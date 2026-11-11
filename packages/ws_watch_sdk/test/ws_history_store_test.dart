import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  const scope = WSHistoryScope(
    userId: '0123456789abcdef0123456789abcdef',
    deviceMac: 'AA:BB:CC:DD:EE:FF',
  );

  test('write and query heart rate in test database', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    addTearDown(store.dispose);

    await store.writeHeartRates(scope, [
      const WSHeartRate(time: 1_700_000_000, bpm: 72),
      const WSHeartRate(time: 1_700_000_300, bpm: 75),
    ]);

    final rows = await store.queryHeartRates(WSHistoryQuery(scope: scope));
    expect(rows.length, 2);
    expect(rows[0].bpm, 72);
    expect(rows[1].bpm, 75);

    await store.writeHeartRates(scope, [
      const WSHeartRate(time: 1_700_000_000, bpm: 80),
    ]);
    final updated =
        await store.queryHeartRates(WSHistoryQuery(scope: scope));
    expect(updated.length, 2);
    expect(updated.first.bpm, 80);
  });

  test('replaceHeartRates clears prior rows for scope', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    addTearDown(store.dispose);

    await store.writeHeartRates(scope, [
      const WSHeartRate(time: 100, bpm: 60),
      const WSHeartRate(time: 200, bpm: 61),
    ]);
    await store.replaceHeartRates(scope, [
      const WSHeartRate(time: 300, bpm: 62),
    ]);

    final rows = await store.queryHeartRates(WSHistoryQuery(scope: scope));
    expect(rows.length, 1);
    expect(rows.single.time, 300);
    expect(rows.single.bpm, 62);
  });
}
