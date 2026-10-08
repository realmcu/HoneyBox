import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/services/jw/history/jw_history_store.dart';
import 'package:honeybox/validation/jw_history_replay_acceptance.dart';
import 'jw_history_replay_acceptance_test.dart' show row;

void main() {
  test(
      'actual durable duplicate batch contains received IDs despite unchanged firstSeenBatch',
      () async {
    final dir = await Directory.systemTemp.createTemp('jw_replay_store_');
    final store = FileJwHistoryStore(dir);
    await store.open();
    final record = row(1);
    try {
      await store.beginBatch('baseline', record.deviceKey);
      expect((await store.append('baseline', [record])).insertedIds,
          [record.recordId]);
      await store.commit(JwHistoryBatchCommit(
          batchId: 'baseline',
          deviceKey: record.deviceKey,
          recordIds: [record.recordId],
          summary: {'localCommitComplete': true}));
      await store.beginBatch('replay', record.deviceKey);
      expect((await store.append('replay', [record])).existingIds,
          [record.recordId]);
      await store.commit(JwHistoryBatchCommit(
          batchId: 'replay',
          deviceKey: record.deviceKey,
          recordIds: [record.recordId],
          summary: {'localCommitComplete': true}));
      final proof = await readJwHistoryReplayRecords(store, record.deviceKey,
          batchId: 'replay');
      expect(proof.single.recordId, record.recordId);
      expect(proof.single.rawHex, record.rawHex);
      expect(proof.single.firstSeenBatch, 'old');
      expect((await store.inventory(record.deviceKey)).recordCount, 1);
      await store.close();
      final restarted = FileJwHistoryStore(dir);
      await restarted.open();
      expect((await restarted.inventory(record.deviceKey)).recordIds,
          [record.recordId]);
      await restarted.close();
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });
  test('corrupt batch checksum cannot become replay proof', () async {
    final dir = await Directory.systemTemp.createTemp('jw_replay_corrupt_');
    final store = FileJwHistoryStore(dir);
    await store.open();
    final record = row(1);
    try {
      await store.beginBatch('replay', record.deviceKey);
      await store.append('replay', [record]);
      await store.commit(JwHistoryBatchCommit(
          batchId: 'replay',
          deviceKey: record.deviceKey,
          recordIds: [record.recordId],
          summary: {'localCommitComplete': true}));
      final file = File(
          '${dir.path}/${jwHistoryDigest(record.deviceKey)}/batches/replay.committed.json');
      final envelope = jsonDecode(await file.readAsString()) as Map;
      envelope['sha256'] = '0' * 64;
      await file.writeAsString('${jsonEncode(envelope)}\n', flush: true);
      await expectLater(
          readJwHistoryReplayRecords(store, record.deviceKey,
              batchId: 'replay'),
          throwsStateError);
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });
}
