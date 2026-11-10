import 'jw_measure_models.dart';

/// Session-scoped measure device-config cache (§8.0 implementation plan).
///
/// Cleared on disconnect / dispose; not exposed to app callers.
final class JWMeasureConfigCache {
  JWAutoMeasureSlot _heartRateAuto = const JWAutoMeasureSlot();
  List<int>? _heartRateIntervalOptions;
  bool _heartRateIntervalOptionsKnown = false;

  JWAutoMeasureConfig? get heartRateAutoMeasureIfComplete =>
      _heartRateAuto.ifComplete;

  List<int>? get heartRateIntervalOptionsIfKnown =>
      _heartRateIntervalOptionsKnown
          ? List<int>.unmodifiable(_heartRateIntervalOptions ?? const [])
          : null;

  void clear() {
    _heartRateAuto = const JWAutoMeasureSlot();
    _heartRateIntervalOptions = null;
    _heartRateIntervalOptionsKnown = false;
  }

  void setHeartRateAutoMeasure(JWAutoMeasureConfig config) {
    _heartRateAuto = JWAutoMeasureSlot.full(config);
  }

  void mergeHeartRateAutoEnabled(bool enabled) {
    _heartRateAuto = _heartRateAuto.mergeEnabled(enabled);
  }

  void setHeartRateIntervalOptions(List<int> options) {
    _heartRateIntervalOptions = List<int>.from(options);
    _heartRateIntervalOptionsKnown = true;
  }
}

final class JWAutoMeasureSlot {
  const JWAutoMeasureSlot({
    this.enabledKnown = false,
    this.intervalKnown = false,
    this.enabled = false,
    this.intervalMinutes = 0,
  });

  JWAutoMeasureSlot.full(JWAutoMeasureConfig config)
      : enabledKnown = true,
        intervalKnown = true,
        enabled = config.enabled,
        intervalMinutes = config.intervalMinutes;

  final bool enabledKnown;
  final bool intervalKnown;
  final bool enabled;
  final int intervalMinutes;

  bool get isComplete => enabledKnown && intervalKnown;

  JWAutoMeasureConfig? get ifComplete => isComplete
      ? JWAutoMeasureConfig(
          enabled: enabled,
          intervalMinutes: intervalMinutes,
        )
      : null;

  JWAutoMeasureSlot mergeEnabled(bool value) => JWAutoMeasureSlot(
        enabledKnown: true,
        intervalKnown: intervalKnown,
        enabled: value,
        intervalMinutes: intervalMinutes,
      );
}
