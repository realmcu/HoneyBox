import 'dart:typed_data';

import 'jw_today_activity_models.dart';

int _u24(Uint8List data, int offset) =>
    ((data[offset] & 0xff) << 16) |
    ((data[offset + 1] & 0xff) << 8) |
    (data[offset + 2] & 0xff);

int _u16(Uint8List data, int offset) =>
    ((data[offset] & 0xff) << 8) | (data[offset + 1] & 0xff);

/// Parses HL `SPORTS_DATA_TODAY_ADJUST_RSP` (`cmd 0x05` / `key 0x0C`).
JWTodayActivitySummary decodeJWTodayActivitySummary(Uint8List data) {
  if (data.length < 16) {
    throw FormatException(
      'JW today activity summary requires at least 16 bytes, got ${data.length}',
    );
  }
  final offset = data[0] & 0xff;
  final steps = _u24(data, 1);
  final caloriesCal = _u24(data, 4);
  final distanceMeters = _u24(data, 7);
  final recentSteps = _u16(data, 10);

  if (data.length >= 17) {
    final recentCaloriesCal = _u24(data, 12);
    final recentDistanceMeters = _u16(data, 15);
    return JWTodayActivitySummary(
      slotOffset: offset,
      steps: steps,
      caloriesCal: caloriesCal,
      distanceMeters: distanceMeters,
      recentSteps: recentSteps,
      recentCaloriesCal: recentCaloriesCal,
      recentDistanceMeters: recentDistanceMeters,
    );
  }

  final recentCaloriesCal = _u16(data, 12);
  final recentDistanceMeters = _u16(data, 14);
  return JWTodayActivitySummary(
    slotOffset: offset,
    steps: steps,
    caloriesCal: caloriesCal,
    distanceMeters: distanceMeters,
    recentSteps: recentSteps,
    recentCaloriesCal: recentCaloriesCal,
    recentDistanceMeters: recentDistanceMeters,
  );
}
