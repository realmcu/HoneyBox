import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_data_catalog.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('data catalog covers core health types', () {
    final items = jwDataCatalog();
    final ids = items.map((e) => e.id).toSet();
    expect(ids.contains(JwDataTypeId.activity), isTrue);
    expect(ids.contains(JwDataTypeId.sleep), isTrue);
    expect(ids.contains(JwDataTypeId.heartRate), isTrue);
    expect(ids.contains(JwDataTypeId.bloodOxygen), isTrue);
    expect(ids.contains(JwDataTypeId.sport), isTrue);
    expect(items.map((e) => e.title).toSet().contains('步数'), isTrue);
  });

  test('day helpers stay on calendar boundaries', () {
    final day = DateTime(2026, 11, 6, 15, 30);
    expect(jwDataDayStart(day), DateTime(2026, 11, 6));
    expect(jwDataDayEnd(day).day, 6);
    expect(jwDataDayEnd(day).isAfter(jwDataDayStart(day)), isTrue);
    expect(jwDataFormatDay(DateTime.now()), '今天');
  });

  test('activity summary prefers step count with App units in detail line', () {
    final row = JWActivity(
      time: DateTime(2026, 11, 6, 9, 15),
      steps: 1200,
      distance: 800,
      energy: 35000,
      activeTime: 15,
      mode: 0,
    );
    expect(jwDataLatestSummary(row), '1200 步');
    expect(jwDataRecordDetailLine(row).contains('0.80 km'), isTrue);
    expect(jwDataRecordDetailLine(row).contains('35 kcal'), isTrue);
  });
}
