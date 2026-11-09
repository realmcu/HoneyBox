import 'dart:async';
import 'dart:typed_data';

import '../connection/jw_link.dart';
import '../connection/jw_protocol.dart';
import '../debug/jw_debug_log.dart';
import '../model/jw_error.dart';
import '../storage/jw_history_store.dart';
import 'jw_history_models.dart';
import 'jw_history_sync_frame.dart';
import 'jw_history_sync_listener.dart';
import 'jw_history_write_queue.dart';

/// Internal HL private-protocol (`cmd 0x05`) health-history engine.
///
/// Flow matches [HL_Private_Protocol.md] §5.1 → §5.7 → payload keys → §5.8,
/// then phone `key 0x1c` ack (Android V2). HoneyProtocol `05 10` / `0x40` sync
/// control is **not** used on JW devices.
final class JWHealthHistorySync {
  JWHealthHistorySync({
    required JWLink link,
    required JWHistoryStore store,
    required JWHistoryScope scope,
    required JWHistorySyncListener listener,
    void Function(JWHistorySyncFrame frame)? onHistoryFrame,
  })  : _link = link,
        _store = store,
        _scope = scope,
        _listener = listener,
        _onHistoryFrame = onHistoryFrame;

  static const idleTimeout = kJWHistorySyncIdleTimeout;

  final JWLink _link;
  final JWHistoryStore _store;
  final JWHistoryScope _scope;
  final JWHistorySyncListener _listener;
  final void Function(JWHistorySyncFrame frame)? _onHistoryFrame;
  StreamSubscription<JWProtocolMessage>? _events;
  StreamSubscription<JWException>? _failures;
  Completer<void>? _done;
  Timer? _idleTimer;
  Future<void> _tail = Future.value();
  final _declared = <int, int>{};
  final _received = <int, int>{};
  final _markerStreamsEnded = <int>{};
  bool _started = false;
  bool _traditionalEnd = false;
  bool _finished = false;
  bool _roundCompleteQueued = false;
  int _totalWire = 0;
  JWHistoryWriteQueue? _writeQueue;

