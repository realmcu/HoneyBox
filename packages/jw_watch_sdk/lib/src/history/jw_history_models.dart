/// Scope required for every JW health-history operation.
///
/// [userId] is the user ID that successfully authenticated the JW session and
/// [deviceMac] is the public BLE connection address. Neither has a default:
/// health data must never fall into an implicit user or device bucket.
final class JWHistoryScope {
  JWHistoryScope({required String userId, required String deviceMac})
      : userId = userId.trim(),
        deviceMac = deviceMac.trim() {
    if (this.userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be blank');
    }
    if (this.deviceMac.isEmpty) {
      throw ArgumentError.value(deviceMac, 'deviceMac', 'must not be blank');
    }
  }

  final String userId;
  final String deviceMac;
}

/// A stable time-range query for one authenticated JW user and one watch.
final class JWHistoryQuery {
  JWHistoryQuery({
    required this.scope,
    this.from,
    this.to,
    this.limit = 100,
    this.descending = false,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    if (from != null && to != null && from!.isAfter(to!)) {
      throw ArgumentError('from must not be after to');
    }
  }

  final JWHistoryScope scope;
  final DateTime? from;
  final DateTime? to;
  final int limit;
  final bool descending;
}

/// Firmware calendar fields (Y-M-D and minutes-from-midnight) are device-local
/// wall time, matching Android `DateUtil.getTime` / `HomeSpo2Bean` — not UTC.
DateTime parseJWDeviceLocalDateTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int second = 0,
]) =>
    DateTime(year, month, day, hour, minute, second);

/// Base contract shared by all persisted JW health records.
abstract interface class JWHistoryRecord {
  DateTime get time;
}

final class JWActivity implements JWHistoryRecord {
  const JWActivity({
    required this.time,
    required this.steps,
    required this.distance,
    required this.energy,
    required this.activeTime,
    required this.mode,
  });
  @override
  final DateTime time;
  final int steps, distance, energy, activeTime, mode;
}

final class JWSleep implements JWHistoryRecord {
  const JWSleep({required this.time, required this.mode});
  @override
  final DateTime time;
  final int mode;
}

final class JWHeartRate implements JWHistoryRecord {
  const JWHeartRate({required this.time, required this.heartRate});
  @override
  final DateTime time;
  final int heartRate;
}

final class JWBloodPressure implements JWHistoryRecord {
  const JWBloodPressure(
      {required this.time, required this.systolic, required this.diastolic});
  @override
  final DateTime time;
  final int systolic, diastolic;
}

final class JWBloodOxygen implements JWHistoryRecord {
  const JWBloodOxygen(
      {required this.time, required this.value, this.high, this.low});
  @override
  final DateTime time;
  final int value;
  final int? high, low;
}

final class JWHrv implements JWHistoryRecord {
  const JWHrv({required this.time, required this.sdnn});
  @override
  final DateTime time;
  final int sdnn;
}

final class JWPressure implements JWHistoryRecord {
  const JWPressure({required this.time, required this.value});
  @override
  final DateTime time;
  final int value;
}

/// Temperature fields deliberately retain the current JW Flutter meanings.
final class JWTemperature implements JWHistoryRecord {
  const JWTemperature({
    required this.time,
    required this.skinTemperature,
    required this.heatStress,
    required this.worn,
    required this.compensated,
  });
  @override
  final DateTime time;
  final double skinTemperature;
  final int heatStress;
  final bool worn, compensated;
}

final class JWBloodGlucose implements JWHistoryRecord {
  /// [value] uses the existing JW convention: an integer in 0.1 mmol/L.
  const JWBloodGlucose({required this.time, required this.value});
  @override
  final DateTime time;
  final int value;
}

final class JWSport implements JWHistoryRecord {
  const JWSport({
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
  });
  @override
  final DateTime time;
  final int mode, duration, pauseCount, pauseDuration, steps, distance, energy;
  final int? heartRateMax, heartRateAverage, heartRateMin;
}
