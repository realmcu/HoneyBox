import 'dart:typed_data';
import 'dart:async';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/validation/jw_history_replay_acceptance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/services/jw/jw_configuration.dart';
import 'package:honeybox/services/jw/jw_remaining_models.dart';
import 'package:honeybox/validation/jw_sdk_acceptance.dart';
import 'jw_sdk_history_acceptance_test.dart' show HistoryPort, round;

JwHistoryRecord row(int value) => JwHistoryRecord(
    deviceKey: 'jw:64:1A:B2:B8:00:3A',
    type: JwHistoryType.sleep,
    key: 9,
    wireVersion: 1,
    sourceIdentity: 'retained',
    sourceTimeBasis: 'device',
    day: '2026-10-05',
    rawHex: value.toRadixString(16).padLeft(2, '0'),
    firstSeenBatch: 'old',
    firstSeenOrdinal: 0,
    values: {},
    sourceTime: {},
    validity: {});

class ReplayPort extends HistoryPort implements JwHistoryReplayAcceptancePort {
  final _wire = StreamController<JwFrame>.broadcast(sync: true);
  @override
  Stream<JwFrame> get outgoingFrames => _wire.stream;
  int resets = 0, preparations = 0;
  bool emptyReplay = false,
      distinctReplay = false,
      emptyBaseline = false,
      forbiddenWrite = false;
  bool cancelBeforeReset = false, cancelled = false;
  final retained = row(1);
  ReplayPort() {
    ids = [retained.recordId];
    state = state.copyWith(
        info: const JwDeviceInfo(
            deviceKey: '', firmware: 'T005', hardware: 'H001'));
  }
  @override
  Future<void> prepareHistoryReplayIdentity(String expected) async {
    preparations++;
  }

  @override
  Future<JwSubmission> resetHistoryCursor(
      {required JwConfigurationContract contract}) async {
    resets++;
    if (forbiddenWrite) {
      _wire.add(JwFrame(
          2,
          false,
          false,
          JwCodec.encodeL2(2, [
            JwField(1, Uint8List.fromList([1]))
          ])));
    }
    _wire.add(JwFrame(
        1, false, false, JwCodec.encodeL2(5, [JwField(250, Uint8List(0))])));
    return JwSubmission(5, 250, const []);
  }

  @override
  Future<List<JwHistoryRecord>> historyRecords({String? batchId}) async {
    if (batchId == null && cancelBeforeReset) cancelled = true;
    if (batchId == null) {
      return [retained, if (distinctReplay && rounds > 1) row(2)];
    }
    return emptyReplay || (emptyBaseline && rounds == 1)
        ? []
        : [distinctReplay && rounds > 1 ? row(2) : retained];
  }

  @override
  Future<JwHistoryResult> syncHistory(JwHistoryOptions options) async {
    rounds++;
    if (distinctReplay && rounds > 1) {
      ids = [retained.recordId, row(2).recordId];
    }
    final empty = emptyReplay || (emptyBaseline && rounds == 1);
    final base = round(
        received: empty ? 0 : 1,
        inserted: distinctReplay && rounds > 1 ? 1 : 0);
    return JwHistoryResult(
        batchId: 'b$rounds',
        phase: base.phase,
        counts: {
          JwHistoryType.sleep: JwHistoryTypeStats(
              received: empty ? 0 : 1,
              uniqueInBatch: empty ? 0 : 1,
              newlyPersisted: distinctReplay && rounds > 1 ? 1 : 0,
              deduplicated: empty || distinctReplay ? 0 : 1)
        },
        expectedMarkers: base.expectedMarkers,
        observedMarkers: base.observedMarkers,
        startReceived: true,
        traditionalEndReceived: true,
        wireRoundComplete: true,
        localCommitComplete: true,
        applicationAckTransportDelivered: true,
        countValidation: 'minimumSatisfied');
  }
}

void main() {
  Future<Map<String, Object?>> run(ReplayPort p,
          {String mode = 'history-replay', Map<String, Object?>? baseline}) =>
      AcceptanceRunner(
          port: p,
          config: AcceptanceConfig(
              outputDirectory: 'unused',
              address: '64:1A:B2:B8:00:3A',
              mode: mode,
              historyBaselineFile:
                  mode.endsWith('restart') ? 'baseline.json' : null,
              expectedIdentitySha256: 'd' * 64,
              expectedFunctions: '4dd17dfce34ad83d',
              expectedFactory: 3),
          record: (_) async {},
          historyBaseline: baseline,
          isCancelled: () => p.cancelled,
          delay: p.delay,
          now: () => p.clock).run();
  test('cancellation after baseline inspection sends no reset', () async {
    final p = ReplayPort()..cancelBeforeReset = true;
    final r = await run(p);
    expect(p.resets, 0);
    expect(r['exitCode'], 2);
    expect(p.disconnects, 1);
  });
  test(
      'replay resets once between baseline and replay and proves real repeated rows',
      () async {
    final p = ReplayPort();
    final r = await run(p);
    expect(p.resets, 1);
    expect(p.rounds, 2);
    expect(p.preparations, 1);
    expect(r['replayObserved'], true);
    expect(r['deduplicationProved'], true);
    expect(r['exitCode'], 0);
  });
  test('ACK with empty replay cannot pass reset acceptance', () async {
    final p = ReplayPort()..emptyReplay = true;
    final r = await run(p);
    expect(r['replayObserved'], false);
    expect(r['exitCode'], 1);
    expect(r['inventory'], isA<Map>());
  });
  test('new rows alone cannot prove replay of previously persisted data',
      () async {
    final p = ReplayPort()..distinctReplay = true;
    final r = await run(p);
    expect(r['replayObserved'], false);
    expect(r['exitCode'], 1);
  });
  test('wire violation still disconnects the owned connection', () async {
    final p = ReplayPort()..forbiddenWrite = true;
    final r = await run(p);
    expect(r['exitCode'], 1);
    expect(p.disconnects, 1);
    expect(p.rounds, 1);
  });
  test(
      'independent restart retains IDs and counts without another reset or sync',
      () async {
    final previous = await run(ReplayPort());
    final p = ReplayPort();
    final r = await run(p, mode: 'history-replay-restart', baseline: previous);
    expect(r['exitCode'], 0);
    expect(r['persistedBaselineRetained'], true);
    expect(p.resets, 0);
    expect(p.rounds, 0);
  });
  test('independent restart rejects missing durable IDs', () async {
    final previous = await run(ReplayPort());
    final p = ReplayPort()..ids = [];
    final r = await run(p, mode: 'history-replay-restart', baseline: previous);
    expect(r['exitCode'], 1);
    expect(p.resets, 0);
  });
  test(
      'already consumed empty baseline can prove replay against preserved durable rows',
      () async {
    final p = ReplayPort()..emptyBaseline = true;
    final r = await run(p);
    expect(r['replayObserved'], true);
    expect(r['exitCode'], 0);
    expect(p.resets, 1);
  });
}
