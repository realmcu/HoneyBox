import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../services/jw/history/jw_history_models.dart';
import '../services/jw/history/jw_history_store.dart';
import '../services/jw/jw_codec.dart';
import '../services/jw/jw_configuration.dart';
import '../services/jw/jw_remaining_models.dart';
import 'jw_sdk_acceptance.dart';

abstract interface class JwHistoryReplayAcceptancePort
    implements JwHistoryAcceptancePort {
  Future<void> prepareHistoryReplayIdentity(String expectedDigest);
  Future<JwSubmission> resetHistoryCursor(
      {required JwConfigurationContract contract});
  Future<List<JwHistoryRecord>> historyRecords({String? batchId});
  Stream<JwFrame> get outgoingFrames;
}

/// Read-only inspection of the production, checksummed committed batch IDs.
/// The manifest includes IDs received again even when the journal deduplicates
/// their rows. firstSeenBatch alone cannot establish repeated reception.
Future<List<JwHistoryRecord>> readJwHistoryReplayRecords(
    FileJwHistoryStore store, String deviceKey,
    {String? batchId}) async {
  Set<String>? received;
  if (batchId != null) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(batchId)) {
      throw StateError('Invalid history batch selector');
    }
    final file = File(
        '${store.root.path}/${jwHistoryDigest(deviceKey)}/batches/$batchId.committed.json');
    final lines = const LineSplitter().convert(await file.readAsString());
    if (lines.length != 1) {
      throw StateError('Invalid committed batch entry count');
    }
    final envelope = jsonDecode(lines.single) as Map;
    final p = Map<String, Object?>.from(envelope['payload'] as Map);
    if (envelope['schema'] != 1 ||
        envelope['sha256'] != jwHistoryDigest(p) ||
        p['batchId'] != batchId ||
        p['deviceKey'] != deviceKey ||
        (p['summary'] as Map)['localCommitComplete'] != true) {
      throw StateError('History replay manifest checksum/provenance mismatch');
    }
    received = (p['recordIds'] as List).cast<String>().toSet();
  }
  final inventory = await store.inventory(deviceKey);
  final rows = <JwHistoryRecord>[];
  for (final e in inventory.daysByType.entries) {
    final type = JwHistoryType.values.byName(e.key);
    for (final day in e.value) {
      var offset = 0;
      while (true) {
        final page = await store.query(deviceKey, type,
            day: day, offset: offset, limit: 500);
        rows.addAll(page.records
            .where((r) => received == null || received.contains(r.recordId)));
        offset += page.records.length;
        if (offset >= page.total) break;
        if (page.records.isEmpty) {
          throw StateError('History replay query stalled');
        }
      }
    }
  }
  if (received != null &&
      rows.map((r) => r.recordId).toSet().length != received.length) {
    throw StateError('Committed history batch references missing durable rows');
  }
  return rows;
}

