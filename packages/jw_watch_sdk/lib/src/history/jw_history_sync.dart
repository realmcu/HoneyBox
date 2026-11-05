import 'dart:async';
import 'dart:typed_data';

import '../connection/jw_link.dart';
import '../connection/jw_protocol.dart';
import '../model/jw_error.dart';
import '../storage/jw_history_store.dart';
import 'jw_history_models.dart';

/// The only callback emitted during a history round.  It contains the device's
/// complete announced count; callers can derive their own UI progress without
/// making the protocol path wait for UI listeners.
final class JWHistorySyncStart {
  const JWHistorySyncStart({required this.totalCount, required this.counts});
  final int totalCount;
  final Map<int, int> counts;
}

enum JWHistoryConfirmation { notAttempted, transportDelivered, unknown }

final class JWHistorySyncResult {
  const JWHistorySyncResult({
    required this.totalCount,
    required this.receivedCount,
    required this.persistedCount,
    required this.declaredCounts,
    required this.receivedCounts,
    required this.confirmation,
  });
  final int totalCount, receivedCount, persistedCount;
  final Map<int, int> declaredCounts, receivedCounts;
  final JWHistoryConfirmation confirmation;
}

/// Serializes one JW 0x05 history transaction.  Record packets are committed
/// as they arrive, which avoids a large end-of-sync disk burst, but 0x1c is
/// sent only after every declared stream has ended and all writes succeeded.
final class JWHistorySynchronizer {
  JWHistorySynchronizer({
    required JWLink link,
    required JWHistoryStore store,
    required JWHistoryScope scope,
  })  : _link = link,
        _store = store,
        _scope = scope;

  final JWLink _link;
  final JWHistoryStore _store;
  final JWHistoryScope _scope;
  final _starts = StreamController<JWHistorySyncStart>.broadcast(sync: true);
  StreamSubscription<JWProtocolMessage>? _events;
  StreamSubscription<JWException>? _failures;
  Completer<JWHistorySyncResult>? _done;
  Future<void> _tail = Future.value();
  final _declared = <int, int>{};
  final _received = <int, int>{};
  final _modernEnded = <int>{};
  bool _started = false;
  bool _traditionalEnd = false;
  bool _cancelled = false;
  int _persisted = 0;

  Stream<JWHistorySyncStart> get starts => _starts.stream;

  Future<JWHistorySyncResult> synchronize() async {
    if (_done != null) throw StateError('JW history synchronization is active');
    _done = Completer<JWHistorySyncResult>();
    _events = _link.events.listen(_onMessage);
    _failures = _link.failures.listen(_fail);
    try {
      await _link.send(JWProtocolCommands.startHistorySync());
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
    return _done!.future.whenComplete(_cleanup);
  }

  Future<void> cancel() async {
    if (_done == null || _done!.isCompleted) return;
    _cancelled = true;
    _fail(
        const JWException(JWErrorCode.cancelled, 'JW history sync cancelled'));
  }

  void _onMessage(JWProtocolMessage message) {
    if (_done!.isCompleted || message.command != 5) return;
    _tail = _tail.then((_) => _process(message)).catchError(_fail);
  }

  Future<void> _process(JWProtocolMessage message) async {
    for (final field in [message]) {
      if (field.key == 7) {
        _readStart(field.value);
      } else if (field.key == 8) {
        if (!_started || _traditionalEnd || field.value.isNotEmpty) {
          throw const FormatException('Invalid JW history END');
        }
        _traditionalEnd = true;
      } else if (_keyType.containsKey(field.key)) {
        await _readRecords(field.key, field.value);
      }
    }
    await _completeIfReady();
  }

  void _readStart(Uint8List bytes) {
    if (_started || bytes.isEmpty || bytes.length % 3 != 0) {
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
    final total = _declared.values.fold(0, (a, b) => a + b);
    _starts.add(JWHistorySyncStart(
        totalCount: total, counts: Map.unmodifiable(_declared)));
  }

  Future<void> _readRecords(int key, Uint8List value) async {
    if (!_started) throw const FormatException('JW history before START');
    final type = _keyType[key]!;
    if (!_declared.containsKey(type)) {
      throw FormatException('Undeclared JW history key $key');
    }
    if (_isMarker(value)) {
      if (!_modernTypes.contains(type) || !_modernEnded.add(type)) {
        throw FormatException('Unexpected JW history stream marker $key');
      }
      return;
    }
    if (_modernEnded.contains(type) ||
        (!_modernTypes.contains(type) && _traditionalEnd)) {
      throw FormatException('Late JW history record $key');
    }
    final decoded = _decode(key, value);
    _received[type] = _received[type]! + decoded.wireCount;
    // METAB/readiness are intentionally not public models yet. They remain
    // decoded enough to count their fixed-size records and gate confirmation.
    if (decoded.records.isNotEmpty) {
      await _store.writeRecords(_scope, decoded.records);
      _persisted += decoded.records.length;
    }
  }

  Future<void> _completeIfReady() async {
    if (!_started || !_traditionalEnd || _done!.isCompleted) return;
    for (final entry in _declared.entries) {
      if (_modernTypes.contains(entry.key) &&
          !_modernEnded.contains(entry.key)) {
        return;
      }
      if (_received[entry.key] != entry.value) {
        throw FormatException(
            'JW history count mismatch for type ${entry.key}: ${_received[entry.key]}/${entry.value}');
      }
    }
    if (_cancelled) return;
    // The frame channel confirms delivery, not firmware persistence.  Record
    // that ambiguity explicitly so a later sync can safely be repeated.
    await _link.send(JWProtocolCommands.confirmHistorySync());
    _done!.complete(JWHistorySyncResult(
      totalCount: _declared.values.fold(0, (a, b) => a + b),
      receivedCount: _received.values.fold(0, (a, b) => a + b),
      persistedCount: _persisted,
      declaredCounts: Map.unmodifiable(_declared),
      receivedCounts: Map.unmodifiable(_received),
      confirmation: JWHistoryConfirmation.unknown,
    ));
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_done == null || _done!.isCompleted) return;
    _done!.completeError(error, stackTrace);
  }

  Future<void> _cleanup() async {
    await _events?.cancel();
    await _failures?.cancel();
    _events = null;
    _failures = null;
    _done = null;
  }

  Future<void> dispose() async {
    await cancel();
    await _starts.close();
  }
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
  // These legacy streams remain deliberately internal after the new public
  // model reduction. Their record width is still known from Android V2, so
  // they participate in receipt validation and never prevent 0x1c merely
  // because the SDK no longer exposes their records.
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
const _modernTypes = {0x0e, 0x0f, 0x10};

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