  Future<void> run() async {
    if (_done != null) {
      throw StateError('JW health sync is already active on this engine');
    }
    _done = Completer<void>();
    _writeQueue = JWHistoryWriteQueue(
      store: _store,
      scope: _scope,
      onError: _fail,
    );
    _events = _link.events.listen(_onMessage);
    _failures = _link.failures.listen(_onLinkFailure);
    _armIdleTimer();
    try {
      // HL private protocol §5.1: cmd 0x05, key 0x01, empty value.
      await _link.send(JWProtocolCommands.startHistorySync());
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
    return _done!.future.whenComplete(_cleanup);
  }

  void _onMessage(JWProtocolMessage message) {
    if (_finished || _done == null || _done!.isCompleted) return;
    if (message.command != 5) return;
    _armIdleTimer();
    _tail = _tail.then((_) => _process(message)).catchError(_fail);
  }

  void _onLinkFailure(JWException error) => _fail(error);

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      _failSync(JWHistorySyncFailure(
        code: JWErrorCode.historySyncIdleTimeout,
        message:
            'JW health sync idle timeout (${idleTimeout.inSeconds}s without incoming 0x05)',
      ));
    });
  }

  Future<void> _process(JWProtocolMessage message) async {
    if (_finished) return;
    _trace(message.key, message.value);
    if (message.key == 7) {
      _readStart(message.value);
    } else if (message.key == 8) {
      if (!_started || _traditionalEnd || message.value.isNotEmpty) {
        throw const FormatException('Invalid JW history END');
      }
      _traditionalEnd = true;
    } else if (_ignoredHistoryKeys.contains(message.key)) {
      return;
    } else if (_keyType.containsKey(message.key)) {
      await _readRecords(message.key, message.value);
    }
    if (_finished) return;
    await _completeIfReady();
  }

  void _trace(int key, Uint8List value) {
    _onHistoryFrame?.call(JWHistorySyncFrame(key: key, value: value));
  }

  void _readStart(Uint8List bytes) {
    if (_started || bytes.length % 3 != 0) {
      throw const FormatException('Invalid JW history START');
    }
    for (var offset = 0; offset < bytes.length; offset += 3) {
      final type = bytes[offset];
      if (_declared.containsKey(type)) {
        throw const FormatException('Duplicate JW history START type');
      }
      _declared[type] = (bytes[offset + 1] << 8) | bytes[offset + 2];
      _received[type] = 0;
    }
    _started = true;
    _totalWire = _declared.values.fold(0, (a, b) => a + b);
    final byCategory = <JWHistorySyncCategory, int>{};
    for (final entry in _declared.entries) {
      final category = _categoryForStartType(entry.key);
      if (category == null) continue;
      byCategory[category] = (byCategory[category] ?? 0) + entry.value;
    }
    _invoke(() {
      _listener.onSyncStart(JWHistorySyncPlan(
        totalWireRecords: _totalWire,
        wireCountsByCategory: Map.unmodifiable(byCategory),
      ));
      _listener.onSyncProgress(0, _totalWire);
    });
  }

  Future<void> _readRecords(int key, Uint8List value) async {
    if (!_started) throw const FormatException('JW history before START');
    final type = _keyType[key]!;
    if (!_declared.containsKey(type)) {
      throw FormatException('Undeclared JW history key $key');
    }
    if (_isMarker(value)) {
      if (!_markerStreamTypes.contains(type) ||
          !_markerStreamsEnded.add(type)) {
        throw FormatException('Unexpected JW history stream marker $key');
      }
      _emitProgress();
      return;
    }
    if (_markerStreamsEnded.contains(type) ||
        (!_markerStreamTypes.contains(type) && _traditionalEnd)) {
      throw FormatException('Late JW history record $key');
    }
    final decoded = _decode(key, value);
    _received[type] = _received[type]! + decoded.wireCount;
    if (decoded.records.isNotEmpty) {
      final records = decoded.records;
      _writeQueue!.enqueueRecords(records);
      scheduleMicrotask(() => _invoke(() => _deliverRecords(records)));
    }
    _emitProgress();
  }

  void _emitProgress() {
    if (_totalWire == 0) return;
    final received = _received.values.fold(0, (a, b) => a + b);
    _invoke(() => _listener.onSyncProgress(received, _totalWire));
  }

  Future<void> _completeIfReady() async {
    if (!_started || !_traditionalEnd || _finished || _roundCompleteQueued) {
      return;
    }
    for (final entry in _declared.entries) {
      if (_markerStreamTypes.contains(entry.key) &&
          !_markerStreamsEnded.contains(entry.key)) {
        return;
      }
      if (_received[entry.key] != entry.value) {
        throw FormatException(
            'JW history count mismatch for type ${entry.key}: ${_received[entry.key]}/${entry.value}');
      }
    }
    _roundCompleteQueued = true;
    final queue = _writeQueue;
    if (queue == null) {
      throw StateError('JW health sync writer is unavailable');
    }
    JWWatchDebugLog.apiIn(
      'JWHealthHistorySync.persist',
      'pendingRecords=${queue.pendingRecordCount} '
      'chunk=$kJWHistoryWriteChunkRecords',
    );
    queue.enqueueRoundCompleteSentinel();
    try {
      await queue.waitForRoundDrain();
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
      return;
    }
    JWWatchDebugLog.apiOut('JWHealthHistorySync.persist');
    await _link.send(JWProtocolCommands.confirmHistorySync());
    _finished = true;
    _idleTimer?.cancel();
    _invoke(_listener.onSyncFinished);
    _done!.complete();
  }

  void _deliverRecords(List<JWHistoryRecord> records) {
    final activities = <JWActivity>[];
    final sleeps = <JWSleep>[];
    final rates = <JWHeartRate>[];
    final temperatures = <JWTemperature>[];
    final pressures = <JWBloodPressure>[];
    final oxygens = <JWBloodOxygen>[];
    final hrvs = <JWHrv>[];
    final stress = <JWPressure>[];
    final sports = <JWSport>[];
    for (final record in records) {
      switch (record) {
        case JWActivity():
          activities.add(record);
        case JWSleep():
          sleeps.add(record);
        case JWHeartRate():
          rates.add(record);
        case JWTemperature():
          temperatures.add(record);
        case JWBloodPressure():
          pressures.add(record);
        case JWBloodOxygen():
          oxygens.add(record);
        case JWHrv():
          hrvs.add(record);
        case JWPressure():
          stress.add(record);
        case JWSport():
          sports.add(record);
        case JWBloodGlucose():
          break;
      }
    }
    if (activities.isNotEmpty) {
      _listener.onActivityReceived(List.unmodifiable(activities));
    }
    if (sleeps.isNotEmpty) {
      _listener.onSleepReceived(List.unmodifiable(sleeps));
    }
    if (rates.isNotEmpty) {
      _listener.onHeartRateReceived(List.unmodifiable(rates));
    }
    if (temperatures.isNotEmpty) {
      _listener.onTemperatureReceived(List.unmodifiable(temperatures));
    }
    if (pressures.isNotEmpty) {
      _listener.onBloodPressureReceived(List.unmodifiable(pressures));
    }
    if (oxygens.isNotEmpty) {
      _listener.onBloodOxygenReceived(List.unmodifiable(oxygens));
    }
    if (hrvs.isNotEmpty) {
      _listener.onHrvReceived(List.unmodifiable(hrvs));
    }
    if (stress.isNotEmpty) {
      _listener.onPressureReceived(List.unmodifiable(stress));
    }
    if (sports.isNotEmpty) {
      _listener.onSportReceived(List.unmodifiable(sports));
    }
  }

  void _invoke(void Function() callback) {
    try {
      callback();
    } catch (error) {
      _failSync(JWHistorySyncFailure(
        code: JWErrorCode.protocol,
        message: 'JW history sync listener failed: $error',
      ));
    }
  }

  void _failSync(JWHistorySyncFailure failure) {
    if (_finished || _done == null || _done!.isCompleted) return;
    _finished = true;
    _idleTimer?.cancel();
    try {
      _listener.onSyncFailed(failure);
    } catch (error, stackTrace) {
      _done!.completeError(error, stackTrace);
      return;
    }
    _done!.completeError(
        JWException(failure.code, failure.message), StackTrace.current);
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_finished || _done == null || _done!.isCompleted) return;
    _failSync(_failureFrom(error));
  }

  JWHistorySyncFailure _failureFrom(Object error) {
    if (error is JWHistorySyncFailure) return error;
    if (error is JWException) {
      return JWHistorySyncFailure(code: error.code, message: error.msg);
    }
    if (error is FormatException) {
      return JWHistorySyncFailure(
          code: JWErrorCode.protocol, message: error.message);
    }
    return JWHistorySyncFailure(
        code: JWErrorCode.protocol, message: error.toString());
  }

  Future<void> _cleanup() async {
    _idleTimer?.cancel();
    await _events?.cancel();
    await _failures?.cancel();
    _events = null;
    _failures = null;
    _done = null;
    _writeQueue = null;
    _roundCompleteQueued = false;
  }
}

