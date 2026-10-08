import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'jw_history_models.dart';

abstract interface class JwHistoryJournalIo {
  Future<void> append(File file, String line);
  Future<void> flush();
  Future<void> close();
}

/// Bounded open handles; journal writes are serialized by the store.
class FileJwHistoryJournalIo implements JwHistoryJournalIo {
  final _handles = <String, RandomAccessFile>{};
  @override
  Future<void> append(File file, String line) async {
    var handle = _handles.remove(file.path);
    if (handle == null) {
      if (_handles.length >= 16) {
        final old = _handles.remove(_handles.keys.first)!;
        await old.flush();
        await old.close();
      }
      await file.parent.create(recursive: true);
      handle = await file.open(mode: FileMode.append);
    }
    _handles[file.path] = handle;
    await handle.writeString(line);
  }

  @override
  Future<void> flush() async {
    for (final handle in _handles.values) {
      await handle.flush();
    }
  }

  @override
  Future<void> close() async {
    Object? error;
    for (final handle in _handles.values) {
      try {
        await handle.flush();
      } catch (e) {
        error ??= e;
      }
      try {
        await handle.close();
      } catch (e) {
        error ??= e;
      }
    }
    _handles.clear();
    if (error != null) {
      throw error;
    }
  }
}

abstract interface class JwHistoryStore {
  Future<void> open();
  Future<void> beginBatch(String batchId, String deviceKey);
  Future<JwHistoryAppendResult> append(
      String batchId, List<JwHistoryRecord> records);
  Future<void> quarantine(
      String batchId, int key, String rawHex, String reason);
  Future<void> flush();
  Future<void> commit(JwHistoryBatchCommit batch);
  Future<void> noteAck(String batchId, String status);
  Future<void> noteFailure(String batchId, String stage, String message);
  Future<JwHistoryPage> query(String deviceKey, JwHistoryType type,
      {required String day, int offset = 0, int limit = 100});
  Future<JwHistoryInventory> inventory(String deviceKey);
  Future<List<String>> deviceKeys();
  Future<void> close();
}

Future<JwHistoryStore> openJwHistoryStore() async {
  final support = await getApplicationSupportDirectory();
  final store = FileJwHistoryStore(Directory('${support.path}/jw_history/v1'));
  await store.open();
  return store;
}

class _JwHistoryBatchState {
  final Map<String, String> ackByBatch, failures;
  _JwHistoryBatchState(Map<String, String> acks, Map<String, String> failures)
      : ackByBatch = Map.unmodifiable(acks),
        failures = Map.unmodifiable(failures);
  int get entryCount => ackByBatch.length + failures.length;
}

class FileJwHistoryStore implements JwHistoryStore {
  static final _processLocks = <String>{};
  static const _metadataDeviceLimit = 4;
  static const _metadataRecordLimit = 16000;
  static const _metadataBatchLimit = 256;
  // Separate budgets keep batch lookup fast when record-ID caches cannot fit.
  final _batchStateCache = <String, _JwHistoryBatchState>{};
  final _inventoryCache = <String, JwHistoryInventory>{};
  final _committedIdsCache = <String, Set<String>>{};
  final Directory root;
  final JwHistoryJournalIo _io;
  final _batches = <String, String>{};
  final _idsByShard = <String, Set<String>>{};
  Future<void> _tail = Future.value();
  Future<void>? _opening, _closing;
  RandomAccessFile? _lock;
  String? _lockKey;
  bool _open = false, _poisoned = false;
  int _recoveredTails = 0;
  FileJwHistoryStore(this.root, {JwHistoryJournalIo? journalIo})
      : _io = journalIo ?? FileJwHistoryJournalIo();

  @override
  Future<void> open() {
    if (_open) {
      return Future.value();
    }
    if (_closing != null) {
      return Future.error(StateError('History store is closed'));
    }
    return _opening ??= _openStore().whenComplete(() => _opening = null);
  }

