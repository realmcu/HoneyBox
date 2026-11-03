#include "bluetooth_address.h"
#include <cstdlib>
#include <iostream>
#include <string_view>

int main() {
  uint64_t address = 0U;
  const auto require = [](bool ok) { if (!ok) { std::cerr << "BLE address assertion failed\n"; std::exit(1); } };
  require(watch_ble::ParseBluetoothAddress("aA:BB:cc:DD:ee:Ff", &address));
  require(address == 0xAABBCCDDEEFFULL);
  for (std::string_view text : {"", "AABBCCDDEEFF", "AA-BB-CC-DD-EE-FF", "GG:BB:CC:DD:EE:FF", "AA:BB:CC:DD:EE:FF:00", " AA:BB:CC:DD:EE:FF", "AA:BB:CC:DD:EE:F"}) {
    require(!watch_ble::ParseBluetoothAddress(text, &address));
  }
  require(!watch_ble::ParseBluetoothAddress("AA:BB:CC:DD:EE:FF", nullptr));
  std::cout << "BLE native address tests passed\n";
}