JWHistorySyncCategory? _categoryForStartType(int type) {
  return switch (type) {
    0 => JWHistorySyncCategory.activity,
    1 => JWHistorySyncCategory.sleep,
    2 => JWHistorySyncCategory.heartRate,
    3 => JWHistorySyncCategory.bloodPressure,
    4 => JWHistorySyncCategory.sport,
    5 => JWHistorySyncCategory.bloodOxygen,
    6 => JWHistorySyncCategory.hrv,
    0x0e => JWHistorySyncCategory.pressure,
    0x0f => JWHistorySyncCategory.metabDaily,
    0x10 => JWHistorySyncCategory.readinessHistory,
    >= 7 && <= 13 => JWHistorySyncCategory.legacyInternal,
    _ => null,
  };
}

final class _DecodedField {
  const _DecodedField(this.wireCount, this.records);
  final int wireCount;
  final List<JWHistoryRecord> records;
}

const _keyType = <int, int>{
  2: 0,
  3: 1,
  0x1b: 2,
  0x29: 2,
  0x13: 3,
  0x16: 4,
  0x2c: 5,
  0x3c: 6,
  0x40: 7,
  0x49: 8,
  0x4a: 9,
  0x4b: 10,
  0x4c: 11,
  0x4d: 12,
  0x4e: 13,
  0x5b: 0x0e,
  0x60: 0x0f,
  0x64: 0x10,
};
/// Payload keys that may appear mid-sync but are not HL history batch data
/// (same skip list as HoneyBox `JwHistoryCoordinator`).
const _ignoredHistoryKeys = {0x0f, 0x28, 0x1a};

/// START types that end with an `overover` stream marker before END (0x5b/0x60/0x64).
const _markerStreamTypes = {0x0e, 0x0f, 0x10};

bool _isMarker(Uint8List bytes) =>
    bytes.length == 8 && String.fromCharCodes(bytes) == 'overover';

_DecodedField _decode(int key, Uint8List bytes) {
  const widths = <int, int>{
    2: 12,
    3: 8,
    0x1b: 12,
    0x29: 12,
    0x13: 12,
    0x16: 32,
    0x2c: 8,
    0x3c: 8,
    0x40: 8,
    0x49: 8,
    0x4a: 16,
    0x4b: 16,
    0x4c: 16,
    0x4d: 8,
    0x4e: 8,
    0x5b: 8,
    0x60: 48,
    0x64: 20,
  };
  final width = widths[key]!;
  if (bytes.isEmpty || bytes.length % width != 0) {
    throw FormatException('Invalid JW history payload length for key $key');
  }
  final records = <JWHistoryRecord>[];
  for (var offset = 0; offset < bytes.length; offset += width) {
    final raw = Uint8List.fromList(bytes.sublist(offset, offset + width));
    final record = _decodeOne(key, raw);
    if (record != null) records.addAll(record);
  }
  return _DecodedField(bytes.length ~/ width, records);
}

