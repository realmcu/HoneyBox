import 'jw_demo_controller.dart';
import 'jw_measure_module.dart';

/// Default HR interval list when SDK has not returned device options yet.
const kJwDemoFallbackHeartRateIntervals = [5, 10, 30, 60, 120];

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
