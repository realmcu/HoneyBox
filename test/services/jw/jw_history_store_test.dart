import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/history/jw_history_decoder.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/services/jw/history/jw_history_store.dart';
import '../../helpers/jw_fixture.dart';

class FailFlushIo implements JwHistoryJournalIo {
  final delegate = FileJwHistoryJournalIo();
  @override
  Future<void> append(File f, String line) => delegate.append(f, line);
  @override
  Future<void> flush() =>
      Future.error(const FileSystemException('flush failed'));
  @override
  Future<void> close() => delegate.close();
}

JwHistoryRecord readiness(
    {String device = 'jw:test',
    int score = 82,
    String batch = 'b1',
    int day = 4}) {
  final bytes =
      Uint8List.fromList(jwHex('ea070a04000352fe030937002f00a40103000000'));
  bytes[6] = score;
  bytes[3] = day;
  return decodeJwHistoryField(device, 100, bytes,
          batchId: batch, firstSeenOrdinal: 0)
      .single;
}

class FailReferenceAppendIo implements JwHistoryJournalIo {
  final delegate = FileJwHistoryJournalIo();
  bool failReferences = false;
  @override
  Future<void> append(File file, String line) async {
    final payload = (jsonDecode(line) as Map)['payload'] as Map;
    if (failReferences && payload['kind'] == 'recordReference') {
      throw const FileSystemException('record reference append failed');
    }
    await delegate.append(file, line);
  }

  @override
  Future<void> flush() => delegate.flush();
  @override
  Future<void> close() => delegate.close();
}

String fixtureEnvelope(Map<String, Object?> payload) => '${jsonEncode({
          'schema': 1,
          'payload': payload,
          'sha256': jwHistoryDigest(payload)
        })}\n';

Future<void> seedJournalFile(
    File file, Iterable<Map<String, Object?>> payloads) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(payloads.map(fixtureEnvelope).join(), flush: true);
}

Future<List<JwHistoryRecord>> seedLargeJournal(Directory root) async {
  // Synthetic valid decoder records, seeded before open to avoid 16001 flushes.
  final rows = <JwHistoryRecord>[];
  for (var i = 0; i < 16001; i++) {
    final bytes =
        Uint8List.fromList([0x35, 0x44, 0, 1, 0, 0, 0, 0, 0, 0, i % 60, 80]);
    ByteData.sublistView(bytes).setUint16(8, i ~/ 60);
    rows.add(decodeJwHistoryField('jw:test', 0x1b, bytes,
            batchId: 'bulk', firstSeenOrdinal: i)
        .single);
  }
  final device = '${root.path}/${jwHistoryDigest('jw:test')}';
  await seedJournalFile(
      File('$device/records/heartTemperature/2026-10-04.jsonl'),
      rows.map((r) => r.toJson()));
  await seedJournalFile(File('$device/batches/bulk.events.jsonl'), [
    {'kind': 'begin', 'batchId': 'bulk', 'deviceKey': 'jw:test'},
    {
      'kind': 'ack',
      'batchId': 'bulk',
      'deviceKey': 'jw:test',
      'status': 'requested'
    },
  ]);
  await seedJournalFile(File('$device/batches/bulk.committed.json'), [
    JwHistoryBatchCommit(
        batchId: 'bulk',
        deviceKey: 'jw:test',
        recordIds: rows.map((r) => r.recordId)).toJson(),
  ]);
  return rows;
}

