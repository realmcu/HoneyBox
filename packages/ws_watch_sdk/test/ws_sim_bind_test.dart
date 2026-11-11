import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  test('simulator bind then login reaches ready', () async {
    const userId = '0123456789abcdef0123456789abcdef';
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
  final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      expect(session.state.phase, WSSessionPhase.connected);

      await session.bindFirstTime(userId, confirmed: true);
      expect(session.state.phase, WSSessionPhase.ready);
      expect(session.authenticatedUserId, userId);
      expect(session.historyScope?.userId, userId);
      expect(session.historyScope?.deviceMac, kWsWatchSimDeviceId);

      await session.dispose();

      final session2 = watch.createSession(kWsWatchSimDeviceId);
      await session2.connect();
      await session2.login(userId);
      expect(session2.state.phase, WSSessionPhase.ready);
      await session2.dispose();
    } finally {
      await watch.dispose();
    }
  });

  test('login without bind rejects', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.login('other-user');
      expect(session.state.phase, WSSessionPhase.loginRejected);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });
}
