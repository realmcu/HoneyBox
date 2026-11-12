import 'package:watch_transport_ble/watch_transport_ble.dart';

/// Nordic UART service (HoneyProtocol L0 / Zephyr NUS).
const wsNusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const wsNusTxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const wsNusRxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

/// Realtek `hmi_ble_gap_init.c` primary adv: 16-bit `0xFEE7`.
const wsRealtekFee7ServiceUuid = '0000fee7-0000-1000-8000-00805f9b34fb';

/// Software filtering only. Honey Realtek firmware often omits NUS from air
/// packets (GATT NUS appears after connect; scan response may still carry
/// legacy JW `000001ff` UUID).
const wsBleScanServiceUuids = <String>[];

/// Nordic UART (WS L0 UART profile) per WS protocol architecture.
WatchBleProfile wsBleProfile() => WatchBleProfile(
      service: wsNusServiceUuid,
      tx: wsNusTxUuid,
      rx: wsNusRxUuid,
    );

bool _realtekFec5WithMac(WatchBleAdvertisement device) {
  final payload = device.manufacturerData[0xfec5];
  return payload != null && payload.length >= 6;
}

/// Align with `hmi-watch-360/.../hmi_ble_gap_init.c` (name Watch, FEE7, FEC5).
bool isWSCandidate(WatchBleAdvertisement device) {
  final services = device.services.map(normalizeBleUuid).toSet();
  if (services.contains(normalizeBleUuid(wsNusServiceUuid))) {
    return true;
  }
  if (_realtekFec5WithMac(device) &&
      services.contains(normalizeBleUuid(wsRealtekFee7ServiceUuid))) {
    return true;
  }
  final name = device.name.trim().toLowerCase();
  return _realtekFec5WithMac(device) && name == 'watch';
}
