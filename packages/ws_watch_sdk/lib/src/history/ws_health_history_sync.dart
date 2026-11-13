import 'dart:async';
import 'dart:typed_data';

import '../connection/ws_link.dart';
import '../debug/ws_debug_log.dart';
import '../wire/ws_data_command.dart';
import '../wire/ws_l2_message.dart';
import '../model/ws_error.dart';
import '../storage/ws_history_store.dart';
import 'ws_health_codecs.dart';
import 'ws_history_sync_frame.dart';
import 'ws_history_sync_listener.dart';

/// WS `0x05` full health sync: `0x00` → `0x40` → data → `0x41` → `0x42`.
final class WSHealthHistorySync {
  WSHealthHistorySync({
    required WSLink link,
    required WSHistoryStore store,
    required WSHistoryScope scope,
    required WSHistorySyncListener listener,
    int syncKey = WSDataCommand.keySyncAll,
    void Function(WSHistorySyncFrame frame)? onHistoryFrame,
  })  : _link = link,
        _store = store,
        _scope = scope,
        _listener = listener,
        _syncKey = syncKey,
        _onHistoryFrame = onHistoryFrame;

  final WSLink _link;
  final WSHistoryStore _store;
  final WSHistoryScope _scope;
  final WSHistorySyncListener _listener;
  final int _syncKey;
  final void Function(WSHistorySyncFrame frame)? _onHistoryFrame;

  StreamSubscription<WSL2Message>? _sub;
  StreamSubscription<WSException>? _failures;
  Future<void>? _finishing;
  Completer<void>? _done;
  Timer? _idle;
  final _declared = <int, int>{};
  final _received = <int, int>{};
  int _totalWire = 0;
  bool _sawStart = false;
  bool _finished = false;

  final _activities = <WSActivity>[];
  final _sleeps = <WSSleep>[];
  final _heartRates = <WSHeartRate>[];
  final _bloodPressures = <WSBloodPressure>[];
  final _bloodOxygens = <WSBloodOxygen>[];
  final _hrvs = <WSHrv>[];
  final _pressures = <WSPressure>[];
  final _temperatures = <WSTemperature>[];
  final _glucoses = <WSBloodGlucose>[];
  final _sports = <WSSport>[];

  Future<void> run() async {
    if (_done != null) {
      throw StateError('WS health sync is already active');
    }
    _done = Completer<void>();
    _done!.future.ignore();
    _failures = _link.failures.listen(_fail);
    _sub = _link.incoming.listen(_onMessage, onError: _fail);
    _armIdle();
    WSWatchDebugLog.apiIn(
      'WSHealthHistorySync.run',
      'syncKey=0x${_syncKey.toRadixString(16)}',
    );
    try {
      await _link.send(WSDataCommand.syncRequest(_syncKey));
      await _done!.future;
      WSWatchDebugLog.apiOut('WSHealthHistorySync.run', 'finished');
    } catch (error, stack) {
      _fail(error, stack);
      Error.throwWithStackTrace(_operationError(error), stack);
    } finally {
      try {
        await _finishing;
      } catch (_) {}
      await _cleanup();
    }
  }

