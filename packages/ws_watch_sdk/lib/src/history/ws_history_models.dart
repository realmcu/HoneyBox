/// Scope required for every WS health-history operation.
final class WSHistoryScope {
  const WSHistoryScope({required this.userId, required this.deviceMac});

  final String userId;
  final String deviceMac;
}

/// A stable time-range query for one authenticated WS user and one watch.
final class WSHistoryQuery {
  WSHistoryQuery({
    required this.scope,
    this.from,
    this.to,
    this.limit = 100,
    this.descending = false,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    if (from != null && to != null && from! > to!) {
      throw ArgumentError('from must not be after to');
    }
  }

  final WSHistoryScope scope;

  /// Inclusive lower bound in the same epoch unit stored for the queried table.
  final int? from;

  /// Inclusive upper bound in the same epoch unit stored for the queried table.
  final int? to;
  final int limit;
  final bool descending;
}

abstract interface class WSHistoryRecord {
  DateTime get time;
}

final class WSActivity implements WSHistoryRecord {
  const WSActivity({
    required this.time,
    required this.steps,
    required this.distance,
    required this.energy,
    required this.activeTime,
    required this.mode,
    this.avgHeartBpm = 0,
    this.bucketMinutes = 15,
    this.flags = 0,
    this.hasAvgHeartRate = false,
    this.incompleteBucket = false,
  });

  @override
  final DateTime time;
  final int steps;
  final int distance;
  final int energy;
  final int activeTime;
  final int mode;
  final int avgHeartBpm;
  final int bucketMinutes;
  final int flags;
  final bool hasAvgHeartRate;
  final bool incompleteBucket;

  int get caloriesTenthKcal => energy;
  int get distanceMeters => distance;
}

final class WSSleep implements WSHistoryRecord {
  const WSSleep({
    required this.time,
    required this.mode,
    this.flags = 0,
    this.timeRewind = false,
  });

  @override
  final DateTime time;
  final int mode;
  final int flags;
  final bool timeRewind;

  int get state => mode;
}

/// Heart rate history point (`0x23`); [time] is wall-clock epoch seconds.
final class WSHeartRate {
  const WSHeartRate({required this.time, required this.bpm});

  final int time;
  final int bpm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WSHeartRate && other.time == time && other.bpm == bpm;

  @override
  int get hashCode => Object.hash(time, bpm);
}

final class WSBloodPressure implements WSHistoryRecord {
  const WSBloodPressure({
    required this.time,
    required this.systolic,
    required this.diastolic,
  });

  @override
  final DateTime time;
  final int systolic;
  final int diastolic;
}

final class WSBloodOxygen implements WSHistoryRecord {
  const WSBloodOxygen({
    required this.time,
    required this.value,
    this.high,
    this.low,
  });

  @override
  final DateTime time;
  final int value;
  final int? high;
  final int? low;

  int get currentPercent => value;
  int? get highPercent => high;
  int? get lowPercent => low;
}

final class WSHrv implements WSHistoryRecord {
  const WSHrv({required this.time, required this.sdnn});

  @override
  final DateTime time;
  final int sdnn;

  int get sdnnMs => sdnn;
}

final class WSPressure implements WSHistoryRecord {
  const WSPressure({required this.time, required this.value});

  @override
  final DateTime time;
  final int value;
}

final class WSTemperature implements WSHistoryRecord {
  const WSTemperature({
    required this.time,
    required this.skinTemperature,
    required this.heatStress,
    required this.worn,
    required this.compensated,
    this.bodyHundredthCelsius,
    this.skinHundredthCelsius,
    this.heatStressRaw,
    this.flags = 0,
  });

  @override
  final DateTime time;
  final double skinTemperature;
  final int heatStress;
  final bool worn;
  final bool compensated;
  final int? bodyHundredthCelsius;
  final int? skinHundredthCelsius;
  final int? heatStressRaw;
  final int flags;
}

final class WSBloodGlucose implements WSHistoryRecord {
  const WSBloodGlucose({required this.time, required this.value});

  @override
  final DateTime time;
  final int value;

  int get mmolLtenth => value;
}

final class WSSport implements WSHistoryRecord {
  const WSSport({
    required this.time,
    required this.mode,
    required this.duration,
    required this.pauseCount,
    required this.pauseDuration,
    required this.steps,
    required this.distance,
    required this.energy,
    this.heartRateMax,
    this.heartRateAverage,
    this.heartRateMin,
    this.sportId = 0,
    this.startTime,
    this.endTime,
    this.effectiveDurationSec,
    this.totalDurationSec,
    this.detailFlags = 0,
    this.hasDetail = false,
  });

  @override
  final DateTime time;
  final int mode;
  final int duration;
  final int pauseCount;
  final int pauseDuration;
  final int steps;
  final int distance;
  final int energy;
  final int? heartRateMax;
  final int? heartRateAverage;
  final int? heartRateMin;
  final int sportId;
  final int? startTime;
  final int? endTime;
  final int? effectiveDurationSec;
  final int? totalDurationSec;
  final int detailFlags;
  final bool hasDetail;

  int get distanceMeters => distance;
  int get caloriesTenthKcal => energy;
  int? get avgHeartBpm => heartRateAverage;
}
