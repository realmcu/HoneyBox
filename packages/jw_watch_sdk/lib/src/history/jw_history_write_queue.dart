import 'dart:async';

import '../storage/jw_history_store.dart';
import 'jw_history_models.dart';

/// Persists decoded history in the background so BLE decode never awaits Drift.
///
/// Items are whole decoded wire batches. The writer merges queued batches until
/// at least [kJWHistoryWriteChunkRecords] records are ready, then writes one
/// transaction. A [enqueueRoundCompleteSentinel] entry drains the remainder and
/// completes [waitForRoundDrain].
/// Merged Drift transaction size for one [JWHistoryStore.writeRecords] call.
const kJWHistoryWriteChunkRecords = 500;

enum _JWHistoryWriteKind { records, roundComplete }

final class _JWHistoryWriteItem {
  const _JWHistoryWriteItem._(this.kind, this.records);

  const _JWHistoryWriteItem.records(List<JWHistoryRecord> records)
      : this._(_JWHistoryWriteKind.records, records);

  const _JWHistoryWriteItem.roundComplete()
      : this._(_JWHistoryWriteKind.roundComplete, const []);

  final _JWHistoryWriteKind kind;
  final List<JWHistoryRecord> records;
}

final class JWHistoryWriteQueue {
  JWHistoryWriteQueue({
    required JWHistoryStore store,
    required JWHistoryScope scope,
    required void Function(Object error, StackTrace stackTrace) onError,
  })  : _store = store,
        _scope = scope,
        _onError = onError;

  final JWHistoryStore _store;
  final JWHistoryScope _scope;
  final void Function(Object error, StackTrace stackTrace) _onError;
  final List<_JWHistoryWriteItem> _queue = [];
  Future<void> _writer = Future.value();
  Completer<void>? _roundDrain;
  bool _failed = false;
  bool _drainScheduled = false;

  void enqueueRecords(List<JWHistoryRecord> records) {
    if (_failed || records.isEmpty) return;
    _queue.add(_JWHistoryWriteItem.records(List<JWHistoryRecord>.from(records)));
    _kickWriter();
  }

  void enqueueRoundCompleteSentinel() {
    if (_failed) return;
    _queue.add(const _JWHistoryWriteItem.roundComplete());
    _roundDrain ??= Completer<void>();
    _kickWriter();
  }

  Future<void> waitForRoundDrain() {
    final pending = _roundDrain;
    if (pending == null) {
      return Future.value();
    }
    return pending.future;
  }

  /// Records still waiting in the write queue (excluding the round sentinel).
  int get pendingRecordCount {
    var count = 0;
    for (final item in _queue) {
      if (item.kind == _JWHistoryWriteKind.records) {
        count += item.records.length;
      }
    }
    return count;
  }

  void _kickWriter() {
    if (_failed || _drainScheduled) return;
    _drainScheduled = true;
    _writer = _writer.then((_) => _drain()).catchError((Object error, StackTrace stackTrace) {
      _fail(error, stackTrace);
    });
  }

  Future<void> _drain() async {
    try {
      while (!_failed) {
        final completed = await _runWriterPass();
        if (completed || _queue.isEmpty) {
          return;
        }
      }
    } finally {
      _drainScheduled = false;
      if (!_failed && _queue.isNotEmpty) {
        _kickWriter();
      }
    }
  }

  /// Returns `true` when the round-complete sentinel was consumed.
  Future<bool> _runWriterPass() async {
    while (_queue.isNotEmpty) {
      if (_queue.first.kind == _JWHistoryWriteKind.roundComplete) {
        _queue.removeAt(0);
        final pending = _roundDrain;
        _roundDrain = null;
        pending?.complete();
        return true;
      }
      final batch = <JWHistoryRecord>[];
      while (_queue.isNotEmpty &&
          _queue.first.kind == _JWHistoryWriteKind.records) {
        final next = _queue.first;
        if (batch.isNotEmpty &&
            batch.length + next.records.length > kJWHistoryWriteChunkRecords) {
          break;
        }
        _queue.removeAt(0);
        batch.addAll(next.records);
        if (batch.length >= kJWHistoryWriteChunkRecords) {
          break;
        }
      }
      if (batch.isEmpty) {
        return false;
      }
      await _store.writeRecords(_scope, batch);
    }
    return false;
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (_failed) return;
    _failed = true;
    final pending = _roundDrain;
    _roundDrain = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error, stackTrace);
    }
    _onError(error, stackTrace);
  }
}
