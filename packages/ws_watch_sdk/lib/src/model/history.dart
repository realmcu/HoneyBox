import 'dart:typed_data';
import 'wall_clock.dart';
import 'sync.dart';

class WSRecordQuery {
  WSRecordQuery(
      {required this.deviceId,
      this.userId,
      this.from,
      this.to,
      this.limit,
      this.descending = false}) {
    if (deviceId.isEmpty) throw ArgumentError('deviceId is required');
    if (limit != null && limit! < 0) {
      throw ArgumentError('limit must be nonnegative');
    }
    if (from != null && to != null && from!.seconds > to!.seconds) {
      throw ArgumentError('from must not exceed to');
    }
  }
  final String deviceId;
  final String? userId;
  final WSWallClock? from, to;
  final int? limit;
  final bool descending;
}

abstract interface class WSRecordQueryApi<T> {
  Future<List<T>> query(WSRecordQuery query);
  Future<int> delete(WSRecordQuery query);
}

abstract interface class WSHistoryRecord {
  int get id;
  String get deviceId;
  String get userId;
  WSWallClock get recordTime;
  DateTime get syncedAt;
  int get tzOffsetMinutes;
  Uint8List get raw;
}

// Decoded wire samples have no database identity or connection ownership.
sealed class WSHistorySample {
  WSHistorySample({required this.recordTime, required List<int> raw})
      : raw = Uint8List.fromList(raw).asUnmodifiableView();
  final WSWallClock recordTime;
  final Uint8List raw;
  WSHistoryType get type;
}

class WSStepSample extends WSHistorySample {
  WSStepSample(
      {required super.recordTime,
      required super.raw,
      required this.mode,
      required this.steps,
      required this.bucketMinutes,
      required this.averageHeartRate,
      required this.flags,
      required this.caloriesDeciKcal,
      required this.distanceMeters});
  @override
  WSHistoryType get type => WSHistoryType.steps;
  final int mode, bucketMinutes, flags;
  final int? steps, averageHeartRate, caloriesDeciKcal, distanceMeters;
}

class WSHeartRateSample extends WSHistorySample {
  WSHeartRateSample(
      {required super.recordTime, required super.raw, required this.bpm});
  @override
  WSHistoryType get type => WSHistoryType.heartRate;
  final int? bpm;
  int get sourceKey => 0x23;
}

class WSStepRecord extends WSStepSample implements WSHistoryRecord {
  WSStepRecord(
      {required this.id,
      required this.deviceId,
      required this.userId,
      required this.syncedAt,
      required this.tzOffsetMinutes,
      required WSStepSample sample})
      : super(
            recordTime: sample.recordTime,
            raw: sample.raw,
            mode: sample.mode,
            steps: sample.steps,
            bucketMinutes: sample.bucketMinutes,
            averageHeartRate: sample.averageHeartRate,
            flags: sample.flags,
            caloriesDeciKcal: sample.caloriesDeciKcal,
            distanceMeters: sample.distanceMeters);
  @override
  final int id;
  @override
  final String deviceId, userId;
  @override
  final DateTime syncedAt;
  @override
  final int tzOffsetMinutes;
}

class WSHeartRateRecord extends WSHeartRateSample implements WSHistoryRecord {
  WSHeartRateRecord(
      {required this.id,
      required this.deviceId,
      required this.userId,
      required this.syncedAt,
      required this.tzOffsetMinutes,
      required WSHeartRateSample sample})
      : super(recordTime: sample.recordTime, raw: sample.raw, bpm: sample.bpm);
  @override
  final int id;
  @override
  final String deviceId, userId;
  @override
  final DateTime syncedAt;
  @override
  final int tzOffsetMinutes;
}
