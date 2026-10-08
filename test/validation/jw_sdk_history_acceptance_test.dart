import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/validation/jw_sdk_acceptance.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'jw_sdk_acceptance_test.dart' show TestPort;

JwHistoryResult round({String? failure, int received = 1, int inserted = 1}) =>
    JwHistoryResult(
        batchId: 'b',
        phase:
            failure == null ? JwHistoryPhase.completed : JwHistoryPhase.failed,
        counts: {
          for (final t in JwHistoryType.values)
            t: JwHistoryTypeStats(
                received: t == JwHistoryType.sleep ? received : 0,
                newlyPersisted: t == JwHistoryType.sleep ? inserted : 0)
        },
        expectedMarkers: [91, 96, 100],
        observedMarkers: [91, 96, 100],
        startReceived: true,
        traditionalEndReceived: true,
        failureStage: failure,
        error: failure,
        wireRoundComplete: failure == null,
        localCommitComplete: failure == null,
        applicationAckTransportDelivered: failure == null,
        countValidation: 'minimumSatisfied');

class HistoryPort extends TestPort implements JwHistoryAcceptancePort {
  int rounds = 0, cancels = 0;
  List<String> ids = ['a' * 64];
  String? failure;
  bool pending = false;
  final gate = Completer<JwHistoryResult>();
  @override
  Future<JwHistoryResult> syncHistory(JwHistoryOptions options) async {
    rounds++;
    if (pending) return gate.future;
    if (failure != null) {
      throw JwHistoryException(failure!, round(failure: failure));
    }
    return round(inserted: rounds == 1 ? 1 : 0);
  }

  @override
  Future<JwHistoryInventory> historyInventory() async => JwHistoryInventory(
      recordIds: ids, counts: {'sleep': ids.length}, ackByBatch: {});
  @override
  Future<void> cancelHistory() async {
    cancels++;
    if (!gate.isCompleted) {
      gate.completeError(
          JwHistoryException('cancelled', round(failure: 'cancelled')));
    }
  }
}

class StrictHistoryPort extends HistoryPort {
  @override
  JwDeviceState get state {
    if (closed) throw StateError('Port already closed');
    return super.state;
  }
}

void main() {
  AcceptanceConfig config({String mode = 'history'}) => AcceptanceConfig(
      outputDirectory: 'unused',
      address: '64:1A:B2:B8:00:3A',
      mode: mode,
      expectedIdentitySha256: mode == 'history-restart' ? 'd' * 64 : null,
      historyBaselineFile: mode == 'history-restart' ? 'baseline.json' : null);
  Future<Map<String, Object?>> run(HistoryPort p,
          {String mode = 'history',
          Map<String, Object?>? baseline,
          bool Function()? cancelled}) =>
      AcceptanceRunner(
              port: p,
              config: config(mode: mode),
              record: (_) async {},
              now: () => p.clock,
              delay: p.delay,
              isCancelled: cancelled,
              historyBaseline: baseline)
          .run();
  test(
      'history config accepts explicit bounds and rejects invalid round/options',
      () {
    final c = AcceptanceConfig.parse([
      '--address',
      '64:1A:B2:B8:00:3A',
      '--mode',
      'history',
      '--history-rounds',
      '2',
      '--history-idle-seconds',
      '45',
      '--history-total-seconds',
      '2400'
    ]);
    expect(c.historyOptions.idleTimeout, const Duration(seconds: 45));
    expect(
        () => AcceptanceConfig(
            outputDirectory: 'unused',
            address: '64:1A:B2:B8:00:3A',
            mode: 'history',
            historyRounds: 0),
        throwsArgumentError);
  });
  test(
      'history performs two observed rounds through real rediscovery and no phase1 setting commands',
      () async {
    final p = HistoryPort();
    final r = await run(p);
    expect(r['exitCode'], 0);
    expect(r['schemaVersion'], 2);
    expect(r['deviceDatasetExhaustive'], false);
    expect(p.rounds, 2);
    expect(p.connections, 2);
    expect(p.languages, isEmpty);
    expect(p.hearts, isEmpty);
    expect(p.times, isEmpty);
    expect(r['historyRounds'], hasLength(2));
    expect(r['nonemptyObservedTypes'], ['sleep']);
    expect(r['inventory'], isA<Map>());
    expect(p.closed, true);
  });
  test(
      'history restart reads persisted inventory without issuing history or phase1 commands',
      () async {
    final p = HistoryPort()..ids = ['a' * 64, 'b' * 64];
    final r = await run(p, mode: 'history-restart', baseline: {
      'inventory': {
        'recordIds': ['a' * 64],
        'digest': 'previous'
      }
    });
    expect(r['exitCode'], 0);
    expect(p.rounds, 0);
    expect(r['persistedBaselineRetained'], true);
    expect(r['exactInventoryDigestMatch'], false);
    expect(p.hearts, isEmpty);
    expect(p.times, isEmpty);
    expect(p.languages, isEmpty);
  });
  test('missing persisted record fails independent restart', () async {
    final p = HistoryPort()..ids = ['b' * 64];
    final r = await run(p, mode: 'history-restart', baseline: {
      'inventory': {
        'recordIds': ['a' * 64]
      }
    });
    expect(r['exitCode'], 1);
    expect(r['error'], contains('persisted'));
    expect(p.rounds, 0);
    expect(p.closed, true);
  });
  test('history timeout retains typed failure and cannot report complete',
      () async {
    final p = HistoryPort()..failure = 'idleTimeout';
    final r = await run(p);
    expect(r['exitCode'], 1);
    expect(r['failureStage'], 'idleTimeout');
    expect((r['historyRounds'] as List).single['localCommitComplete'], false);
    expect(p.rounds, 1);
  });
  test('history final report never reads a disposed production container',
      () async {
    final p = StrictHistoryPort();
    final r = await run(p);
    expect(r['exitCode'], 0);
    expect(r['historyDeviceKey'], 'jw:64:1A:B2:B8:00:3A');
  });
  test('history cancellation directly cancels active operation and exits two',
      () async {
    final p = HistoryPort()..pending = true;
    final r =
        await run(p, cancelled: () => p.rounds > 0 && p.clock.second >= 1);
    expect(r['exitCode'], 2);
    expect(p.cancels, 1);
    expect(p.closed, true);
    expect(p.rounds, 1);
  });
}