class JwHistoryReplayRun {
  final JwHistoryReplayAcceptancePort port;
  final AcceptanceConfig config;
  final void Function() checkCancellation;
  final Map<String, Object?>? baseline;
  final Future<void> Function(Map<String, Object?>) record;
  final evidence = <String, Object?>{
    'resetTransportAcknowledged': false,
    'resetAppliedProved': false,
    'replayObserved': false,
    'deduplicationProved': false,
    'localRecordsCleared': false,
    'deviceDatasetExhaustive': false,
    'resetScope': 'all_supported_history_cursors',
    'cursorPersistenceAfterReset':
        'firmware may block advancement until reconnect; restart only reads local journals',
  };
  StreamSubscription<JwFrame>? _wire;
  Future<void> _tail = Future.value();
  String? _violation;
  int _resetAttempts = 0;
  bool _resetPermitted = false;
  final _attempts = <Map<String, Object?>>[];
  JwHistoryReplayRun(this.port, this.config, this.baseline, this.record,
      {required this.checkCancellation});
  Future<void> prepare() async {
    await port.prepareHistoryReplayIdentity(config.expectedIdentitySha256!);
    _wire = port.outgoingFrames.listen((frame) {
      final entry = <String, Object?>{
        'type': 'historyReplayWireAttempt',
        'seq': frame.seq,
        'ack': frame.ack
      };
      try {
        if (frame.ack) {
          if (frame.error || frame.payload.isNotEmpty) {
            throw StateError('Invalid host ACK');
          }
        } else {
          final m = JwCodec.decodeL2(frame.payload);
          if (m.fields.length != 1) {
            throw StateError('Unexpected multiple fields');
          }
          final f = m.fields.single,
              tag = '${m.command}/${m.fields.single.key}';
          entry.addAll(
              {'command': m.command, 'key': f.key, 'length': f.value.length});
          final login = tag == '3/3' &&
              f.value.length == 32 &&
              sha256.convert(f.value).toString() ==
                  config.expectedIdentitySha256;
          final query =
              {'2/54', '6/61', '2/79'}.contains(tag) && f.value.isEmpty;
          final sync = config.mode == 'history-replay' &&
              {'5/1', '5/28'}.contains(tag) &&
              f.value.isEmpty;
          final reset = config.mode == 'history-replay' &&
              _resetPermitted &&
              tag == '5/250' &&
              f.value.isEmpty;
          if (tag == '5/250') _resetAttempts++;
          if (!(login || query || sync || reset) || _resetAttempts > 1) {
            throw StateError('Command outside history replay policy: $tag');
          }
          if (login) {
            entry['identitySha256'] = config.expectedIdentitySha256;
          } else {
            entry['l2Hex'] = frame.payload
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join();
          }
        }
        entry['status'] = 'pass';
      } catch (e) {
        _violation ??= e.toString();
        entry.addAll({'status': 'fail', 'error': e.toString()});
      }
      _attempts.add(entry);
      _tail = _tail.then((_) => record(entry));
      _tail.catchError((Object _) {});
    });
  }

  void _check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  void checkDevice(String deviceKey, String identity) {
    final state = port.state;
    _check(
        state.info?.firmware == 'T005' &&
            state.info?.hardware == 'H001' &&
            state.capabilities?.rawHex == config.expectedFunctions &&
            state.capabilities?.factorySwitchRaw == config.expectedFactory &&
            identity == config.expectedIdentitySha256,
        'History replay identity/profile/capabilities mismatch');
    evidence['historyReplayDevice'] = {
      'deviceKey': deviceKey,
      'identitySha256': identity,
      'firmware': 'T005',
      'hardware': 'H001',
      'functionList': config.expectedFunctions,
      'factorySwitch': config.expectedFactory
    };
    _check(_violation == null,
        'History replay wire policy violation: $_violation');
  }