  Future<void> _openStore() async {
    _clearReadMetadata();
    await root.create(recursive: true);
    var key = await root.resolveSymbolicLinks();
    if (Platform.isWindows) {
      key = key.toLowerCase();
    }
    if (!_processLocks.add(key)) {
      throw StateError('History storeBusy');
    }
    _lockKey = key;
    try {
      _lock =
          await File('${root.path}/writer.lock').open(mode: FileMode.append);
      if (await _lock!.length() == 0) {
        await _lock!.writeByte(0);
        await _lock!.flush();
      }
      try {
        await _lock!.lock(FileLock.exclusive, 0, 1);
      } on FileSystemException catch (e) {
        throw StateError('History storeBusy: $e');
      }
      final recovery = File('${root.path}/recovery.jsonl');
      if (await recovery.exists()) {
        await _recoverTail(recovery, countRecovery: false);
        await for (final payload in _read(recovery)) {
          if (payload['kind'] == 'recoveredTail') {
            _recoveredTails++;
          }
        }
      }
      await for (final entry
          in root.list(recursive: true, followLinks: false)) {
        if (entry is! File ||
            !(entry.path.endsWith('.jsonl') ||
                entry.path.endsWith('.committed.json')) ||
            _normalized(entry.absolute.path) ==
                _normalized(recovery.absolute.path)) {
          continue;
        }
        if (entry.path.endsWith('.jsonl')) {
          await _recoverTail(entry);
        }
        var entries = 0;
        await for (final payload in _read(entry)) {
          entries++;
          if (payload.containsKey('recordId') &&
              payload.containsKey('rawHex')) {
            final row = JwHistoryRecord.fromJson(payload);
            if (_normalized(_shard(row).absolute.path) !=
                _normalized(entry.absolute.path)) {
              throw const FormatException('History shard provenance');
            }
          } else if (payload['kind'] == 'begin' ||
              entry.path.endsWith('.committed.json')) {
            _register(
                payload['batchId'] as String, payload['deviceKey'] as String);
          }
        }
        if (entry.path.endsWith('.committed.json') && entries != 1) {
          throw const FormatException('History published commit entry count');
        }
      }
      _open = true;
    } catch (e) {
      await _releaseLock();
      rethrow;
    } finally {
      _clearReadMetadata();
    }
  }

  String _normalized(String path) {
    final normalized = path.replaceAll('\\', '/');
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  Future<T> _serial<T>(Future<T> Function() action, {bool write = false}) {
    final future = _tail.then((_) async {
      if (write) _clearReadMetadata();
      try {
        if (!_open || _closing != null) {
          throw StateError('History store is closed');
        }
        if (write && _poisoned) {
          throw StateError('History store write failure; reopen required');
        }
        return await action();
      } catch (e) {
        if (write && e is FileSystemException) {
          _poisoned = true;
        }
        rethrow;
      } finally {
        // A write can load metadata mid-action, or fail after durable changes.
        if (write) _clearReadMetadata();
      }
    });
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  void _clearReadMetadata() {
    _batchStateCache.clear();
    _inventoryCache.clear();
    _committedIdsCache.clear();
  }

  T? _cachedMetadata<T>(Map<String, T> cache, String deviceKey) {
    final value = cache.remove(deviceKey);
    if (value != null) cache[deviceKey] = value;
    return value;
  }

  void _cacheMetadata<T>(Map<String, T> cache, String deviceKey, T value) {
    cache.remove(deviceKey);
    if (cache.length >= _metadataDeviceLimit) cache.remove(cache.keys.first);
    cache[deviceKey] = value;
  }

  void _validBatch(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id)) {
      throw const FormatException('History batch identity');
    }
  }

