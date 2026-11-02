import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/model/history.dart';
import 'package:ws_watch_sdk/src/storage/history_store.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_session.dart';
import 'package:ws_watch_sdk/src/link/frame.dart';

void main() {
  late _Store store;
  late WSWatch watch;
  late SimWatchState device;
  late bool dropConfirmation;
  late int confirmations;
  setUp(() {
    store = _Store();
    dropConfirmation = false;
    confirmations = 0;
    device = SimWatchState()
      ..confirmationDelay = Duration.zero
      ..historyDelay = const Duration(milliseconds: 5);
    watch = runZoned(
        () => WSWatch(
            config: const WSConfig(
                simulationEnabled: true,
                link: WSLinkConfig(ackTimeout: Duration(milliseconds: 60)),
                sync: WSSyncConfig(
                    syncIdleTimeout: Duration(milliseconds: 200),
                    maxPendingBytes: 64))),
        zoneValues: {
          wsEnvironmentZoneKey: WSConnectionEnvironment(
              openStore: (_) async => store,
              openTransport: (_, c) async {
                final (host, peer) = SimWatchSession.pair();
                await peer.prepare();
                int? confirmSeq;
                host.interceptWrite = (bytes) async {
                  final f = WSFrame.decode(bytes);
                  if (!f.isAck &&
                      f.payload.length >= 5 &&
                      f.payload[0] == 5 &&
                      f.payload[2] == 0x42) {
                    confirmSeq = f.seq;
                    confirmations++;
                  }
                  host.deliver(bytes);
                };
                peer.interceptWrite = (bytes) async {
                  final f = WSFrame.decode(bytes);
                  if (dropConfirmation && f.isAck && f.seq == confirmSeq) {
                    return;
                  }
                  peer.deliver(bytes);
                };
                final sim =
                    SimWatchDevice(peer, linkConfig: c.link, state: device);
                return WSManagedTransport(host, release: () async {
                  await sim.dispose();
                  await peer.dispose();
                });
              })
        });
  });
  tearDown(() async {
    await watch.dispose();
    await store.close();
  });
  test('confirmation waits for batch commit', () async {
    store.gate = Completer<void>();
    await watch.connect(kWsWatchSimDeviceId);
    final sync = watch.data.sync(type: WSHistoryType.steps);
    await store.writeStarted.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(confirmations, 0);
    store.gate!.complete();
    expect((await sync.result).status, WSSyncStatus.completed);
    expect(confirmations, 1);
  });
  test('cancel during write waits for durability and never confirms', () async {
    store.gate = Completer<void>();
    await watch.connect(kWsWatchSimDeviceId);
    final sync = watch.data.sync(type: WSHistoryType.steps);
    await store.writeStarted.future;
    var done = false;
    final cancelling = sync.cancel().then((_) => done = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(done, isFalse);
    store.gate!.complete();
    await cancelling;
    final result = await sync.result;
    expect(result.reason, WSSyncFailure.cancelled);
    expect(result.progress.committed, 2);
    expect(confirmations, 0);
    expect(
        await watch.data.steps
            .query(WSRecordQuery(deviceId: kWsWatchSimDeviceId)),
        hasLength(2));
  });
  for (final audit in [false, true]) {
    test('storage failure (audit=$audit) never confirms', () async {
      store.failWrite = !audit;
      store.failLog = audit;
      await watch.connect(kWsWatchSimDeviceId);
      final result = await watch.data.sync(type: WSHistoryType.steps).result;
      expect(result.reason, WSSyncFailure.storageFailed);
      expect(result.status, WSSyncStatus.incomplete);
      expect(confirmations, 0);
    });
  }
  test('confirmation ACK loss is unknown and has no automatic retry', () async {
    dropConfirmation = true;
    await watch.connect(kWsWatchSimDeviceId);
    final result = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(result.status, WSSyncStatus.confirmationUnknown);
    expect(result.confirmation, WSSyncConfirmation.unknown);
    expect(result.progress.committed, 2);
    expect(confirmations, 1);
    expect(
        (await watch.data.syncLogs(deviceId: kWsWatchSimDeviceId))
            .single
            .confirmation,
        WSSyncConfirmation.unknown);
  });
  test('pending raw payload overflow closes without confirmation', () async {
    device.historyBatchOverride = [100, 0, 1, ...List.filled(100, 0)];
    await watch.connect(kWsWatchSimDeviceId);
    final result = await watch.data.sync(type: WSHistoryType.steps).result;
    expect(result.reason, WSSyncFailure.bufferOverflow);
    expect(confirmations, 0);
  });
}

class _Store extends WSDriftDeviceStore {
  _Store() : super(WSDatabase(NativeDatabase.memory()));
  Completer<void>? gate;
  final writeStarted = Completer<void>();
  bool failWrite = false, failLog = false;
  @override
  Future<WSHistoryWriteResult> writeHistory(
      WSHistoryScope scope, List<WSHistorySample> samples) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await gate?.future;
    if (failWrite) throw StateError('injected write failure');
    return super.writeHistory(scope, samples);
  }

  @override
  Future<void> saveSyncLog(WSSyncLog log) async {
    if (failLog) throw StateError('injected audit failure');
    await super.saveSyncLog(log);
  }
}