  Future<void> run(Future<JwHistoryResult> Function(int) sync) async {
    if (config.mode == 'history-replay-restart') {
      final b = baseline;
      _check(
          b != null &&
              b['mode'] == 'history-replay' &&
              b['exitCode'] == 0 &&
              b['replayObserved'] == true &&
              b['deduplicationProved'] == true,
          'Invalid successful history replay restart baseline');
      _check(
          jwHistoryCanonicalJson(b!['historyReplayDevice']) ==
              jwHistoryCanonicalJson(evidence['historyReplayDevice']),
          'History replay restart belongs to another device');
      final inventory = await port.historyInventory();
      evidence['inventory'] = inventory.toJson();
      final previous = Map<String, Object?>.from(b['inventory'] as Map);
      final retained = previous['digest'] == inventory.digest &&
          jwHistoryCanonicalJson(previous['recordIds']) ==
              jwHistoryCanonicalJson(inventory.recordIds) &&
          jwHistoryCanonicalJson(previous['counts']) ==
              jwHistoryCanonicalJson(inventory.counts);
      evidence['persistedBaselineRetained'] = retained;
      _check(retained,
          'History replay persistent IDs/counts changed after independent restart');
      return;
    }
    final before = await port.historyInventory();
    evidence['initialInventory'] = before.toJson();
    final baseRound = await sync(1);
    final baseRows = await port.historyRecords(batchId: baseRound.batchId);
    final inventory = await port.historyInventory();
    final retained = await port.historyRecords();
    final known = {for (final r in retained) r.recordId: r};
    evidence.addAll({
      'baselineRound': baseRound.toJson(),
      'baselineReceivedRecords': baseRows.map((r) => r.toJson()).toList(),
      'baselineInventory': inventory.toJson()
    });
    _check(_violation == null,
        'History replay wire policy violation: $_violation');
    checkCancellation();
    _resetPermitted = true;
    final submission = await port.resetHistoryCursor(
        contract: JwConfigurationContract.v101S200);
    _resetPermitted = false;
    evidence['resetTransportAcknowledged'] = submission.acknowledged;
    await record({
      'type': 'historyCursorResetSubmitted',
      'command': submission.command,
      'key': submission.key,
      'valueLength': submission.raw.length,
      'transportAcknowledged': submission.acknowledged,
      'appliedProved': false
    });
    _check(
        _violation == null, 'History reset wire policy violation: $_violation');
    final replay = await sync(2);
    final rows = await port.historyRecords(batchId: replay.batchId);
    final after = await port.historyInventory();
    final repeated = rows
        .where((r) =>
            known[r.recordId]?.rawSha256 == r.rawSha256 &&
            known[r.recordId]?.rawHex == r.rawHex)
        .toList();
    final newIds =
        after.recordIds.toSet().difference(inventory.recordIds.toSet());
    final expectedNew = rows
        .map((r) => r.recordId)
        .toSet()
        .difference(inventory.recordIds.toSet());
    final retainedIds = inventory.recordIds.every(after.recordIds.contains);
    final inserted =
        replay.counts.values.fold<int>(0, (n, s) => n + s.newlyPersisted);
    final dedup =
        replay.counts.values.fold<int>(0, (n, s) => n + s.deduplicated);
    final matchedNew = newIds.length == expectedNew.length &&
        newIds.containsAll(expectedNew) &&
        inserted == newIds.length;
    final proved = repeated.isNotEmpty &&
        retainedIds &&
        matchedNew &&
        dedup >= repeated.length;
    evidence.addAll({
      'replayRound': replay.toJson(),
      'replayReceivedRecords': rows.map((r) => r.toJson()).toList(),
      'repeatedRecords': repeated
          .map((r) => {
                'recordId': r.recordId,
                'type': r.type.name,
                'rawSha256': r.rawSha256,
                'rawHex': r.rawHex
              })
          .toList(),
      'repeatedRecordCount': repeated.length,
      'replayObserved': repeated.isNotEmpty,
      'resetAppliedProved': repeated.isNotEmpty,
      'deduplicationProved': proved,
      'persistedBaselineRetained': retainedIds,
      'newUniqueRecordCount': newIds.length,
      'inventory': after.toJson(),
      'proofGaps': JwHistoryType.values
          .where((t) => !repeated.any((r) => r.type == t))
          .map((t) => t.name)
          .toList()
    });
    _check(proved,
        'Reset ACK does not prove replay: no matching retained records or durable deduplication proof');
  }

  Future<void> finish() async {
    await _wire?.cancel();
    await _tail;
    evidence['historyReplayWireAudit'] = {
      'status': _violation == null ? 'pass' : 'fail',
      'attempts': _attempts,
      'resetAttempts': _resetAttempts,
      'error': _violation
    };
    _check(_violation == null, 'History replay wire audit failed: $_violation');
    if (config.mode == 'history-replay' &&
        evidence['resetTransportAcknowledged'] == true) {
      _check(_resetAttempts == 1,
          'Reset submission has no unique actual outgoing wire proof');
    }
  }
}
