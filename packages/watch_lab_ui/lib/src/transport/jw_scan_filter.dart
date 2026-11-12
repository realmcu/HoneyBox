import 'package:watch_transport_ble/watch_transport_ble.dart';

/// Android `WristbandManager.WRISTBAND_SERVICE_UUID`.
const jwWristbandServiceUuid = '000001ff-3c17-d293-8e48-14fe2e4da212';

/// Android `WristbandManager.FD50_SERVICE_UUID`（涂鸦）。
const jwFd50ServiceUuid = '0000fd50-0000-1000-8000-00805f9b34fb';

const jwBleScanServiceUuids = <String>[
  jwWristbandServiceUuid,
  jwFd50ServiceUuid,
];

const wsNusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const wsRealtekFee7ServiceUuid = '0000fee7-0000-1000-8000-00805f9b34fb';

const wsBleScanServiceUuids = <String>[];

WatchBleProfile jwDiagnosticProfile() => WatchBleProfile(
    service: jwWristbandServiceUuid, tx: 'ff02', rx: 'ff03');

bool _realtekFec5WithMac(WatchBleAdvertisement device) {
  final payload = device.manufacturerData[0xfec5];
  return payload != null && payload.length >= 6;
}

bool isWsUartCandidate(WatchBleAdvertisement device) {
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

/// JW scan list: service UUIDs only; skips Honey WS adverts (see SDK `isJWCandidate`).
bool isJwCandidate(WatchBleAdvertisement device) {
  if (isWsUartCandidate(device)) {
    return false;
  }
  final services = device.services.map(normalizeBleUuid).toSet();
  if (services.contains(normalizeBleUuid(jwWristbandServiceUuid)) ||
      services.contains(normalizeBleUuid(jwFd50ServiceUuid))) {
    return true;
  }
  final legacy = device.manufacturerData[0x07d0];
  return legacy != null && legacy.length >= 6;
}

WatchBleProfile wsUartDiagnosticProfile() => WatchBleProfile(
    service: wsNusServiceUuid,
    tx: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    rx: '6e400003-b5a3-f393-e0a9-e50e24dcca9e');
