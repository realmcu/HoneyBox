import 'ws_demo_controller.dart';
import 'ws_measure_module.dart';

/// Default HR interval list when SDK has not returned device options yet.
const kJwDemoFallbackHeartRateIntervals = [5, 10, 30, 60, 120];

int jwDemoDefaultAutoIntervalMinutes(WSMeasureModuleKind kind) {
  if (kind == WSMeasureModuleKind.heartRate) return 10;
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
