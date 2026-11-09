import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_data_home_header.dart';

void main() {
  test('home header formats value with unit suffix', () {
    expect(jwFormatHomeKcal(218), '218 千卡');
    expect(jwFormatHomeKcal(218.4), '218.4 千卡');
    expect(jwFormatHomeDistanceKm(3.24), '3.2 公里');
    expect(jwFormatHomeSteps(4960), '4,960');
  });
}
