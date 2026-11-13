import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

class Listener implements WSHistorySyncListener {
  int finished = 0;
  final failures = <WSHistorySyncFailure>[];
  @override
  void onSyncStart(WSHistorySyncPlan plan) {}
  @override
  void onSyncProgress(int receivedWireRecords, int totalWireRecords) {}
  @override
  void onSyncFinished() => finished++;
  @override
  void onSyncFailed(WSHistorySyncFailure failure) => failures.add(failure);
}

void main() {
  test('parallel sessions isolate history, battery, failures and reconnect',
      () async {
    final store = await WSHistoryStore.open(databasePath: ':memory:');
    final watch =
        WSWatch(config: const WSConfig.simulation(), historyStore: store);
    addTearDown(() async {
      await watch.dispose();
      await store.dispose();
    });
    await watch.initialize();
    final scan = watch.scanResults.first;
    await watch.startScan();
    expect(await scan, hasLength(2));
    final a = await watch.openSession(kWsWatchSimDeviceId);
    final b = await watch.openSession(kWsWatchSimDeviceId2);
    await Future.wait([a.connect(), b.connect()]);
    await Future.wait([
      a.bindFirstTime('123456', confirmed: true),
      b.bindFirstTime('123456', confirmed: true)
    ]);
    expect(await a.control.queryBatteryPercent(), 75);
    expect(await b.control.queryBatteryPercent(), 55);
    final la = Listener(), lb = Listener();
    await Future.wait([a.syncHealthData(la), b.syncHealthData(lb)]);
    expect(la.finished, 1);
    expect(lb.finished, 1);
    expect((await a.history.queryHeartRates()).first.bpm, 72);
    expect((await b.history.queryHeartRates()).first.bpm, 82);
    final connection = a.connection as WatchSimulationConnection;
    connection.interceptWrite = (_) async => throw StateError('write failed');
    final failed = Listener();
    await expectLater(
        a.syncHealthData(failed),
        throwsA(isA<WSException>()
            .having((e) => e.code, 'code', WSErrorCode.writeFailed)));
    expect(failed.failures.single.code, WSErrorCode.writeFailed);
    expect(a.state.isReady, isTrue);
    expect(b.state.isReady, isTrue);
    connection.interceptWrite = null;
    await a.syncHealthData(Listener());
    // Closing A during sync must fail once and drain before it releases storage.
    final cancelled = Listener();
    final running = a.syncHealthData(cancelled);
    final check = expectLater(running, throwsA(isA<WSException>()));
    await watch.closeSession(kWsWatchSimDeviceId);
    await check;
    expect(cancelled.failures, hasLength(1));
    expect(await b.settings.readLanguage(), 1);
    final replacement = await watch.openSession(kWsWatchSimDeviceId);
    expect(replacement, isNot(same(a)));
    await replacement.connect();
    await replacement.login('123456');
    expect(replacement.state.isReady, isTrue);
  });
}
