import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../config.dart';
import '../debug/models.dart';
import '../errors.dart';
import '../logger.dart';
import '../model/history.dart';
import '../model/sync.dart';
import '../model/feature.dart';
import '../protocol/cmd_05_history.dart';
import '../session/session.dart';
import '../storage/history_store.dart';

abstract interface class WSData {
  bool get isSyncing;
  WSSyncSession sync({required WSHistoryType type});
  WSRecordQueryApi<WSStepRecord> get steps;
  WSRecordQueryApi<WSHeartRateRecord> get heartRate;
  Future<List<WSSyncLog>> syncLogs(
      {required String deviceId, String? userId, int limit = 20});
}

class WSDataConnection {
  const WSDataConnection(this.session, this.deviceId, this.userId);
  final WSSession session;
  final String deviceId, userId;
}

class WSDataController implements WSData {
  WSDataController(
      {required this.connection,
      required this.openStore,
      required this.disconnect,
      required this.support,
      required this.config,
      required this.now,
      required this.logger});
  final WSDataConnection Function() connection;
  final Future<WSHistoryStore> Function() openStore;
  final Future<void> Function(WSSession session) disconnect;
  final WSFeatureSupport Function(WSFeature) support;
  final WSSyncConfig config;
  final DateTime Function() now;
  final WSLogger logger;
  _HistoryTransfer? _active;
  bool _disposed = false;
  final Set<Future<dynamic>> _operations = {};
  Future<void>? _disposing;
  @override
  bool get isSyncing => _active != null;
  @override
  late final WSRecordQueryApi<WSStepRecord> steps = _RecordApi(
      (q) => _local((s) => s.querySteps(q)),
      (q) => _local((s) => s.deleteSteps(q)));
  @override
  late final WSRecordQueryApi<WSHeartRateRecord> heartRate = _RecordApi(
      (q) => _local((s) => s.queryHeartRate(q)),
      (q) => _local((s) => s.deleteHeartRate(q)));
  Future<T> _local<T>(Future<T> Function(WSHistoryStore) action) {
    if (_disposed) return Future.error(const WSDisposedException());
    final work = openStore().then(action);
    _operations.add(work);
    unawaited(work.then<void>((_) {
      _operations.remove(work);
    }, onError: (Object _) {
      _operations.remove(work);
    }));
    return work;
  }

  @override
  Future<List<WSSyncLog>> syncLogs(
      {required String deviceId, String? userId, int limit = 20}) {
    if (deviceId.isEmpty || limit < 0) {
      return Future.error(
          ArgumentError('deviceId and nonnegative limit required'));
    }
    return _local((s) => s.querySyncLogs(deviceId, userId, limit));
  }

  @override
  WSSyncSession sync({required WSHistoryType type}) {
    if (_disposed) throw const WSDisposedException();
    final current = connection();
    if (_active != null) throw const WSSyncInProgressException();
    if (config.syncIdleTimeout <= Duration.zero ||
        config.maxPendingBytes <= 0) {
      throw ArgumentError('invalid sync configuration');
    }
    final feature = type == WSHistoryType.steps
        ? WSFeature.activityHistory
        : WSFeature.heartRateHistory;
    if (support(feature) == WSFeatureSupport.unsupported) {
      throw WSUnsupportedException(feature);
    }
    final owner = current.session.acquireHistory();
    final transfer = _HistoryTransfer(
        current: current,
        type: type,
        owner: owner,
        openStore: openStore,
        disconnect: disconnect,
        config: config,
        now: now,
        logger: logger,
        finished: (transfer) {
          if (identical(_active, transfer)) _active = null;
        });
    _active = transfer;
    scheduleMicrotask(transfer.start);
    return transfer;
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    await _active?.cancel();
    await Future.wait(_operations
        .toList()
        .map((f) => f.then<void>((_) {}, onError: (Object _) {})));
  }
}

class _RecordApi<T> implements WSRecordQueryApi<T> {
  _RecordApi(this._query, this._delete);
  final Future<List<T>> Function(WSRecordQuery) _query;
  final Future<int> Function(WSRecordQuery) _delete;
  @override
  Future<List<T>> query(WSRecordQuery query) => _query(query);
  @override
  Future<int> delete(WSRecordQuery query) => _delete(query);
}

