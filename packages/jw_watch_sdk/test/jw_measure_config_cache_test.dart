import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/src/measure/jw_measure_config_cache.dart';
import 'package:jw_watch_sdk/src/measure/jw_measure_models.dart';

void main() {
  test('heart rate auto measure incomplete until interval known', () {
    final cache = JWMeasureConfigCache();
    cache.mergeHeartRateAutoEnabled(true);
    expect(cache.heartRateAutoMeasureIfComplete, isNull);
    cache.setHeartRateAutoMeasure(
      const JWAutoMeasureConfig(enabled: true, intervalMinutes: 10),
    );
    expect(cache.heartRateAutoMeasureIfComplete?.intervalMinutes, 10);
  });

  test('clear resets heart rate slots', () {
    final cache = JWMeasureConfigCache();
    cache.setHeartRateIntervalOptions(const [5, 10]);
    cache.setHeartRateAutoMeasure(
      const JWAutoMeasureConfig(enabled: false, intervalMinutes: 5),
    );
    cache.clear();
    expect(cache.heartRateAutoMeasureIfComplete, isNull);
    expect(cache.heartRateIntervalOptionsIfKnown, isNull);
  });
}