void main() {
  late Directory root;
  late FileJwHistoryStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('jw-history-store-');
    store = FileJwHistoryStore(root);
    await store.open();
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });
  test('a damaged published commit is corruption, never a recoverable tail',
      () async {
    final row = readiness();
    await store.append('b1', [row]);
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b1', deviceKey: 'jw:test', recordIds: [row.recordId]));
    await store.inventory('jw:test');
    await store.query('jw:test', JwHistoryType.readiness, day: '2026-10-04');
    await store.close();
    final manifest = (await root
            .list(recursive: true)
            .where((e) => e is File && e.path.endsWith('.committed.json'))
            .toList())
        .single as File;
    await manifest.writeAsString('{}');
    store = FileJwHistoryStore(root);
    await expectLater(store.open(), throwsFormatException);
    expect(await manifest.readAsString(), '{}');
  });
  test('multiple restarts count each torn-tail recovery exactly once',
      () async {
    await store.append('b1', [readiness()]);
    await store.close();
    final shard = (await root
            .list(recursive: true)
            .where((e) => e is File && e.path.endsWith('2026-10-04.jsonl'))
            .toList())
        .single as File;
    for (var count = 1; count <= 2; count++) {
      await shard.writeAsString('{torn', mode: FileMode.append);
      store = FileJwHistoryStore(root);
      await store.open();
      expect((await store.inventory('jw:test')).recoveredTails, count);
      await store.close();
    }
  });
  test('duplicates remain one physical record across close and reopen',
      () async {
    final row = readiness();
    final inserted = await store.append('b1', [row]);
    expect(inserted.insertedIds, {row.recordId});
    final repeated = await store.append('b2', [readiness(batch: 'b2')]);
    expect(repeated.existingIds, {row.recordId});
    await store.close();
    store = FileJwHistoryStore(root);
    await store.open();
    expect((await store.inventory('jw:test')).recordCount, 1);
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-04');
    expect(page.records.single.values['score'], 82);
    expect(page.partialRecordIds, {row.recordId});
  });
  test(
      'distinct revisions survive while old payload replay cannot reverse latest',
      () async {
    final old = readiness(), newer = readiness(score: 83);
    await store.append('b1', [old, newer]);
    await store.append('b2', [old]);
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-04');
    expect(page.records, hasLength(2));
    expect(page.latestBySourceIdentity.single.values['score'], 83);
  });
  test('saved device catalog is restored independently of BLE or login',
      () async {
    await store.append('b1', [readiness()]);
    await store.append('other', [readiness(device: 'jw:other')]);
    await store.close();
    store = FileJwHistoryStore(root);
    await store.open();
    expect(await store.deviceKeys(), ['jw:other', 'jw:test']);
  });
  test('device ownership is isolated only by data key, without login gate',
      () async {
    await store.append('b1', [readiness()]);
    await store.append('bOther', [readiness(device: 'jw:other')]);
    expect((await store.inventory('jw:test')).recordCount, 1);
    expect((await store.inventory('jw:other')).recordCount, 1);
  });
  test(
      'committed references make duplicate rows durable and ACK requested stays unknown',
      () async {
    final row = readiness();
    await store.append('b1', [row]);
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b2', deviceKey: 'jw:test', recordIds: [row.recordId]));
    await store.noteAck('b2', 'requested');
    await store.close();
    store = FileJwHistoryStore(root);
    await store.open();
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-04');
    expect(page.partialRecordIds, isEmpty);
    expect((await store.inventory('jw:test')).ackByBatch['b2'], 'unknown');
    await expectLater(
        store.commit(JwHistoryBatchCommit(
            batchId: 'b2', deviceKey: 'jw:test', recordIds: [])),
        throwsStateError);
  });
  test('only torn last entry is trimmed; complete corruption is an error',
      () async {
    await store.append('b1', [readiness()]);
    await store.close();
    final shard = (await root
            .list(recursive: true)
            .where((e) => e is File && e.path.endsWith('2026-10-04.jsonl'))
            .toList())
        .single as File;
    await shard.writeAsString('{"schema":', mode: FileMode.append);
    store = FileJwHistoryStore(root);
    await store.open();
    expect((await store.inventory('jw:test')).recordCount, 1);
    expect((await store.inventory('jw:test')).recoveredTails, 1);
    await store.close();
    await shard.writeAsString('{"schema":1,"payload":{},"sha256":"wrong"}\n',
        mode: FileMode.append);
    store = FileJwHistoryStore(root);
    await expectLater(store.open(), throwsFormatException);
  });
  test(
      'query enforces bounded pages and invalid day cannot traverse directories',
      () async {
    await store.append('b1', [readiness(), readiness(score: 83)]);
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04', offset: 1, limit: 1))
            .records
            .single
            .values['score'],
        83);
    await expectLater(
        store.query('jw:test', JwHistoryType.readiness,
            day: '2026-10-04', limit: 501),
        throwsRangeError);
    await expectLater(
        store.query('jw:test', JwHistoryType.readiness, day: '../escape'),
        throwsFormatException);
  });
  test('another local writer fails fast and lock is released after close',
      () async {
    final competing = FileJwHistoryStore(root);
    await expectLater(competing.open(), throwsStateError);
    await store.close();
    await competing.open();
    await competing.close();
  });
  test('actual cross-process byte-range lock rejects a foreign writer',
      () async {
    expect(await File('${root.path}/writer.lock').exists(), isTrue);
    final script = File('${root.path}/lock-probe.ps1');
    await script.writeAsString(
        r'''$s=[System.IO.File]::Open($args[0],[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::ReadWrite)
try {$s.Lock(0,1); exit 0} catch {exit 3} finally {$s.Dispose()}
''');
    final result = await Process.run('powershell.exe',
        ['-NoProfile', '-File', script.path, '${root.path}/writer.lock']);
    expect(result.exitCode, 3,
        reason: 'OS lock must protect a separate process');
  }, skip: !Platform.isWindows);
  test('flush failure is surfaced and forbids a batch commit', () async {
    await store.close();
    store = FileJwHistoryStore(root, journalIo: FailFlushIo());
    await store.open();
    await expectLater(
        store.append('b1', [readiness()]), throwsA(isA<FileSystemException>()));
    await expectLater(
        store.commit(JwHistoryBatchCommit(
            batchId: 'b1', deviceKey: 'jw:test', recordIds: [])),
        throwsStateError);
  });
  test('daily query orders source time, inventory exposes saved days',
      () async {
    final laterBytes = Uint8List.fromList(jwHex('3544000105460002'));
    final earlierBytes = Uint8List.fromList(jwHex('3544000105000002'));
    final later = decodeJwHistoryField('jw:test', 3, laterBytes,
            batchId: 'b1', firstSeenOrdinal: 0)
        .single;
    final earlier = decodeJwHistoryField('jw:test', 3, earlierBytes,
            batchId: 'b1', firstSeenOrdinal: 1)
        .single;
    await store.append('b1', [later, earlier]);
    final page = await store.query('jw:test', JwHistoryType.sleep,
        day: '2026-10-04', limit: 1);
    expect(page.records.single.recordId, earlier.recordId);
    expect(
        (await store.inventory('jw:test')).daysByType['sleep'], ['2026-10-04']);
  });
  test('warm reads refresh appended dates revisions and partial rows',
      () async {
    final old = readiness();
    await store.append('b1', [old]);
    expect((await store.inventory('jw:test')).recordCount, 1);
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04'))
            .total,
        1);
    final revised = readiness(score: 83, batch: 'b2');
    final nextDay = readiness(day: 5, batch: 'b2');
    await store.append('b2', [revised, nextDay]);
    final inventory = await store.inventory('jw:test');
    expect(inventory.recordCount, 3);
    expect(inventory.daysByType['readiness'], ['2026-10-04', '2026-10-05']);
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-04');
    expect(page.total, 2);
    expect(page.latestBySourceIdentity.single.values['score'], 83);
    expect(page.partialRecordIds, {old.recordId, revised.recordId});
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-05'))
            .records
            .single
            .recordId,
        nextDay.recordId);
  });
  test('warm partial visibility becomes committed without reopening', () async {
    final row = readiness();
    await store.append('b1', [row]);
    await store.inventory('jw:test');
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04'))
            .partialRecordIds,
        {row.recordId});
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b1', deviceKey: 'jw:test', recordIds: [row.recordId]));
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-04');
    expect(page.partialRecordIds, isEmpty);
    expect(page.records.single.values['score'], 82);
    expect((await store.inventory('jw:test')).recordCount, 1);
  });
  test('warm committed visibility reverts to partial after batch failure',
      () async {
    final row = readiness();
    await store.append('b1', [row]);
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b1', deviceKey: 'jw:test', recordIds: [row.recordId]));
    await store.inventory('jw:test');
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04'))
            .partialRecordIds,
        isEmpty);
    await store.noteFailure('b1', 'confirming', 'transport disconnected');
    expect(
        (await store.inventory('jw:test')).batchFailures, {'b1': 'confirming'});
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04'))
            .partialRecordIds,
        {row.recordId});
  });
  test('warm ACK metadata preserves requested unknown then delivered status',
      () async {
    final row = readiness();
    await store.append('b1', [row]);
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b1', deviceKey: 'jw:test', recordIds: [row.recordId]));
    expect((await store.inventory('jw:test')).ackByBatch, isEmpty);
    await store.query('jw:test', JwHistoryType.readiness, day: '2026-10-04');
    await store.noteAck('b1', 'requested');
    expect((await store.inventory('jw:test')).ackByBatch, {'b1': 'unknown'});
    await store.noteAck('b1', 'transportDelivered');
    expect((await store.inventory('jw:test')).ackByBatch,
        {'b1': 'transportDelivered'});
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04'))
            .partialRecordIds,
        isEmpty);
  });
  test(
      'failed reference append exposes the durable partial row after warm reads',
      () async {
    await store.close();
    final io = FailReferenceAppendIo();
    store = FileJwHistoryStore(root, journalIo: io);
    await store.open();
    final first = readiness();
    await store.append('b1', [first]);
    await store.inventory('jw:test');
    await store.query('jw:test', JwHistoryType.readiness, day: '2026-10-04');
    final durable = readiness(day: 5, batch: 'b2');
    io.failReferences = true;
    await expectLater(
        store.append('b2', [durable]), throwsA(isA<FileSystemException>()));
    final inventory = await store.inventory('jw:test');
    expect(inventory.recordCount, 2);
    expect(inventory.daysByType['readiness'], ['2026-10-04', '2026-10-05']);
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-05');
    expect(page.records.single.recordId, durable.recordId);
    expect(page.partialRecordIds, {durable.recordId});
    await expectLater(
        store.noteFailure('b2', 'failed', 'write failure'), throwsStateError);
  });
  test('warm metadata stays isolated across five devices and failure updates',
      () async {
    for (var i = 0; i < 5; i++) {
      final row = readiness(device: 'jw:$i', batch: 'device$i', score: 80 + i);
      await store.append('device$i', [row]);
      await store.commit(JwHistoryBatchCommit(
          batchId: 'device$i', deviceKey: 'jw:$i', recordIds: [row.recordId]));
    }
    for (var i = 0; i < 5; i++) {
      expect((await store.inventory('jw:$i')).recordCount, 1);
      expect(
          (await store.query('jw:$i', JwHistoryType.readiness,
                  day: '2026-10-04'))
              .partialRecordIds,
          isEmpty);
    }
    await store.noteFailure('device2', 'receiving', 'device failed');
    for (var i = 4; i >= 0; i--) {
      final page = await store.query('jw:$i', JwHistoryType.readiness,
          day: '2026-10-04');
      expect(page.records.single.values['score'], 80 + i);
      expect(page.partialRecordIds.length, i == 2 ? 1 : 0);
      expect((await store.inventory('jw:$i')).batchFailures,
          i == 2 ? {'device2': 'receiving'} : <String, String>{});
    }
  });
  test(
      'above sixteen thousand IDs complete inventory and visibility stay fresh',
      () async {
    await store.close();
    final rows = await seedLargeJournal(root);
    store = FileJwHistoryStore(root);
    await store.open();
    expect((await store.inventory('jw:test')).recordCount, 16001);
    final last = await store.query('jw:test', JwHistoryType.heartTemperature,
        day: '2026-10-04', offset: 16000, limit: 1);
    expect(last.total, 16001);
    expect(last.records.single.recordId, rows.last.recordId);
    expect(last.partialRecordIds, isEmpty);
    await store.noteAck('bulk', 'transportDelivered');
    final delivered = await store.inventory('jw:test');
    expect(delivered.recordCount, 16001);
    expect(delivered.daysByType['heartTemperature'], ['2026-10-04']);
    expect(delivered.ackByBatch, {'bulk': 'transportDelivered'});
    expect(
        (await store.query('jw:test', JwHistoryType.heartTemperature,
                day: '2026-10-04', offset: 16000, limit: 1))
            .partialRecordIds,
        isEmpty);
    await store.noteFailure('bulk', 'confirming', 'failed after commit');
    expect(
        (await store.query('jw:test', JwHistoryType.heartTemperature,
                day: '2026-10-04', offset: 16000, limit: 1))
            .partialRecordIds,
        {rows.last.recordId});
    expect((await store.inventory('jw:test')).batchFailures,
        {'bulk': 'confirming'});
  });
  test(
      'above batch map bounds uncached metadata keeps every entry and visibility',
      () async {
    await store.close();
    final row = readiness(batch: 'selected');
    final device = '${root.path}/${jwHistoryDigest('jw:test')}';
    await seedJournalFile(
        File('$device/records/readiness/2026-10-04.jsonl'), [row.toJson()]);
    await seedJournalFile(File('$device/batches/selected.committed.json'), [
      JwHistoryBatchCommit(
          batchId: 'selected',
          deviceKey: 'jw:test',
          recordIds: [row.recordId]).toJson(),
    ]);
    await seedJournalFile(File('$device/batches/selected.events.jsonl'), [
      {'kind': 'begin', 'batchId': 'selected', 'deviceKey': 'jw:test'},
      {
        'kind': 'ack',
        'batchId': 'selected',
        'deviceKey': 'jw:test',
        'status': 'requested'
      },
    ]);
    await Future.wait([
      for (var i = 0; i < 256; i++)
        seedJournalFile(File('$device/batches/failure$i.events.jsonl'), [
          {'kind': 'begin', 'batchId': 'failure$i', 'deviceKey': 'jw:test'},
          {
            'kind': 'failure',
            'batchId': 'failure$i',
            'deviceKey': 'jw:test',
            'stage': 'receiving$i',
            'message': 'fixture failure'
          },
        ])
    ]);
    store = FileJwHistoryStore(root);
    await store.open();
    final initial = await store.inventory('jw:test');
    expect(initial.recordCount, 1);
    expect(initial.batchFailures.length, 256);
    expect(initial.batchFailures['failure255'], 'receiving255');
    expect(initial.ackByBatch, {'selected': 'unknown'});
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04'))
            .partialRecordIds,
        isEmpty);
    await store.noteAck('selected', 'transportDelivered');
    expect((await store.inventory('jw:test')).ackByBatch,
        {'selected': 'transportDelivered'});
    await store.noteFailure('selected', 'confirming', 'new failure');
    final failed = await store.inventory('jw:test');
    expect(failed.batchFailures.length, 257);
    expect(failed.batchFailures['failure0'], 'receiving0');
    expect(failed.batchFailures['selected'], 'confirming');
    expect(
        (await store.query('jw:test', JwHistoryType.readiness,
                day: '2026-10-04'))
            .partialRecordIds,
        {row.recordId});
  });
  test('failed batch state read cannot retain an incomplete failure map',
      () async {
    final row = readiness();
    await store.append('b1', [row]);
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b1', deviceKey: 'jw:test', recordIds: [row.recordId]));
    await store.noteAck('b1', 'requested');
    final events = File(
        '${root.path}/${jwHistoryDigest('jw:test')}/batches/b1.events.jsonl');
    final original = await events.readAsString();
    await events.writeAsString(
        '$original{"schema":1,"payload":{},"sha256":"wrong"}\n',
        flush: true);
    await expectLater(
        store.query('jw:test', JwHistoryType.readiness, day: '2026-10-04'),
        throwsFormatException);
    await events.writeAsString(
        original +
            fixtureEnvelope({
              'kind': 'failure',
              'batchId': 'b1',
              'deviceKey': 'jw:test',
              'stage': 'confirming',
              'message': 'fixture repair',
            }),
        flush: true);
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-04');
    expect(page.partialRecordIds, {row.recordId});
    expect(
        (await store.inventory('jw:test')).batchFailures, {'b1': 'confirming'});
  });
  test('failed manifest read cannot retain partly trusted committed IDs',
      () async {
    final first = readiness(), second = readiness(score: 83);
    await store.append('b1', [first, second]);
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b1', deviceKey: 'jw:test', recordIds: [first.recordId]));
    await store.commit(JwHistoryBatchCommit(
        batchId: 'b2', deviceKey: 'jw:test', recordIds: [second.recordId]));
    final manifest = File(
        '${root.path}/${jwHistoryDigest('jw:test')}/batches/b2.committed.json');
    final original = await manifest.readAsString();
    await manifest.writeAsString(
        '$original{"schema":1,"payload":{},"sha256":"wrong"}\n',
        flush: true);
    await expectLater(
        store.query('jw:test', JwHistoryType.readiness, day: '2026-10-04'),
        throwsFormatException);
    await seedJournalFile(manifest, [
      JwHistoryBatchCommit(
          batchId: 'b2', deviceKey: 'jw:test', recordIds: const []).toJson()
    ]);
    final page = await store.query('jw:test', JwHistoryType.readiness,
        day: '2026-10-04');
    expect(page.partialRecordIds, {second.recordId});
    expect(
        page.records.map((r) => r.recordId), [first.recordId, second.recordId]);
  });
  test('raw quarantines persist without becoming measured history', () async {
    await store.beginBatch('b1', 'jw:test');
    await store.quarantine('b1', 100, 'abcd', 'unknownVersion');
    expect((await store.inventory('jw:test')).recordCount, 0);
    final files = await root
        .list(recursive: true)
        .where((e) => e is File && e.path.contains('quarantine'))
        .toList();
    expect((await (files.single as File).readAsString()),
        contains('unknownVersion'));
  });
}