List<JWHistoryRecord>? _decodeOne(int key, Uint8List raw) {
  final data = ByteData.sublistView(raw);
  DateTime calendar(int minute, [int second = 0]) {
    final word = data.getUint16(0);
    final date = DateTime.utc(2000 + (word >> 9 & 63), word >> 5 & 15,
        word & 31, minute ~/ 60, minute % 60, second);
    if (date.year != 2000 + (word >> 9 & 63) || minute >= 1440 || second > 59) {
      throw const FormatException('Invalid JW history calendar time');
    }
    return date;
  }

  int? nonzero(int value) => value == 0 ? null : value;
  switch (key) {
    case 2:
      final word = _be(raw, 4, 8);
      final quarter = _bits(word, 53, 11);
      if (quarter >= 96) {
        throw const FormatException('Invalid JW activity quarter');
      }
      return [
        JWActivity(
            time: calendar(quarter * 15),
            steps: _bits(word, 39, 12),
            distance: _bits(word, 0, 16),
            energy: _bits(word, 16, 19),
            activeTime: _bits(word, 35, 4),
            mode: _bits(word, 51, 2))
      ];
    case 3:
      final word = data.getUint32(4);
      final mode = word & 15;
      if (mode > 4) throw const FormatException('Invalid JW sleep mode');
      return [JWSleep(time: calendar(word >> 16), mode: mode)];
    case 0x1b:
    case 0x29:
      final word = _be(raw, 4, 8);
      final time = calendar(_bits(word, 16, 16), _bits(word, 8, 8));
      final rows = <JWHistoryRecord>[];
      final rate = nonzero(_bits(word, 0, 8));
      if (rate != null) rows.add(JWHeartRate(time: time, heartRate: rate));
      if (key == 0x29) {
        final temperature = _bits(word, 32, 14);
        if (temperature != 0) {
          rows.add(JWTemperature(
              time: time,
              skinTemperature: temperature / 10,
              heatStress: _bits(word, 46, 2),
              worn: _bits(word, 48, 1) == 1,
              compensated: _bits(word, 49, 1) == 1));
        }
      }
      return rows;
    case 0x13:
      final word = _be(raw, 4, 8);
      final systolic = nonzero(_bits(word, 0, 8));
      final diastolic = nonzero(_bits(word, 8, 8));
      return systolic == null || diastolic == null
          ? const []
          : [
              JWBloodPressure(
                  time: calendar(_bits(word, 32, 16), _bits(word, 24, 8)),
                  systolic: systolic,
                  diastolic: diastolic)
            ];
    case 0x16:
      if (raw[11] > 59 || raw[15] > 59) {
        throw const FormatException('Invalid JW sport duration');
      }
      return [
        JWSport(
            time: calendar(data.getUint16(5), raw[7]),
            mode: raw[8],
            duration: data.getUint16(9) * 60 + raw[11],
            pauseCount: raw[12],
            pauseDuration: data.getUint16(13) * 60 + raw[15],
            steps: data.getUint32(16),
            distance: data.getUint32(20),
            energy: data.getUint32(24),
            heartRateMax: nonzero(raw[28]),
            heartRateAverage: nonzero(raw[29]),
            heartRateMin: nonzero(raw[30]))
      ];
    case 0x2c:
      final word = _be(raw, 0, 8);
      final value = nonzero(_bits(word, 16, 8));
      if (value == null) return const [];
      final time = DateTime.utc(
          2000 + _bits(word, 57, 6),
          _bits(word, 53, 4),
          _bits(word, 48, 5),
          _bits(word, 32, 16) ~/ 60,
          _bits(word, 32, 16) % 60,
          _bits(word, 24, 8));
      return [
        JWBloodOxygen(
            time: time,
            value: value,
            high: nonzero(_bits(word, 8, 8)),
            low: nonzero(_bits(word, 0, 8)))
      ];
    case 0x3c:
      if (raw[0] != 1) {
        throw const FormatException('Unsupported JW HRV version');
      }
      final seconds = data.getUint32(1);
      final sdnn = nonzero(raw[5]);
      return sdnn == null
          ? const []
          : [
              JWHrv(
                  time: DateTime.utc(2000)
                      .add(Duration(seconds: seconds - 946656000)),
                  sdnn: sdnn)
            ];
    case 0x5b:
      final value = nonzero(raw[4]);
      return value == null
          ? const []
          : [
              JWPressure(
                  time: DateTime.utc(2000)
                      .add(Duration(seconds: data.getUint32(0, Endian.little))),
                  value: value)
            ];
    case 0x60:
    case 0x64:
      return null;
  }
  return null;
}

BigInt _be(Uint8List bytes, int offset, int length) {
  var value = BigInt.zero;
  for (var i = offset; i < offset + length; i++) {
    value = (value << 8) | BigInt.from(bytes[i]);
  }
  return value;
}

int _bits(BigInt word, int shift, int width) =>
    ((word >> shift) & ((BigInt.one << width) - BigInt.one)).toInt();
