import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/simulation/ws_sim_fixtures.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

final class _CollectListener implements WSHistorySyncListener {
  WSHistorySyncPlan? plan;
  int progressCalls = 0;
  int lastReceived = 0;
  int lastTotal = 0;
  bool finished = false;

  @override
  void onSyncFailed(WSHistorySyncFailure failure) {
    fail('sync failed: ${failure.message}');
  }

  @override
  void onSyncFinished() => finished = true;

  @override
  void onSyncProgress(int receivedWireRecords, int totalWireRecords) {
    progressCalls++;
    lastReceived = receivedWireRecords;
    lastTotal = totalWireRecords;
  }

  @override
  void onSyncStart(WSHistorySyncPlan p) => plan = p;
}

void main() {
  test('sim full syncHealthData persists all types', () async {
    const userId = '0123456789abcdef0123456789abcdef';
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    final listener = _CollectListener();
    try {
      await session.connect();
      await session.bindFirstTime(userId, confirmed: true);
      await session.syncHealthData(listener);
      expect(listener.finished, isTrue);
      expect(listener.plan?.totalWireRecords, WsSimFixtures.totalWireRecords);
      expect(listener.lastReceived, WsSimFixtures.totalWireRecords);

      final scope = session.historyScope!;
      final now = DateTime.now();
      final hourAgo = now.subtract(const Duration(hours: 1, minutes: 5));
      final activities =
          await store.queryActivities(WSHistoryQuery(scope: scope));
      expect(activities.length, 2);
      expect(activities.first.time.isAfter(hourAgo), isTrue);
      expect((await store.queryHeartRates(WSHistoryQuery(scope: scope))).length, 2);
      expect((await store.querySleeps(WSHistoryQuery(scope: scope))).length, 0);
      expect((await store.querySports(WSHistoryQuery(scope: scope))).length, 1);

      // Second round still succeeds (idempotent upsert).
      await session.syncHealthData(const WSHistorySyncNoOpListener());
      expect((await store.queryHeartRates(WSHistoryQuery(scope: scope))).length, 2);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });
}
