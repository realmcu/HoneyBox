import 'dart:async';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';
import 'package:ws_watch_sdk/src/protocol/cmd_05_history.dart';

void main() {
  late SimWatchState device;
  late WSDriftDeviceStore store;
  late WSWatch watch;
  setUp(() {
    device = SimWatchState()
      ..confirmationDelay = Duration.zero
      ..historyDelay = const Duration(milliseconds: 5);
    store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    watch = runZoned(
        () => WSWatch(
            config: const WSConfig(
                simulationEnabled: true,
                sync: WSSyncConfig(
                    syncIdleTimeout: Duration(milliseconds: 120)))),
        zoneValues: {
          wsEnvironmentZoneKey: WSConnectionEnvironment(
              openTransport: (_, c) =>
                  WSConnectionEnvironment.openSimulator(c, device),
              openStore: (_) async => store)
        });
  });
  tearDown(() async {
    await watch.dispose();
    await store.close();
  });
  WSRecordQuery query({int? limit, bool descending = false}) => WSRecordQuery(
      deviceId: kWsWatchSimDeviceId, limit: limit, descending: descending);
  test('golden steps, progress, repeat dedup and disconnected query/delete',
      () async {
    expect(await watch.data.steps.query(query()), isEmpty);
    expect(() => watch.data.sync(type: WSHistoryType.steps),
        throwsA(isA<WSNotReadyException>()));
    await watch.connect(kWsWatchSimDeviceId);
    final sync = watch.data.sync(type: WSHistoryType.steps);
    final progress = <WSSyncProgress>[];
    final sub = sync.progress.listen(progress.add);
    final result = await sync.result;
    expect(result.status, WSSyncStatus.completed);
    expect(result.confirmation, WSSyncConfirmation.acked);
    expect(result.progress.announced, 2);
    expect(result.progress.received, 2);
    expect(result.progress.committed, 2);
    expect(result.progress.inserted, 2);
    expect(progress.first.stage, WSSyncStage.requesting);
    expect(progress.last.stage, WSSyncStage.finished);
    final rows = await watch.data.steps.query(query());
    expect(rows.map((r) => r.steps), [1200, 300]);
    expect(rows.map((r) => r.averageHeartRate), [98, null]);
    expect(rows.first.distanceMeters, 850);
    expect(rows.first.caloriesDeciKcal, 456);
    expect(rows.first.recordTime.toString(), '2026-10-12 08:30:00');
    final second = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(second.status, WSSyncStatus.completed);
    expect(second.progress.inserted, 0);
    expect(second.progress.duplicates, 2);
    await watch.disconnect();
    expect(await watch.data.steps.query(query()), hasLength(2));
    expect(
        await watch.data.syncLogs(deviceId: kWsWatchSimDeviceId), hasLength(2));
    expect(await watch.data.steps.delete(query(limit: 0)), 0);
    expect(await watch.data.steps.delete(query(limit: 1, descending: true)), 1);
    expect((await watch.data.steps.query(query())).single.steps, 1200);
    await sub.cancel();
  });
  test('heart rate and empty sync', () async {
    await watch.connect(kWsWatchSimDeviceId);
    expect((await watch.data.sync(type: WSHistoryType.heartRate).result).status,
        WSSyncStatus.completed);
    expect((await watch.data.heartRate.query(query())).map((r) => r.bpm),
        [72, 75]);
    device.emptyHistory = true;
    final result = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(result.status, WSSyncStatus.completed);
    expect(result.progress.received, 0);
  });
  test('exclusive sync and Raw controls, settings remain usable', () async {
    device.historyDelay = const Duration(milliseconds: 25);
    await watch.connect(kWsWatchSimDeviceId);
    final sync = watch.data.sync(type: WSHistoryType.steps);
    expect(() => watch.data.sync(type: WSHistoryType.heartRate),
        throwsA(isA<WSSyncInProgressException>()));
    await expectLater(
        watch.debug
            .sendRaw(WSRawRequest(cmd: 5, version: 1, key: 0x42, data: [])),
        throwsA(isA<WSSyncInProgressException>()));
    await watch.settings.setLanguage(WSLanguage.english);
    expect(await watch.settings.getLanguage(), WSLanguage.english);
    expect((await sync.result).status, WSSyncStatus.completed);
  });
  for (final code in [2, 3, 4]) {
    test('device failure $code never confirms', () async {
      device.historyResultCode = code;
      await watch.connect(kWsWatchSimDeviceId);
      final result = await watch.data.sync(type: WSHistoryType.steps).result;
      expect(result.status, WSSyncStatus.incomplete);
      expect(result.deviceResultCode, code);
      expect(result.confirmation, WSSyncConfirmation.notSent);
      expect(device.historyConfirmations, 0);
      expect(watch.state, WSConnectionState.disconnected);
    });
  }
  test('count mismatch keeps partial records; reconnect dedups', () async {
    device.historyCountAdjustment = 1;
    await watch.connect(kWsWatchSimDeviceId);
    final result = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(result.reason, WSSyncFailure.countMismatch);
    expect(result.progress.committed, 2);
    expect(device.historyConfirmations, 0);
    device.historyCountAdjustment = 0;
    await watch.connect(kWsWatchSimDeviceId);
    final next = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(next.progress.duplicates, 2);
    expect(next.status, WSSyncStatus.completed);
  });
  test('malformed batch fails', () async {
    device.historyBatchOverride = [18, 0, 2, 1];
    await watch.connect(kWsWatchSimDeviceId);
    final result = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(result.reason, WSSyncFailure.protocolError);
    expect(result.progress.decodeFailures, 1);
    expect(device.historyConfirmations, 0);
  });
  test('idle deadline preserves partial data', () async {
    device.suppressHistoryEnd = true;
    await watch.connect(kWsWatchSimDeviceId);
    final result = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(result.reason, WSSyncFailure.idleTimeout);
    expect(result.progress.committed, 2);
    expect(device.historyConfirmations, 0);
  });
  test('cancel before start and dispose always complete result', () async {
    await watch.connect(kWsWatchSimDeviceId);
    final sync = watch.data.sync(type: WSHistoryType.steps);
    await sync.cancel();
    expect((await sync.result).reason, WSSyncFailure.cancelled);
    expect(device.historyConfirmations, 0);
    await watch.connect(kWsWatchSimDeviceId);
    final next = watch.data.sync(type: WSHistoryType.steps);
    await watch.dispose();
    expect((await next.result).status, WSSyncStatus.incomplete);
  });
  test('codec extensions, unknown mode and bad framing', () {
    final row = [
      0x6a,
      0xcc,
      0x9a,
      0x88,
      255,
      255,
      255,
      255,
      255,
      255,
      255,
      15,
      254,
      3,
      0,
      0,
      0,
      0,
      99
    ];
    final batch = WSHistoryProtocol.decodeBatch(
        WSHistoryType.steps, Uint8List.fromList([19, 0, 1, ...row]));
    expect(batch.samples.single.raw.last, 99);
    for (final b in [
      Uint8List(0),
      Uint8List.fromList([18, 0, 1]),
      Uint8List.fromList([4, 0, 0])
    ]) {
      expect(() => WSHistoryProtocol.decodeBatch(WSHistoryType.steps, b),
          throwsFormatException);
    }
    expect(
        () => WSHistoryProtocol.decodeStart(
            Uint8List.fromList([1, 0, 1, 1, 0, 1])),
        throwsFormatException);
    expect(
        () => WSHistoryProtocol.decodeEnd(Uint8List(4)), throwsFormatException);
  });
}