  void _validDay(String day) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw const FormatException('History query day');
    }
    final parsed = DateTime.tryParse(day);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != day) {
      throw const FormatException('History query calendar date');
    }
  }

  void _register(String batch, String device) {
    _validBatch(batch);
    if (device.isEmpty ||
        (_batches.containsKey(batch) && _batches[batch] != device)) {
      throw const FormatException('History batch device provenance');
    }
    _batches[batch] = device;
  }

  Directory _device(String device) =>
      Directory('${root.path}/${jwHistoryDigest(device)}');
  File _shard(JwHistoryRecord row) {
    _validDay(row.day);
    return File(
        '${_device(row.deviceKey).path}/records/${row.type.name}/${row.day}.jsonl');
  }

  File _events(String batch) {
    final device = _batches[batch];
    if (device == null) {
      throw StateError('History batch not started');
    }
    return File('${_device(device).path}/batches/$batch.events.jsonl');
  }

  String _line(Map<String, Object?> payload) => '${jsonEncode({
            'schema': 1,
            'payload': payload,
            'sha256': jwHistoryDigest(payload)
          })}\n';
  Stream<Map<String, Object?>> _read(File file) async* {
    if (!await file.exists()) {
      return;
    }
    await for (final line in file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      try {
        final envelope = jsonDecode(line) as Map;
        final payload = Map<String, Object?>.from(envelope['payload'] as Map);
        if (envelope['schema'] != 1 ||
            envelope['sha256'] != jwHistoryDigest(payload)) {
          throw const FormatException('History journal checksum/schema');
        }
        yield payload;
      } on FormatException {
        rethrow;
      } catch (e) {
        throw FormatException('History journal entry: $e');
      }
    }
  }

  Future<void> _recoverTail(File file, {bool countRecovery = true}) async {
    _clearReadMetadata();
    final handle = await file.open(mode: FileMode.append);
    try {
      var end = await handle.length();
      if (end == 0) {
        return;
      }
      await handle.setPosition(end - 1);
      if (await handle.readByte() == 10) {
        return;
      }
      final originalLength = end;
      var good = 0;
      while (end > 0) {
        final start = end > 4096 ? end - 4096 : 0;
        await handle.setPosition(start);
        final bytes = await handle.read(end - start);
        final index = bytes.lastIndexOf(10);
        if (index >= 0) {
          good = start + index + 1;
          break;
        }
        end = start;
      }
      // A published manifest is never passed here; only append journals.
      final event = File('${root.path}/recovery.jsonl');
      final self =
          _normalized(file.absolute.path) == _normalized(event.absolute.path);
      final line = _line({
        'kind': 'recoveredTail',
        'path': file.path,
        'removedBytes': originalLength - good
      });
      if (!self) {
        await event.writeAsString(line, mode: FileMode.append, flush: true);
      }
      await handle.truncate(good);
      await handle.flush();
      if (self) {
        await event.writeAsString(line, mode: FileMode.append, flush: true);
      }
      if (countRecovery) {
        _recoveredTails++;
      }
    } finally {
      _clearReadMetadata();
      await handle.close();
    }
  }

  Future<void> _begin(String batch, String device) async {
    final known = _batches.containsKey(batch);
    _register(batch, device);
    if (!known) {
      await _io.append(_events(batch),
          _line({'kind': 'begin', 'batchId': batch, 'deviceKey': device}));
      await _io.flush();
    }
  }

  @override
  Future<void> beginBatch(String batchId, String deviceKey) =>
      _serial(() => _begin(batchId, deviceKey), write: true);

  Future<Set<String>> _ids(File file) async {
    var ids = _idsByShard.remove(file.path);
    if (ids == null) {
      ids = <String>{};
      await for (final payload in _read(file)) {
        ids.add(JwHistoryRecord.fromJson(payload).recordId);
      }
      if (_idsByShard.length >= 8) {
        _idsByShard.remove(_idsByShard.keys.first);
      }
    }
    _idsByShard[file.path] = ids;
    return ids;
  }

  @override
  Future<JwHistoryAppendResult> append(
          String batchId, List<JwHistoryRecord> records) =>
      _serial(() async {
        final inserted = <String>{}, existing = <String>{};
        if (records.isEmpty) {
          return JwHistoryAppendResult(inserted, existing);
        }
        await _begin(batchId, records.first.deviceKey);
        for (final row in records) {
          _register(batchId, row.deviceKey);
          final shard = _shard(row), ids = await _ids(_shard(row));
          if (ids.contains(row.recordId)) {
            existing.add(row.recordId);
          } else {
            await _io.append(shard, _line(row.toJson()));
            await _io.flush(); // Never reference/count a row before its flush.
            ids.add(row.recordId);
            inserted.add(row.recordId);
          }
          await _io.append(
              _events(batchId),
              _line({
                'kind': 'recordReference',
                'batchId': batchId,
                'deviceKey': row.deviceKey,
                'recordId': row.recordId
              }));
        }
        await _io.flush();
        return JwHistoryAppendResult(inserted, existing);
      }, write: true);

  @override
  Future<void> quarantine(
          String batchId, int key, String rawHex, String reason) =>
      _serial(() async {
        final device = _batches[batchId];
        if (device == null) {
          throw StateError('History batch not started');
        }
        await _io.append(
            File('${_device(device).path}/quarantine/$batchId.jsonl'),
            _line({
              'batchId': batchId,
              'deviceKey': device,
              'key': key,
              'rawHex': rawHex,
              'reason': reason
            }));
        await _io.flush();
      }, write: true);
  @override
  Future<void> flush() => _serial(_io.flush, write: true);

  @override
  Future<void> commit(JwHistoryBatchCommit batch) => _serial(() async {
        await _begin(batch.batchId, batch.deviceKey);
        final file = File(
            '${_device(batch.deviceKey).path}/batches/${batch.batchId}.committed.json');
        if (await file.exists()) {
          throw StateError('History batch already committed');
        }
        final known = (await _inventory(batch.deviceKey)).recordIds.toSet();
        if (batch.recordIds.any((id) => !known.contains(id))) {
          throw StateError('History batch references an unpersisted record');
        }
        await _io.flush();
        await file.parent.create(recursive: true);
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(_line(batch.toJson()), flush: true);
        await temp.rename(file.path);
      }, write: true);

  @override
  Future<void> noteAck(String batchId, String status) => _serial(() async {
        if (!['requested', 'transportDelivered', 'unknown'].contains(status)) {
          throw ArgumentError('History ACK status');
        }
        final events = _events(batchId);
        final manifest = File('${events.parent.path}/$batchId.committed.json');
        if (!await manifest.exists()) {
          throw StateError('History ACK before commit');
        }
        await _io.append(
            events,
            _line({
              'kind': 'ack',
              'batchId': batchId,
              'deviceKey': _batches[batchId],
              'status': status
            }));
        await _io.flush();
      }, write: true);

  @override
  Future<void> noteFailure(String batchId, String stage, String message) =>
      _serial(() async {
        await _io.append(
            _events(batchId),
            _line({
              'kind': 'failure',
              'batchId': batchId,
              'deviceKey': _batches[batchId],
              'stage': stage,
              'message': message
            }));
        await _io.flush();
      }, write: true);

  Future<List<File>> _files(Directory dir, String suffix) async {
    if (!await dir.exists()) {
      return [];
    }
    final files = <File>[];
    await for (final f in dir.list(recursive: true, followLinks: false)) {
      if (f is File && f.path.endsWith(suffix)) {
        files.add(f);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  @override
  Future<JwHistoryPage> query(String deviceKey, JwHistoryType type,
          {required String day, int offset = 0, int limit = 100}) =>
      _serial(() async {
        _validDay(day);
        RangeError.checkValueInInterval(limit, 1, 500);
        if (offset < 0) throw RangeError.value(offset);
        final shard =
            File('${_device(deviceKey).path}/records/${type.name}/$day.jsonl');
        final rows = <JwHistoryRecord>[];
        final latest = <String, JwHistoryRecord>{};
        final seen = <String>{};
        final order = <String, int>{};
        await for (final payload in _read(shard)) {
          final row = JwHistoryRecord.fromJson(payload);
          if (!seen.add(row.recordId)) continue;
          order[row.recordId] = rows.length;
          rows.add(row);
          // Arrival order chooses the latest distinct revision, independently
          // of chronological display. A known payload retry never reverses it.
          latest[row.sourceIdentity] = row;
        }
        int time(JwHistoryRecord r) =>
            (r.sourceTime['localEpochSeconds'] as int?) ??
            (r.sourceTime['dayEpochSeconds'] as int?) ??
            ((r.sourceTime['minute'] as int? ?? 0) * 60 +
                (r.sourceTime['second'] as int? ?? 0));
        int compare(JwHistoryRecord a, JwHistoryRecord b) {
          final t = time(a).compareTo(time(b));
          return t != 0 ? t : order[a.recordId]!.compareTo(order[b.recordId]!);
        }

        rows.sort(compare);
        final revisions = latest.values.toList()..sort(compare);
        final pageRows = rows.skip(offset).take(limit).toList();
        final pageRevisions = revisions.skip(offset).take(limit).toList();
        final committed = await _committedIds(deviceKey);

        return JwHistoryPage(
            records: pageRows,
            total: rows.length,
            latestBySourceIdentity: pageRevisions,
            partialRecordIds: [...pageRows, ...pageRevisions]
                .where((r) => !committed.contains(r.recordId))
                .map((r) => r.recordId));
      });
  Future<_JwHistoryBatchState> _batchState(String deviceKey) async {
    final cached = _cachedMetadata(_batchStateCache, deviceKey);
    if (cached != null) return cached;
    final acks = <String, String>{}, failures = <String, String>{};
    // This fallback reads events only, regardless of raw dataset size.
    for (final file in await _files(
        Directory('${_device(deviceKey).path}/batches'), '.events.jsonl')) {
      await for (final p in _read(file)) {
        if (p['kind'] == 'failure') {
          failures[p['batchId'] as String] = p['stage'] as String;
        }
        if (p['kind'] == 'ack') {
          acks[p['batchId'] as String] =
              p['status'] == 'requested' ? 'unknown' : p['status'] as String;
        }
      }
    }
    final state = _JwHistoryBatchState(acks, failures);
    if (state.entryCount <= _metadataBatchLimit) {
      _cacheMetadata(_batchStateCache, deviceKey, state);
    }
    return state;
  }

  Future<Set<String>> _committedIds(String deviceKey) async {
    final cached = _cachedMetadata(_committedIdsCache, deviceKey);
    if (cached != null) return cached;
    // Never obtain failures via a full raw-record inventory, even on a miss.
    final state = await _batchState(deviceKey);
    final ids = <String>{};
    for (final manifest in await _files(
        Directory('${_device(deviceKey).path}/batches'), '.committed.json')) {
      await for (final p in _read(manifest)) {
        if (!state.failures.containsKey(p['batchId'])) {
          ids.addAll((p['recordIds'] as List).cast<String>());
        }
      }
    }
    final committed = Set<String>.unmodifiable(ids);
    if (committed.length <= _metadataRecordLimit) {
      _cacheMetadata(_committedIdsCache, deviceKey, committed);
    }
    return committed;
  }

  Future<JwHistoryInventory> _inventory(String deviceKey) async {
    final cached = _cachedMetadata(_inventoryCache, deviceKey);
    if (cached != null) return cached;
    final ids = <String>{}, counts = <String, int>{};
    final days = <String, Set<String>>{};
    for (final file in await _files(
        Directory('${_device(deviceKey).path}/records'), '.jsonl')) {
      await for (final p in _read(file)) {
        final row = JwHistoryRecord.fromJson(p);
        days.putIfAbsent(row.type.name, () => {}).add(row.day);
        if (ids.add(row.recordId)) {
          counts.update(row.type.name, (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }
    final state = await _batchState(deviceKey);
    final inventory = JwHistoryInventory(
        recordIds: ids,
        counts: counts,
        ackByBatch: state.ackByBatch,
        recoveredTails: _recoveredTails,
        batchFailures: state.failures,
        daysByType: {
          for (final e in days.entries) e.key: e.value.toList()..sort()
        });
    if (inventory.recordCount <= _metadataRecordLimit &&
        state.entryCount <= _metadataBatchLimit) {
      _cacheMetadata(_inventoryCache, deviceKey, inventory);
    }
    return inventory;
  }

  @override
  Future<JwHistoryInventory> inventory(String deviceKey) =>
      _serial(() => _inventory(deviceKey));

  @override
  Future<List<String>> deviceKeys() => _serial(() async =>
      List<String>.unmodifiable(_batches.values.toSet().toList()..sort()));

  Future<void> _releaseLock() async {
    _clearReadMetadata();
    final lock = _lock;
    _lock = null;
    try {
      if (lock != null) {
        await lock.close();
      }
    } finally {
      if (_lockKey != null) {
        _processLocks.remove(_lockKey);
        _lockKey = null;
      }
    }
  }

  @override
  Future<void> close() => _closing ??= _closeStore();
  Future<void> _closeStore() async {
    _clearReadMetadata();
    await _tail;
    try {
      await _io.close();
    } finally {
      _open = false;
      await _releaseLock();
    }
  }
}
