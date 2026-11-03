#pragma once
#include <cstdint>
#include <string_view>
namespace watch_ble {
bool ParseBluetoothAddress(std::string_view text, uint64_t* address);
}
