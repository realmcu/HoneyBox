#include "include/watch_transport_ble/watch_transport_ble_plugin_c_api.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.h>
#include <condition_variable>
#include <utility>
#include "bluetooth_address.h"
#include <cstdint>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace {
namespace bt = winrt::Windows::Devices::Bluetooth;
class WinrtBluetoothLinkTuner final {
 public:
  WinrtBluetoothLinkTuner() {
    worker_ = std::thread([this] { Run(); });
  }

  ~WinrtBluetoothLinkTuner() { Shutdown(); }

  bool RequestThroughput(uint64_t address) {
    return address != 0U && Post([this, address] { AcquireOnWorker(address); });
  }

  void Release(uint64_t address) {
    (void)Post([this, address] { ReleaseOnWorker(address); });
  }

  void Shutdown() {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (!running_) return;
      running_ = false;
      condition_.notify_all();
    }
    if (worker_.joinable()) worker_.join();
  }

 private:
  bool Post(std::function<void()> work) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!running_) return false;
    pending_.push_back(std::move(work));
    condition_.notify_all();
    return true;
  }

  void Run() noexcept {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    for (;;) {
      std::function<void()> work;
      {
        std::unique_lock<std::mutex> lock(mutex_);
        condition_.wait(lock, [this] { return !running_ || !pending_.empty(); });
        if (!running_ && pending_.empty()) break;
        work = std::move(pending_.front());
        pending_.pop_front();
      }
      try {
        work();
      } catch (...) {
      }
    }
    ReleaseAllOnWorker();
    winrt::uninit_apartment();
  }

  void AcquireOnWorker(uint64_t address) {
    // Replacing an existing request keeps at most one per device.
    ReleaseOnWorker(address);
    auto device = bt::BluetoothLEDevice::FromBluetoothAddressAsync(address).get();
    if (device == nullptr) return;
    // The preference lasts exactly as long as the returned request is held.
    auto request = device.RequestPreferredConnectionParameters(
        bt::BluetoothLEPreferredConnectionParameters::ThroughputOptimized());
    if (auto closable =
            request.try_as<winrt::Windows::Foundation::IClosable>()) {
      held_.emplace(address, std::move(closable));
    }
  }

  void ReleaseOnWorker(uint64_t address) {
    const auto found = held_.find(address);
    if (found == held_.end()) return;
    try {
      found->second.Close();
    } catch (...) {
    }
    held_.erase(found);
  }

  void ReleaseAllOnWorker() noexcept {
    for (auto& entry : held_) {
      try {
        entry.second.Close();
      } catch (...) {
      }
    }
    held_.clear();
  }

  std::mutex mutex_;
  std::condition_variable condition_;
  std::deque<std::function<void()>> pending_;
  bool running_ = true;
  std::thread worker_;
  // Worker-thread only.
  std::map<uint64_t, winrt::Windows::Foundation::IClosable> held_;
};

class WatchBlePlugin final : public flutter::Plugin {
 public:
  explicit WatchBlePlugin(flutter::PluginRegistrarWindows* registrar)
      : channel_(registrar->messenger(), "watch_transport_ble/link",
                 &flutter::StandardMethodCodec::GetInstance()) {
    channel_.SetMethodCallHandler([this](const auto& call, auto result) {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      const std::string* id = nullptr;
      if (args != nullptr) {
        const auto it = args->find(flutter::EncodableValue("remoteId"));
        if (it != args->end()) id = std::get_if<std::string>(&it->second);
      }
      uint64_t address = 0U;
      if (id == nullptr || (!watch_ble::ParseBluetoothAddress(*id, &address) || address == 0U)) {
        result->Error("invalid_argument", "Expected a nonzero AA:BB:CC:DD:EE:FF remoteId");
      } else if (call.method_name() == "requestThroughput") {
        if (tuner_.RequestThroughput(address)) result->Success();
        else result->Error("closed", "BLE tuner stopped");
      } else if (call.method_name() == "releaseThroughput") {
        tuner_.Release(address); result->Success();
      } else {
        result->NotImplemented();
      }
    });
  }
  ~WatchBlePlugin() override { channel_.SetMethodCallHandler(nullptr); tuner_.Shutdown(); }
 private:
  WinrtBluetoothLinkTuner tuner_;
  flutter::MethodChannel<flutter::EncodableValue> channel_;
};
}  // namespace

void WatchTransportBlePluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows = flutter::PluginRegistrarManager::GetInstance()
      ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  windows->AddPlugin(std::make_unique<WatchBlePlugin>(windows));
}
