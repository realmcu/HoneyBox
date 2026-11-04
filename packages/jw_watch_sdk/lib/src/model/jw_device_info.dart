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
  final int? battery;
}
