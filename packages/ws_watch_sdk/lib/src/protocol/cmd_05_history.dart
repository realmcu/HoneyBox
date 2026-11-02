import 'dart:typed_data';
import '../model/history.dart';
import '../model/sync.dart';
import '../model/wall_clock.dart';
import 'address.dart';
import 'protocol.dart';

class WSHistoryBatch {
  WSHistoryBatch(this.type, Iterable<WSHistorySample> samples)
      : samples = List.unmodifiable(samples);
  final WSHistoryType type;
  final List<WSHistorySample> samples;
}

class WSHistoryEnd {
  const WSHistoryEnd(this.code, this.count);
  final int code, count;
}

abstract final class WSHistoryProtocol {
  static WSProtocolEntry entry(int key, String name, {bool incoming = false}) =>
      WSProtocolEntry(
          address: WSProtocolAddress(
              cmd: 5,
              version: 1,
              key: key,
              direction: incoming
                  ? WSWireDirection.deviceToPhone
                  : WSWireDirection.phoneToDevice),
          name: name,
          specRef: '0x05-data#0x${key.toRadixString(16)}',
          maxRetries: incoming ? null : 0);
  static final requestSteps = entry(1, 'syncSteps');
  static final requestHeartRate = entry(3, 'syncHeartRate');
  static final steps = entry(0x21, 'historySteps', incoming: true);
  static final heartRate = entry(0x23, 'historyHeartRate', incoming: true);
  static final start = entry(0x40, 'historyStart', incoming: true);
  static final end = entry(0x41, 'historyEnd', incoming: true);
  static final confirm = entry(0x42, 'confirmHistory');
  static final entries = [
    requestSteps,
    requestHeartRate,
    steps,
    heartRate,
    start,
    end,
    confirm
  ];
  static WSCommand<void> request(WSHistoryType type) => WSCommand(
      request: type == WSHistoryType.steps ? requestSteps : requestHeartRate,
      encodeData: (_) => Uint8List(0),
      maxRetries: 0);
  static final confirmation = WSCommand<void>(
      request: confirm, encodeData: (_) => Uint8List(0), maxRetries: 0);
  static final reports = <WSReport<Object>>[
    WSReport<Map<int, int>>(entry: start, decodeData: decodeStart),
    WSReport<WSHistoryEnd>(entry: end, decodeData: decodeEnd),
    WSReport<WSHistoryBatch>(
        entry: steps, decodeData: (b) => decodeBatch(WSHistoryType.steps, b)),
    WSReport<WSHistoryBatch>(
        entry: heartRate,
        decodeData: (b) => decodeBatch(WSHistoryType.heartRate, b)),
  ];
  static Map<int, int> decodeStart(Uint8List bytes) {
    if (bytes.length % 3 != 0) {
      throw const FormatException('invalid sync start length');
    }
    final view = ByteData.sublistView(bytes), counts = <int, int>{};
    for (var i = 0; i < bytes.length; i += 3) {
      final type = bytes[i], count = view.getUint16(i + 1);
      if (type == 0 || type > 0x1f || count == 0 || counts.containsKey(type)) {
        throw const FormatException(
            'invalid or duplicate announced history type');
      }
      counts[type] = count;
    }
    return Map.unmodifiable(counts);
  }

  static WSHistoryEnd decodeEnd(Uint8List bytes) {
    if (bytes.length != 5) {
      throw const FormatException('sync end requires five bytes');
    }
    return WSHistoryEnd(bytes[0], ByteData.sublistView(bytes).getUint32(1));
  }

  static WSHistoryBatch decodeBatch(WSHistoryType type, Uint8List bytes) {
    if (bytes.length < 3) {
      throw const FormatException('history batch header truncated');
    }
    final size = bytes[0], count = ByteData.sublistView(bytes).getUint16(1);
    final minimum = type == WSHistoryType.steps ? 18 : 5;
    if (size < minimum || bytes.length != 3 + size * count) {
      throw const FormatException('invalid history item size or count');
    }
    final rows = <WSHistorySample>[];
    for (var i = 0; i < count; i++) {
      final raw =
          Uint8List.sublistView(bytes, 3 + i * size, 3 + (i + 1) * size);
      final view = ByteData.sublistView(raw);
      final time = WSWallClock.fromSeconds(view.getUint32(0));
      if (type == WSHistoryType.heartRate) {
        rows.add(WSHeartRateSample(
            recordTime: time, raw: raw, bpm: raw[4] == 255 ? null : raw[4]));
      } else {
        if (raw[11] != 15 || time.minute % 15 != 0 || time.second != 0) {
          throw const FormatException('invalid 15-minute activity bucket');
        }
        int? value(int offset) {
          final v = view.getUint16(offset);
          return v == 65535 ? null : v;
        }

        rows.add(WSStepSample(
            recordTime: time,
            raw: raw,
            steps: value(4),
            distanceMeters: value(6),
            caloriesDeciKcal: value(8),
            averageHeartRate:
                raw[13] & 1 == 0 || raw[10] == 255 ? null : raw[10],
            bucketMinutes: raw[11],
            mode: raw[12],
            flags: raw[13]));
      }
    }
    return WSHistoryBatch(type, rows);
  }
}
