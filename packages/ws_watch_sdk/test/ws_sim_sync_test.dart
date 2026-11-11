import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  test('sim read language after ready', () async {
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
      await session.bindFirstTime(userId, confirmed: true);
      expect(await session.settings.readLanguage(), 1);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });

  test('sim sync heart rate stores rows', () async {
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
      await session.bindFirstTime(userId, confirmed: true);
      final pulled = await session.history.syncHeartRate();
      expect(pulled.length, 2);
      expect(pulled[0].bpm, 0x48);
      final cached = await session.history.queryHeartRates();
      expect(cached, pulled);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });
}
