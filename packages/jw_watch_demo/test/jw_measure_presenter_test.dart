import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_measure_presenter.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('formats blood glucose in mmol/L', () {
    final line = jwMeasureSampleLine(
      JWBloodGlucose(
        time: DateTime.utc(2026, 11, 5, 12, 0),
        value: 56,
      ),
    );
    expect(line, contains('5.6'));
    expect(line, contains('mmol/L'));
  });
}
