import 'package:watch_transport_ble/watch_transport_ble.dart';

/// Android `WristbandManager.WRISTBAND_SERVICE_UUID`.
const jwWristbandServiceUuid = '000001ff-3c17-d293-8e48-14fe2e4da212';

/// Android `WristbandManager.FD50_SERVICE_UUID`（涂鸦）。
const jwFd50ServiceUuid = '0000fd50-0000-1000-8000-00805f9b34fb';

WatchBleProfile jwDiagnosticProfile() => WatchBleProfile(
    service: jwWristbandServiceUuid, tx: 'ff02', rx: 'ff03');

/// Scan filter: only JW wristband or FD50 service (plus legacy manufacturer hint).
bool isJwCandidate(WatchBleAdvertisement device) {
  final services = device.services.map(normalizeBleUuid).toSet();
  if (services.contains(normalizeBleUuid(jwWristbandServiceUuid)) ||
      services.contains(normalizeBleUuid(jwFd50ServiceUuid))) {
    return true;
  }
  return device.manufacturerData.entries.any(
      (e) => (e.key == 0x07d0 || e.key == 0xfec5) && e.value.length >= 6);
}

WatchBleProfile wsUartDiagnosticProfile() => WatchBleProfile(
    service: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    tx: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    rx: '6e400003-b5a3-f393-e0a9-e50e24dcca9e');
