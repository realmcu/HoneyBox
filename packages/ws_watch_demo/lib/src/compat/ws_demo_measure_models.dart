/// Continuous auto-measure config (Android `WSAutoMeasureConfigInfo`).
final class WSAutoMeasureConfig {
  const WSAutoMeasureConfig({
    required this.enabled,
    required this.intervalMinutes,
  });

  final bool enabled;

  /// Sampling interval in minutes (protocol byte).
  final int intervalMinutes;
}

/// Blood sugar continuous monitoring (Android `WSBloodSugarContinuousMonitoringFunctionInfo`).
final class WSBloodSugarAutoMeasureConfig {
  const WSBloodSugarAutoMeasureConfig({
    required this.enabled,
    required this.intervalMinutes,
  });

  final bool enabled;
  final int intervalMinutes;
}

/// Temperature monitoring / display control (Android `ApplicationLayerTemperatureControlPacket`).
final class WSTemperatureControlSetting {
  const WSTemperatureControlSetting({
    required this.enabled,
    required this.adjust,
    required this.celsius,
  });

  /// Maps to firmware `show` (monitoring on device).
  final bool enabled;
  final bool adjust;
  final bool celsius;
}
