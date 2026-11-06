/// Continuous auto-measure config (Android `JWAutoMeasureConfigInfo`).
final class JWAutoMeasureConfig {
  const JWAutoMeasureConfig({
    required this.enabled,
    required this.intervalMinutes,
  });

  final bool enabled;

  /// Sampling interval in minutes (protocol byte).
  final int intervalMinutes;
}

/// Blood sugar continuous monitoring (Android `JWBloodSugarContinuousMonitoringFunctionInfo`).
final class JWBloodSugarAutoMeasureConfig {
  const JWBloodSugarAutoMeasureConfig({
    required this.enabled,
    required this.intervalMinutes,
  });

  final bool enabled;
  final int intervalMinutes;
}

/// Temperature monitoring / display control (Android `ApplicationLayerTemperatureControlPacket`).
final class JWTemperatureControlSetting {
  const JWTemperatureControlSetting({
    required this.enabled,
    required this.adjust,
    required this.celsius,
  });

  /// Maps to firmware `show` (monitoring on device).
  final bool enabled;
  final bool adjust;
  final bool celsius;
}