  void _onMessage(WSL2Message message) {
    if (_finished || _done == null || _done!.isCompleted) return;
    if (message.command != WSDataCommand.command ||
        message.version != WSDataCommand.version) {
      return;
    }
    _armIdle();
    try {
      if (message.key == WSDataCommand.keySyncStart) {
        _readStart(message.value);
      } else if (WSDataCommand.isDataKey(message.key)) {
        _readData(message);
      } else if (message.key == WSDataCommand.keySyncEnd) {
        _finishing ??= _readEnd(message.value)
            .catchError((Object error, StackTrace stack) {
          _fail(error, stack);
        });
      }
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _readStart(Uint8List bytes) {
    if (_sawStart || bytes.length % 3 != 0) {
      throw const FormatException('Invalid sync start');
    }
    _sawStart = true;
    _declared.clear();
    _received.clear();
    for (var i = 0; i < bytes.length; i += 3) {
      final type = bytes[i];
      final count = (bytes[i + 1] << 8) | bytes[i + 2];
      _declared[type] = count;
      _received[type] = 0;
    }
    _totalWire = _declared.values.fold(0, (a, b) => a + b);
    final byCategory = <WSHistorySyncCategory, int>{};
    for (final entry in _declared.entries) {
      final cat = _categoryForSyncKey(entry.key);
      if (cat == null) continue;
      byCategory[cat] = (byCategory[cat] ?? 0) + entry.value;
    }
    _listener.onSyncStart(WSHistorySyncPlan(
      totalWireRecords: _totalWire,
      wireCountsByCategory: Map.unmodifiable(byCategory),
    ));
    _emitProgress();
  }

  void _readData(WSL2Message message) {
    if (!_sawStart) throw const FormatException('data before sync start');
    WSWatchDebugLog.syncDataFrame(key: message.key, value: message.value);
    _onHistoryFrame?.call(
      WSHistorySyncFrame(key: message.key, value: message.value),
    );
    final syncKey = message.key - 0x20;
    final wire = _wireCount(message);
    if (_declared.isNotEmpty && !_declared.containsKey(syncKey)) {
      throw FormatException('unexpected data key ${message.key}');
    }
    _received[syncKey] = (_received[syncKey] ?? 0) + wire;
    final decoded = WSHealthCodecs.decodeByKey(message.key, message);
    switch (decoded) {
      case List<WSActivity> v:
        _activities.addAll(v);
      case List<WSSleep> v:
        _sleeps.addAll(v);
      case List<WSHeartRate> v:
        _heartRates.addAll(v);
      case List<WSBloodPressure> v:
        _bloodPressures.addAll(v);
      case List<WSBloodOxygen> v:
        _bloodOxygens.addAll(v);
      case List<WSHrv> v:
        _hrvs.addAll(v);
      case List<WSPressure> v:
        _pressures.addAll(v);
      case List<WSTemperature> v:
        _temperatures.addAll(v);
      case List<WSBloodGlucose> v:
        _glucoses.addAll(v);
      case List<WSSport> v:
        _sports.addAll(v);
      default:
        throw FormatException('decode type for key ${message.key}');
    }
    _emitProgress();
  }

  Future<void> _readEnd(Uint8List bytes) async {
    if (bytes.length != 5) {
      throw const FormatException('Invalid sync end');
    }
    final result = bytes[0];
    if (result == 0x02) {
      _failSync(const WSHistorySyncFailure(
        code: WSErrorCode.historySyncBusy,
        message: 'device reported sync busy',
      ));
      return;
    }
    if (result != 0x00) {
      _failSync(WSHistorySyncFailure(
        code: WSErrorCode.historySyncFailed,
        message: 'sync end code 0x${result.toRadixString(16)}',
      ));
      return;
    }
    if (_declared.isNotEmpty) {
      for (final e in _declared.entries) {
        if (_received[e.key] != e.value) {
          throw FormatException(
            'count mismatch type 0x${e.key.toRadixString(16)}: '
            '${_received[e.key]}/${e.value}',
          );
        }
      }
    }
    await _persist();
    WSWatchDebugLog.apiOut(
      'WSHealthHistorySync.persist',
      'ok act=${_activities.length} sleep=${_sleeps.length} hr=${_heartRates.length} '
          'bp=${_bloodPressures.length} spo2=${_bloodOxygens.length} hrv=${_hrvs.length} '
          'pressure=${_pressures.length} temp=${_temperatures.length} glu=${_glucoses.length} '
          'sport=${_sports.length}',
    );
    await _link.send(WSDataCommand.syncConfirm());
    if (_finished) return;
    _finished = true;
    _listener.onSyncFinished();
    _done?.complete();
  }

  Future<void> _persist() async {
    if (_activities.isNotEmpty) {
      await _store.writeActivities(_scope, _activities);
    }
    if (_sleeps.isNotEmpty) await _store.writeSleeps(_scope, _sleeps);
    if (_heartRates.isNotEmpty) {
      await _store.writeHeartRates(_scope, _heartRates);
    }
    if (_bloodPressures.isNotEmpty) {
      await _store.writeBloodPressures(_scope, _bloodPressures);
    }
    if (_bloodOxygens.isNotEmpty) {
      await _store.writeBloodOxygens(_scope, _bloodOxygens);
    }
    if (_hrvs.isNotEmpty) await _store.writeHrvs(_scope, _hrvs);
    if (_pressures.isNotEmpty) await _store.writePressures(_scope, _pressures);
    if (_temperatures.isNotEmpty) {
      await _store.writeTemperatures(_scope, _temperatures);
    }
    if (_glucoses.isNotEmpty) {
      await _store.writeBloodGlucoses(_scope, _glucoses);
    }
    if (_sports.isNotEmpty) await _store.writeSports(_scope, _sports);
  }

  int _wireCount(WSL2Message message) {
    final bytes = message.value;
    if (bytes.length < 3) return 0;
    return (bytes[1] << 8) | bytes[2];
  }

  void _emitProgress() {
    if (_totalWire == 0) {
      _listener.onSyncProgress(0, 0);
      return;
    }
    final got = _received.values.fold(0, (a, b) => a + b);
    _listener.onSyncProgress(got, _totalWire);
  }

  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(kWSHistorySyncIdleTimeout, () {
      _failSync(const WSHistorySyncFailure(
        code: WSErrorCode.historySyncIdleTimeout,
        message: 'health sync idle timeout',
      ));
    });
  }

  void _failSync(WSHistorySyncFailure failure) {
    if (_finished) return;
    _finished = true;
    _listener.onSyncFailed(failure);
    _done?.completeError(WSException(failure.code, failure.message));
  }

  WSException _operationError(Object error) => error is WSException
      ? error
      : WSException(WSErrorCode.historySyncFailed, error.toString());

  void _fail(Object error, [StackTrace? stack]) {
    if (_finished) return;
    _finished = true;
    final failure = WSHistorySyncFailure(
      code: error is WSException ? error.code : WSErrorCode.historySyncFailed,
      message: error.toString(),
    );
    _listener.onSyncFailed(failure);
    _done?.completeError(_operationError(error), stack);
  }

  Future<void> _cleanup() async {
    _idle?.cancel();
    await _failures?.cancel();
    await _sub?.cancel();
    _sub = null;
    _done = null;
  }

  static WSHistorySyncCategory? _categoryForSyncKey(int syncKey) {
    return switch (syncKey) {
      WSDataCommand.keySyncActivity => WSHistorySyncCategory.activity,
      WSDataCommand.keySyncSleep => WSHistorySyncCategory.sleep,
      WSDataCommand.keySyncHeartRate => WSHistorySyncCategory.heartRate,
      WSDataCommand.keySyncBloodPressure => WSHistorySyncCategory.bloodPressure,
      WSDataCommand.keySyncBloodOxygen => WSHistorySyncCategory.bloodOxygen,
      WSDataCommand.keySyncHrv => WSHistorySyncCategory.hrv,
      WSDataCommand.keySyncPressure => WSHistorySyncCategory.pressure,
      WSDataCommand.keySyncTemperature => WSHistorySyncCategory.temperature,
      WSDataCommand.keySyncBloodGlucose => WSHistorySyncCategory.bloodGlucose,
      WSDataCommand.keySyncSport => WSHistorySyncCategory.sport,
      _ => null,
    };
  }
}
