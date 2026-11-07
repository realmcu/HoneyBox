import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_data_catalog.dart';
import 'package:jw_watch_demo/src/jw_data_charts.dart';
import 'package:jw_watch_demo/src/jw_data_mock.dart';

void main() {
  test('mock covers every catalog type with chartable day stats', () {
    final day = DateTime(2026, 11, 6);
    for (final item in jwDataCatalog()) {
      final rows = JwDataMock.queryDay(item.id, day);
      expect(rows, isNotEmpty, reason: item.id.name);
      final stats = jwDataBuildDayStats(id: item.id, records: rows);
      expect(stats, isNotNull, reason: item.id.name);
      expect(stats!.chart, isNotNull, reason: item.id.name);
      expect(JwDataMock.cardSummary(item.id, day: day), isNot(equals('暂无数据')));
    }
  });
}
