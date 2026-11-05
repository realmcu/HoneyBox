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

/// Candidate filtering is intentionally broader than the final GATT profile:
/// FD50 advertisements are valid discovery hints, while connection requires
/// the Realtek FF service and characteristics.
bool isJWCandidate(WatchBleAdvertisement device) {
  final services = device.services.map(normalizeBleUuid).toSet();
  if (services.contains(normalizeBleUuid(jwWristbandServiceUuid)) ||
      services.contains(normalizeBleUuid(jwFd50ServiceUuid))) {
    return true;
  }
  return device.manufacturerData.entries.any((entry) =>
      (entry.key == 0x07d0 || entry.key == 0xfec5) && entry.value.length >= 6);
}

WatchBleProfile jwBleProfile() => WatchBleProfile(
      service: jwWristbandServiceUuid,
      tx: 'ff02',
      rx: 'ff03',
    );