class _HistoryTransfer implements WSSyncSession {
  _HistoryTransfer(
      {required this.current,
      required this.type,
      required this.owner,
      required this.openStore,
      required this.disconnect,
      required this.config,
      required this.now,
      required this.logger,
      required this.finished})
      : startedAt = now(),
        syncId = '${DateTime.now().microsecondsSinceEpoch}-${_serial++}';
  static int _serial = 0;
  final WSDataConnection current;
  final WSHistoryType type;
  final Object owner;
  final Future<WSHistoryStore> Function() openStore;
  final Future<void> Function(WSSession) disconnect;
  final WSSyncConfig config;
  final DateTime Function() now;
  final WSLogger logger;
  final void Function(_HistoryTransfer) finished;
  final DateTime startedAt;
  @override
  final String syncId;
  final _progress = StreamController<WSSyncProgress>.broadcast();
  final _result = Completer<WSSyncResult>();
  final _incomingDone = Completer<void>();
  final _queue = Queue<WSDeviceReport>();
  @override
  Stream<WSSyncProgress> get progress => _progress.stream;
  @override
  Future<WSSyncResult> get result => _result.future;
  StreamSubscription<WSDeviceReport>? _subscription;
  Future<void>? _pumping, _disconnecting;
  WSHistoryStore? _store;
  Timer? _idle;
  bool _aborted = false, _finished = false, _started = false, _endSeen = false;
  WSSyncStage _stage = WSSyncStage.requesting;
  WSSyncFailure? _failure;
  String? _message;
  int? _announced, _deviceCode;
  int _endTotal = 0,
      _received = 0,
      _committed = 0,
      _inserted = 0,
      _duplicates = 0,
      _decodeFailures = 0,
      _pendingBytes = 0;
  Map<int, int> _announcedTypes = {};
  WSSyncConfirmation _confirmation = WSSyncConfirmation.notSent;
  WSSyncProgress _snapshot() => WSSyncProgress(
      syncId: syncId,
      type: type,
      stage: _stage,
      announced: _announced,
      received: _received,
      committed: _committed,
      inserted: _inserted,
      duplicates: _duplicates,
      decodeFailures: _decodeFailures,
      pendingBytes: _pendingBytes);
  void _emit(WSSyncStage stage) {
    if (_finished) return;
    _stage = stage;
    _progress.add(_snapshot());
  }

  void _touch() {
    _idle?.cancel();
    if (!_aborted && !_endSeen) {
      _idle = Timer(
          config.syncIdleTimeout,
          () => _abort(WSSyncFailure.idleTimeout,
              'no history payload before idle deadline'));
    }
  }

  @override
  Future<void> cancel() async {
    if (_finished) return;
    _abort(WSSyncFailure.cancelled, 'sync cancelled');
    await result;
  }

  void _abort(WSSyncFailure reason, String message, {bool close = true}) {
    if (_finished || _aborted) return;
    _aborted = true;
    _failure = reason;
    _message = message;
    _idle?.cancel();
    while (_queue.isNotEmpty) {
      _pendingBytes -= _queue.removeFirst().data.length + 5;
    }
    if (!_incomingDone.isCompleted) _incomingDone.complete();
    if (close) {
      _disconnecting ??= disconnect(current.session).catchError((Object _) {});
    }
  }

  void _receive(WSDeviceReport report) {
    if (_finished || _aborted) return;
    final a = report.address;
    if (a == null) {
      if (report.kind == WSReportKind.decodeError &&
          report.data.isNotEmpty &&
          report.data[0] == 5) {
        _decodeFailures++;
        _abort(WSSyncFailure.protocolError, 'malformed history L2 payload');
      }
      return;
    }
    if (a.cmd != 5 ||
        !(a.key == 0x40 || a.key == 0x41 || (a.key >= 0x20 && a.key <= 0x3f))) {
      return;
    }
    if (a.version != 1) {
      _decodeFailures++;
      _abort(WSSyncFailure.protocolError, 'unsupported history version');
      return;
    }
    final bytes = report.data.length + 5;
    if (_pendingBytes + bytes > config.maxPendingBytes) {
      _abort(WSSyncFailure.bufferOverflow,
          'pending history payload exceeds ${config.maxPendingBytes} bytes');
      return;
    }
    _pendingBytes += bytes;
    _queue.add(report);
    _touch();
    if (a.key == 0x41) {
      _idle?.cancel(); // The remaining work is local durability, not wire idle.
    }
    _pump();
  }

