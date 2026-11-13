import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/storage/jw_database.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

class SyncListener implements JWHistorySyncListener {
  int finished = 0;
  int received = 0;
  int total = 0;
  final failures = <JWHistorySyncFailure>[];
  final heartRates = <JWHeartRate>[];
  @override
  void onSyncStart(JWHistorySyncPlan plan) {
    total = plan.totalWireRecords;
  }

  @override
  void onSyncProgress(int receivedWireRecords, int totalWireRecords) {
    received = receivedWireRecords;
  }

  @override
  void onSyncFinished() {
    finished++;
  }

  @override
  void onSyncFailed(JWHistorySyncFailure failure) {
    failures.add(failure);
  }

  @override
  void onHeartRateReceived(List<JWHeartRate> batch) => heartRates.addAll(batch);
  @override
  void onActivityReceived(List<JWActivity> batch) {}
  @override
  void onSleepReceived(List<JWSleep> batch) {}
  @override
  void onTemperatureReceived(List<JWTemperature> batch) {}
  @override
  void onBloodPressureReceived(List<JWBloodPressure> batch) {}
  @override
  void onBloodOxygenReceived(List<JWBloodOxygen> batch) {}
  @override
  void onHrvReceived(List<JWHrv> batch) {}
  @override
  void onPressureReceived(List<JWPressure> batch) {}
  @override
  void onSportReceived(List<JWSport> batch) {}
}

void main() {
  test(
      'history failure callback matches thrown operation error without disconnecting another device',
      () async {
    final store =
        JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));
    final watch = JWWatch.simulation(historyStore: store);
    addTearDown(() async {
      await watch.dispose();
      await store.dispose();
    });
    await watch.initialize();
    final a = await watch.openSession('jw-sim-1');
    final b = await watch.openSession('jw-sim-2');
    await Future.wait([a.connect(), b.connect()]);
    await Future.wait([
      a.bindFirstTime('123456', confirmed: true),
      b.bindFirstTime('123456', confirmed: true)
    ]);
    final connection = a.connection as WatchSimulationConnection;
    connection.interceptWrite = (_) async => throw StateError('write failed');
    final failed = SyncListener();
    await expectLater(
        a.syncHealthData(failed),
        throwsA(isA<JWException>()
            .having((e) => e.code, 'code', JWErrorCode.writeFailed)));
    expect(failed.failures.single.code, JWErrorCode.writeFailed);
    expect(a.state.isReady, isTrue);
    expect(b.state.isReady, isTrue);
    await b.readLanguage();
    connection.interceptWrite = null;
    final retry = SyncListener();
    await a.syncHealthData(retry);
    expect(retry.finished, 1);
  });

  test(
      'two simulated JW watches bind same user, isolate settings and parallel history',
      () async {
    final store =
        JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));
    final watch = JWWatch.simulation(historyStore: store);
    addTearDown(() async {
      await watch.dispose();
      await store.dispose();
    });
    await watch.initialize();
    final scanned = watch.scanResults.first;
    await watch.startScan();
    expect((await scanned).map((d) => d.deviceMac), ['jw-sim-1', 'jw-sim-2']);
    final a = await watch.openSession('jw-sim-1');
    final b = await watch.openSession('jw-sim-2');
    await Future.wait([a.connect(), b.connect()]);
    await Future.wait([
      a.bindFirstTime('123456', confirmed: true),
      b.bindFirstTime('123456', confirmed: true),
    ]);
    expect(a.state.isReady, isTrue);
    expect(b.state.isReady, isTrue);
    await Future.wait([a.readDeviceFeatures(), b.readDeviceFeatures()]);
    await Future.wait([a.readDeviceInfo(), b.readDeviceInfo()]);
    final originalB = await b.readLanguage();
    final nextA = JWLanguage.values.firstWhere((v) => v != originalB);
    await a.setLanguageVerified(nextA);
    expect(await a.readLanguage(), nextA);
    expect(await b.readLanguage(), originalB);
    final la = SyncListener(), lb = SyncListener();
    await Future.wait([a.syncHealthData(la), b.syncHealthData(lb)]);
    expect(la.finished, 1);
    expect(lb.finished, 1);
    expect(la.failures, isEmpty);
    expect(lb.failures, isEmpty);
    expect(la.received, 1);
    final rowsA =
        await store.queryHeartRates(JWHistoryQuery(scope: a.historyScope!));
    final rowsB =
        await store.queryHeartRates(JWHistoryQuery(scope: b.historyScope!));
    expect(rowsA.single.heartRate, 70);
    expect(rowsB.single.heartRate, 80);
    expect(a.historyScope!.userId, b.historyScope!.userId);
    await watch.closeSession('jw-sim-1');
    expect(b.state.isReady, isTrue);
    expect(await b.readLanguage(), originalB);
    final reconnected = await watch.openSession('jw-sim-1');
    expect(reconnected, isNot(same(a)));
    await reconnected.connect();
    await reconnected.login('123456');
    expect(reconnected.state.isReady, isTrue);
    expect(await reconnected.readLanguage(), nextA);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
