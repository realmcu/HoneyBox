final class WSScanDevice {
  const WSScanDevice({
    required this.deviceMac,
    required this.name,
    required this.rssi,
    this.isSimulated = false,
  });

  final String deviceMac;
  final String name;
  final int rssi;
  final bool isSimulated;
}
