import 'jw_demo_controller.dart';
import 'jw_measure_module.dart';

/// Default HR interval list when HRP capability packet is not available yet.
const kJwDemoFallbackHeartRateIntervals = [5, 10, 30, 60, 120];

/// Typical heart-rate intervals when 1-minute detect is supported.
const kJwDemoHeartRateIntervalsWithOne = [1, 5, 10, 30, 60];

/// Supported HR intervals for Demo UI until [JWWatchSession] exposes HRP params.
List<int> jwDemoHeartRateSupportIntervals(JWDemoController controller) {
  // TODO(jw-sdk): derive from device HRP params when exposed on session state.
  return kJwDemoHeartRateIntervalsWithOne;
}

int jwDemoDefaultAutoIntervalMinutes(JWMeasureModuleKind kind) {
  if (kind == JWMeasureModuleKind.heartRate) return 10;
  return 10;
}

int jwDemoSnapHeartRateInterval(int minutes, List<int> supported) {
  if (supported.isEmpty) return minutes;
  if (supported.contains(minutes)) return minutes;
  var best = supported.first;
  for (final candidate in supported) {
    if ((candidate - minutes).abs() < (best - minutes).abs()) {
      best = candidate;
    }
  }
  return best;
}