  void _pump() {
    _pumping ??= _drain().whenComplete(() {
      _pumping = null;
      if (_queue.isNotEmpty && !_aborted) _pump();
    });
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty && !_aborted) {
      final report = _queue.removeFirst();
      try {
        await _process(report);
      } on FormatException catch (e) {
        _decodeFailures++;
        _abort(WSSyncFailure.protocolError, '$e');
      } catch (e) {
        _abort(WSSyncFailure.storageFailed, 'history transaction failed: $e');
      } finally {
        _pendingBytes -= report.data.length + 5;
      }
    }
  }

  Future<void> _process(WSDeviceReport report) async {
    if (_endSeen) throw const FormatException('history data after end');
    if (report.kind == WSReportKind.decodeError) {
      throw FormatException('history decode failed: ${report.error}');
    }
    final key = report.address!.key;
    if (key == 0x40) {
      if (_started) throw const FormatException('duplicate sync start');
      final counts = report.value as Map<int, int>?;
      if (counts == null || counts.keys.any((k) => k != type.requestKey)) {
        throw const FormatException('unrequested history type announced');
      }
      _started = true;
      _announcedTypes = counts;
      _announced = counts[type.requestKey] ?? 0;
      _emit(WSSyncStage.receiving);
      return;
    }
    if (key == 0x41) {
      final end = report.value as WSHistoryEnd?;
      if (end == null) throw const FormatException('undecodable sync end');
      _deviceCode = end.code;
      _endTotal = end.count;
      if (end.code != 0) {
        _abort(
            switch (end.code) {
              2 => WSSyncFailure.deviceBusy,
              4 => WSSyncFailure.invalidParameter,
              _ => WSSyncFailure.deviceFailed
            },
            'device sync result ${end.code}');
        return;
      }
      if (!_started) throw const FormatException('sync end without start');
      _endSeen = true;
      if (!_incomingDone.isCompleted) _incomingDone.complete();
      return;
    }
    if (!_started || key != type.dataKey || report.value is! WSHistoryBatch) {
      throw const FormatException('unexpected history data or missing start');
    }
    final batch = report.value! as WSHistoryBatch;
    _received += batch.samples.length;
    if (_received > _announced!) {
      _abort(WSSyncFailure.countMismatch, 'received more than announced');
      return;
    }
    _emit(WSSyncStage.persisting);
    final write = await _store!.writeHistory(
        WSHistoryScope(
            deviceId: current.deviceId,
            userId: current.userId,
            syncedAt: now(),
            tzOffsetMinutes: startedAt.timeZoneOffset.inMinutes),
        batch.samples);
    _committed += write.committed;
    _inserted += write.inserted;
    _duplicates += write.duplicates;
    if (write.committed != batch.samples.length ||
        write.inserted + write.duplicates != write.committed) {
      _abort(WSSyncFailure.storageFailed,
          'storage counters do not match transaction');
      return;
    }
    _emit(WSSyncStage.receiving);
  }

  void start() {
    unawaited(_run());
  }

  Future<void> _run() async {
    _subscription = current.session.reports.listen(_receive);
    unawaited(current.session.link.terminated.then((error) {
      _abort(WSSyncFailure.disconnected, '$error', close: false);
    }));
    _emit(WSSyncStage.requesting);
    try {
      _store = await openStore();
      if (!_aborted) {
        await current.session.sendHistory(
            WSHistoryProtocol.request(type), owner,
            onSending: _touch);
        await _incomingDone.future;
        await _pumping;
        _idle?.cancel();
        if (!_aborted &&
            (!_endSeen ||
                _deviceCode != 0 ||
                _received != _announced ||
                _received != _endTotal ||
                _committed != _received ||
                _decodeFailures != 0)) {
          _abort(WSSyncFailure.countMismatch,
              'announced=$_announced received=$_received committed=$_committed end=$_endTotal');
        }
        if (!_aborted) {
          // A durable provisional audit entry also verifies storage before confirmation.
          await _writeLog(WSSyncStatus.incomplete, 'awaiting confirmation');
          if (!_aborted) {
            _emit(WSSyncStage.confirming);
            await current.session.sendHistory(
                WSHistoryProtocol.confirmation, owner, onSending: () {
              _confirmation = WSSyncConfirmation.unknown;
            });
            _confirmation = WSSyncConfirmation.acked;
          }
        }
      }
    } catch (e) {
      _abort(
          _confirmation == WSSyncConfirmation.unknown
              ? WSSyncFailure.confirmationFailed
              : (_store == null || _stage != WSSyncStage.requesting
                  ? WSSyncFailure.storageFailed
                  : WSSyncFailure.requestFailed),
          '$e');
    } finally {
      _idle?.cancel();
      await _pumping;
      await _disconnecting;
      await _subscription?.cancel();
      var status = _confirmation == WSSyncConfirmation.unknown
          ? WSSyncStatus.confirmationUnknown
          : _aborted
              ? WSSyncStatus.incomplete
              : WSSyncStatus.completed;
      if (_store != null) {
        try {
          await _writeLog(status, _message);
        } catch (e) {
          _failure = WSSyncFailure.storageFailed;
          _message = 'cannot finalize sync audit: $e';
          if (status == WSSyncStatus.completed) {
            status = WSSyncStatus.incomplete;
          }
        }
      }
      _emit(WSSyncStage.finished);
      final outcome = WSSyncResult(
          status: status,
          progress: _snapshot(),
          confirmation: _confirmation,
          reason: _failure,
          message: _message,
          deviceResultCode: _deviceCode);
      _finished = true;
      current.session.releaseHistory(owner);
      finished(this);
      _result.complete(outcome);
      logger.log(WSLogLevel.info, 'WSData',
          'sync=$syncId result=${status.name} announced=$_announced received=$_received committed=$_committed inserted=$_inserted duplicates=$_duplicates confirmation=${_confirmation.name} reason=$_message');
      await _progress.close();
    }
  }

  Future<void> _writeLog(WSSyncStatus status, String? reason) =>
      _store!.saveSyncLog(WSSyncLog(
          deviceId: current.deviceId,
          userId: current.userId,
          syncId: syncId,
          startedAt: startedAt,
          endedAt: now(),
          announcedJson:
              jsonEncode(_announcedTypes.map((k, v) => MapEntry('$k', v))),
          receivedJson: jsonEncode({
            '${type.requestKey}': {
              'received': _received,
              'committed': _committed,
              'inserted': _inserted,
              'duplicates': _duplicates,
              'decodeFailures': _decodeFailures
            }
          }),
          confirmation: _confirmation,
          result: status,
          deviceResultCode: _deviceCode,
          reason: reason));
}
