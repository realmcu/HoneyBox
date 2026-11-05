/// Device characteristics available before and after JW login.
final class JWDeviceInfo {
  const JWDeviceInfo({
    required this.targetId,
    this.name,
    this.serialNumber,
    this.firmware,
    this.hardware,
    this.battery,
  });

  /// Opaque transport endpoint ID; not the SDK's persistent identity.
  final String targetId;
  final String? name;
  final String? serialNumber;
  final String? firmware;
  final String? hardware;
  /// Set by [JWWatchSession.readBattery], not by [JWWatchSession.readDeviceInfo].
  final int? battery;

  JWDeviceInfo copyWith({
    String? targetId,
    String? name,
    String? serialNumber,
    String? firmware,
    String? hardware,
    int? battery,
    bool clearBattery = false,
  }) =>
      JWDeviceInfo(
        targetId: targetId ?? this.targetId,
        name: name ?? this.name,
        serialNumber: serialNumber ?? this.serialNumber,
        firmware: firmware ?? this.firmware,
        hardware: hardware ?? this.hardware,
        battery: clearBattery ? null : battery ?? this.battery,
      );
}
