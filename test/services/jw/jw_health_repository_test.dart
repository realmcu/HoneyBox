import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/services/jw/history/jw_history_store.dart';
import 'package:honeybox/services/jw/health/jw_health_models.dart';
import 'package:honeybox/services/jw/health/jw_health_repository.dart';
import 'jw_health_aggregator_test.dart' show healthRow;

void main() {
  late Directory dir;
  late FileJwHistoryStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw-health-repository-');
    store = FileJwHistoryStore(dir);
    await store.open();
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  // Break caught: only loading the first page or losing partial record IDs.
  test(
      'all pages preserve partial coverage and inventory dates outside selection',
      () async {
    final rows = [
      for (var i = 0; i < 505; i++)
        healthRow(JwHistoryType.heartTemperature, {'heartRateBpm': 70},
            identity: 'sample-$i', minute: i, ordinal: i)
    ];
    await store.append('20261005-001', rows);
    final old = healthRow(JwHistoryType.steps, {'steps': 8}, day: '2026-10-01');
    await store.append('20261005-001', [old]);
    final s = await JwHealthRepository(store).load(
        deviceKey: 'jw:test',
        date: DateTime(2026, 10, 5),
        period: JwHealthPeriod.day);
    expect(s.metrics[JwHealthMetric.heartRate]!.samples, hasLength(505));
    expect(s.coverage.partialRecordIds, hasLength(505));
    expect(s.coverage.hasPartialData, true);
    expect(s.availableDates,
        [DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 5)]);
  });
  test(
      'adjacent sleep dates close both boundaries without adjacent activity totals',
      () async {
    final rows = [
      healthRow(JwHistoryType.sleep, {'mode': 1},
          day: '2026-10-04', minute: 1380),
      healthRow(JwHistoryType.sleep, {'mode': 2}, minute: 60),
      healthRow(JwHistoryType.sleep, {'mode': 3},
          day: '2026-10-06', minute: 60),
      healthRow(JwHistoryType.steps, {'steps': 99}, day: '2026-10-04')
    ];
    await store.append('20261005-001', rows);
    await store.commit(JwHistoryBatchCommit(
        batchId: '20261005-001',
        deviceKey: 'jw:test',
        recordIds: rows.map((e) => e.recordId)));
    final s = await JwHealthRepository(store).load(
        deviceKey: 'jw:test',
        date: DateTime(2026, 10, 5),
        period: JwHealthPeriod.day);
    expect(s.totals.sleepMinutes, 1440);
    expect(s.totals.steps, isNull);
    expect(s.coverage.hasPartialData, false);
  });
}
