/// Device characteristics available before and after JW login.
final class JWDeviceInfo {
  const JWDeviceInfo({
    required this.deviceMac,
    this.name,
    this.serialNumber,
    this.firmware,
    this.hardware,
    this.battery,
  });

  /// JW BLE MAC address used for connection and history storage.
  final String deviceMac;
  final String? name;
  final String? serialNumber;
  final String? firmware;
  final String? hardware;

  /// Set by [JWWatchSession.readBattery], not by [JWWatchSession.readDeviceInfo].
  final int? battery;

  JWDeviceInfo copyWith({
    String? deviceMac,
    String? name,
    String? serialNumber,
    String? firmware,
    String? hardware,
    int? battery,
    bool clearBattery = false,
  }) =>
      JWDeviceInfo(
        deviceMac: deviceMac ?? this.deviceMac,
        name: name ?? this.name,
        serialNumber: serialNumber ?? this.serialNumber,
        firmware: firmware ?? this.firmware,
        hardware: hardware ?? this.hardware,
        battery: clearBattery ? null : battery ?? this.battery,
      );
}
