import 'package:watch_transport_ble/watch_transport_ble.dart';

/// A scan result filtered as a potential JW watch.
final class JWScanDevice {
  const JWScanDevice({
    required this.deviceMac,
    required this.name,
    required this.rssi,
  });

  /// Public JW connection and persistence identifier.
  final String deviceMac;
  final String name;
  final int rssi;

  factory JWScanDevice.fromAdvertisement(WatchBleAdvertisement value) =>
      JWScanDevice(
        deviceMac: value.deviceId,
        name: value.name,
        rssi: value.rssi,
      );
}

const jwWristbandServiceUuid = '000001ff-3c17-d293-8e48-14fe2e4da212';
const jwFd50ServiceUuid = '0000fd50-0000-1000-8000-00805f9b34fb';

/// Platform `withServices` filter (JW V2 wristband + FD50 discovery hint).
const jwBleScanServiceUuids = <String>[
  jwWristbandServiceUuid,
  jwFd50ServiceUuid,
];

const _wsNusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const _wsRealtekFee7ServiceUuid = '0000fee7-0000-1000-8000-00805f9b34fb';

bool _isHoneyWsAdvertisement(WatchBleAdvertisement device) {
  final services = device.services.map(normalizeBleUuid).toSet();
  if (services.contains(normalizeBleUuid(_wsNusServiceUuid))) {
    return true;
  }
  final fec5 = device.manufacturerData[0xfec5];
  if (fec5 == null || fec5.length < 6) {
    return false;
  }
  if (services.contains(normalizeBleUuid(_wsRealtekFee7ServiceUuid))) {
    return true;
  }
  return device.name.trim().toLowerCase() == 'watch';
}

/// Service UUID discovery for JW V2; excludes Honey/WS Realtek adverts that
/// still carry legacy `000001ff` in scan response.
bool isJWCandidate(WatchBleAdvertisement device) {
  if (_isHoneyWsAdvertisement(device)) {
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

WatchBleProfile jwBleProfile() => WatchBleProfile(
      service: jwWristbandServiceUuid,
      tx: 'ff02',
      rx: 'ff03',
    );
