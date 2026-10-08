import '../history/jw_history_models.dart';
import '../history/jw_history_store.dart';
import '../jw_models.dart';
import 'jw_health_aggregator.dart';
import 'jw_health_models.dart';

class JwHealthRepository {
  final JwHistoryStore store;
  JwHealthRepository(this.store);
  Future<JwHealthSnapshot> load(
      {required String deviceKey,
      required DateTime date,
      required JwHealthPeriod period,
      JwCapabilities? capabilities}) async {
    final selected = jwHealthDate(date);
    final start = selected
        .subtract(Duration(days: period == JwHealthPeriod.week ? 6 : 0));
    final end = selected.add(const Duration(days: 1));
    final inventory = await store.inventory(deviceKey);
    final rows = <JwHistoryRecord>[];
    final partial = <String>{};
    for (final type in JwHistoryType.values) {
      for (final day in inventory.daysByType[type.name] ?? const <String>[]) {
        final d = DateTime.parse('${day}T00:00:00Z');
        final first = type == JwHistoryType.sleep
            ? start.subtract(const Duration(days: 1))
            : start;
        final last = type == JwHistoryType.sleep
            ? end.add(const Duration(days: 1))
            : end;
        if (d.isBefore(first) || !d.isBefore(last)) continue;
        var offset = 0;
        while (true) {
          final page = await store.query(deviceKey, type,
              day: day, offset: offset, limit: 500);
          rows.addAll(page.records);
          partial.addAll(page.partialRecordIds);
          offset += page.records.length;
          if (offset >= page.total) break;
          if (page.records.isEmpty) {
            throw StateError('History pagination made no progress');
          }
        }
      }
    }
    final available = inventory.daysByType.values
        .expand((days) => days)
        .map((day) => DateTime.parse('${day}T00:00:00Z'))
        .toSet()
        .toList()
      ..sort();
    final snapshot = JwHealthAggregator.aggregate(
        deviceKey: deviceKey,
        records: rows,
        date: date,
        period: period,
        capabilities: capabilities);
    return snapshot.withPersistence(
        partialRecordIds: partial,
        availableDates: available,
        issues: [
          if (inventory.recoveredTails > 0) 'recoveredJournalTail',
          if (inventory.batchFailures.isNotEmpty) 'savedBatchFailure'
        ]);
  }
}
