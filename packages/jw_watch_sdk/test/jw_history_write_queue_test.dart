import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/history/jw_history_write_queue.dart';
import 'package:jw_watch_sdk/src/storage/jw_database.dart';
import 'package:drift/native.dart';

void main() {
  final scope =
      JWHistoryScope(userId: 'a' * 32, deviceMac: 'AA:BB:CC:DD:EE:FF');

  JWHistoryStore memoryStore() =>
      JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));

  Future<List<JWHeartRate>> heartRates(JWHistoryStore store) {
    return store.queryHeartRates(JWHistoryQuery(scope: scope, limit: 500));
  }

  test('writer merges batches and drains on round sentinel', () async {
    final store = memoryStore();
    Object? failure;
    final queue = JWHistoryWriteQueue(
      store: store,
      scope: scope,
      onError: (error, _) => failure = error,
    );
    final base = DateTime.utc(2026, 11, 5, 8);
    queue.enqueueRecords([
      for (var i = 0; i < 250; i++)
        JWHeartRate(time: base.add(Duration(minutes: i)), heartRate: 60 + i % 10),
    ]);
    queue.enqueueRoundCompleteSentinel();
    await queue.waitForRoundDrain();
    expect(failure, isNull);
    expect((await heartRates(store)).length, 250);
    await store.dispose();
  });

  test('coalesces many single-packet enqueues before sentinel', () async {
    final store = memoryStore();
    final queue = JWHistoryWriteQueue(
      store: store,
      scope: scope,
      onError: (_, __) {},
    );
    final base = DateTime.utc(2026, 11, 6, 8);
    for (var i = 0; i < 120; i++) {
      queue.enqueueRecords([
        JWHeartRate(time: base.add(Duration(minutes: i)), heartRate: 65),
      ]);
    }
    queue.enqueueRoundCompleteSentinel();
    await queue.waitForRoundDrain();
    expect((await heartRates(store)).length, 120);
    await store.dispose();
  });

  test('sentinel drains remaining records below chunk size', () async {
    final store = memoryStore();
    final queue = JWHistoryWriteQueue(
      store: store,
      scope: scope,
      onError: (_, __) {},
    );
    queue.enqueueRecords([
      JWHeartRate(time: DateTime.utc(2026, 11, 5), heartRate: 70),
    ]);
    queue.enqueueRoundCompleteSentinel();
    await queue.waitForRoundDrain();
    expect((await heartRates(store)).single.heartRate, 70);
    await store.dispose();
  });
}
