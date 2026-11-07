import 'dart:math' as math;

import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_data_units.dart';

/// App `SportStepBean` 日图半小时桶。
final class JwAppStepSlot {
  const JwAppStepSlot({
    required this.index,
    required this.time,
    required this.steps,
    required this.kcal,
  });

  final int index; // 0..47
  final DateTime time;
  final int steps;
  final int kcal;
}

/// App `HrStatisticsBean` 小时桶。
final class JwAppHrHourBucket {
  const JwAppHrHourBucket({
    required this.hour,
    required this.startTime,
    required this.rates,
    required this.avgHr,
  });

  final int hour;
  final DateTime startTime;
  final List<int> rates;
  final int avgHr;
}

/// 睡眠阶段段（App SleepDetail）。
/// [appType]: 0 深睡 / 1 浅睡 / 2|3 眼动 / 4 清醒
final class JwAppSleepSegment {
  const JwAppSleepSegment({
    required this.begin,
    required this.end,
    required this.appType,
    required this.minutes,
  });

  final DateTime begin;
  final DateTime end;
  final int appType;
  final int minutes;
}

/// 血压小时桶。
final class JwAppBpHourBucket {
  const JwAppBpHourBucket({
    required this.hour,
    required this.startTime,
    required this.avgHigh,
    required this.avgLow,
  });

  final int hour;
  final DateTime startTime;
  final int avgHigh;
  final int avgLow;
}

/// 血氧小时桶。
final class JwAppSpo2HourBucket {
  const JwAppSpo2HourBucket({
    required this.hour,
    required this.startTime,
    required this.values,
    required this.maxValue,
    required this.minValue,
  });

  final int hour;
  final DateTime startTime;
  final List<int> values;
  final int maxValue;
  final int minValue;
}

/// 体温半小时桶。
final class JwAppTempSlot {
  const JwAppTempSlot({
    required this.index,
    required this.time,
    required this.temps,
    required this.avg,
    required this.max,
    required this.min,
  });

  final int index; // 0..47
  final DateTime time;
  final List<double> temps;
  final double avg;
  final double max;
  final double min;
}

/// HRV 小时桶。
final class JwAppHrvHourBucket {
  const JwAppHrvHourBucket({
    required this.hour,
    required this.startTime,
    required this.values,
    required this.max,
    required this.min,
  });

  final int hour;
  final DateTime startTime;
  final List<int> values;
  final int max;
  final int min;
}

/// 压力 10 分钟槽（144）。
final class JwAppPressureSlot {
  const JwAppPressureSlot({
    required this.index,
    required this.time,
    required this.avg,
    required this.max,
    required this.min,
  });

  final int index; // 0..143
  final DateTime time;
  final int avg;
  final int max;
  final int min;
}

/// 血糖小时桶。
final class JwAppGluHourBucket {
  const JwAppGluHourBucket({
    required this.hour,
    required this.startTime,
    required this.values,
    required this.avg,
    required this.max,
    required this.min,
  });

  final int hour;
  final DateTime startTime;
  /// mmol/L
  final List<double> values;
  final double avg;
  final double max;
  final double min;
}

/// 运动日柱（按小时累计时长分钟）。
final class JwAppSportHourBar {
  const JwAppSportHourBar({
    required this.hour,
    required this.startTime,
    required this.minutes,
    required this.sessions,
  });

  final int hour;
  final DateTime startTime;
  final int minutes;
  final List<JWSport> sessions;
}

List<JwAppStepSlot> jwAppBuildStepSlots(List<Object> records, DateTime day) {
  final steps = List<int>.filled(48, 0);
  final energy = List<int>.filled(48, 0);
  for (final row in records) {
    if (row is! JWActivity) continue;
    final idx =
        (row.time.hour * 2 + (row.time.minute >= 30 ? 1 : 0)).clamp(0, 47);
    steps[idx] += row.steps;
    energy[idx] += row.energy;
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var i = 0; i < 48; i++)
      JwAppStepSlot(
        index: i,
        time: start.add(Duration(minutes: i * 30)),
        steps: steps[i],
        kcal: jwDataCalToKcal(energy[i]).round(),
      ),
  ];
}

List<JwAppHrHourBucket> jwAppBuildHrHours(List<Object> records, DateTime day) {
  final buckets = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! JWHeartRate) continue;
    if (row.heartRate <= 0) continue;
    buckets[row.time.hour.clamp(0, 23)].add(row.heartRate);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      JwAppHrHourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        rates: buckets[h],
        avgHr: buckets[h].isEmpty
            ? 0
            : (buckets[h].reduce((a, b) => a + b) / buckets[h].length).round(),
      ),
  ];
}

int jwAppStepMaxAxis(List<JwAppStepSlot> slots) {
  var max = 0;
  for (final s in slots) {
    if (s.steps > max) max = s.steps;
  }
  if (max <= 0) return 2000;
  return ((max ~/ 1000) + 1) * 1000;
}

({int max, int min, double avg}) jwAppHrAxis(List<JwAppHrHourBucket> hours) {
  var min = 999;
  var max = 0;
  var sum = 0;
  var n = 0;
  for (final h in hours) {
    for (final r in h.rates) {
      if (r <= 0) continue;
      if (r < min) min = r;
      if (r > max) max = r;
      sum += r;
      n++;
    }
  }
  if (n == 0) return (max: 160, min: 40, avg: 0);
  final avg = sum / n;
  var axisMax = ((max / 10).ceil() * 10).clamp(60, 220);
  var axisMin = ((min / 10).floor() * 10).clamp(30, 120);
  if (axisMax <= axisMin) axisMax = axisMin + 40;
  return (max: axisMax, min: axisMin, avg: avg);
}

/// JW mode → App sleep chart type：1浅→1，2深→0，3退出→4，4 REM→2。
int jwAppSleepModeToAppType(int mode) => switch (mode) {
      1 => 1,
      2 => 0,
      3 => 4,
      4 => 2,
      _ => 1,
    };

List<JwAppSleepSegment> jwAppBuildSleepSegments(List<Object> records) {
  final events = <JWSleep>[
    for (final row in records)
      if (row is JWSleep) row,
  ]..sort((a, b) => a.time.compareTo(b.time));
  if (events.length < 2) return const [];
  final out = <JwAppSleepSegment>[];
  for (var i = 0; i < events.length - 1; i++) {
    final cur = events[i];
    final next = events[i + 1];
    final minutes = next.time.difference(cur.time).inMinutes;
    if (minutes <= 0) continue;
    // 退出睡眠节点本身不画段；段归属当前状态。
    if (cur.mode == 3) continue;
    out.add(
      JwAppSleepSegment(
        begin: cur.time,
        end: next.time,
        appType: jwAppSleepModeToAppType(cur.mode),
        minutes: minutes,
      ),
    );
  }
  return out;
}

List<JwAppBpHourBucket> jwAppBuildBpHours(List<Object> records, DateTime day) {
  final high = List<List<int>>.generate(24, (_) => <int>[]);
  final low = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! JWBloodPressure) continue;
    if (row.systolic <= 0 || row.diastolic <= 0) continue;
    final h = row.time.hour.clamp(0, 23);
    high[h].add(row.systolic);
    low[h].add(row.diastolic);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      JwAppBpHourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        avgHigh: high[h].isEmpty
            ? 0
            : (high[h].reduce((a, b) => a + b) / high[h].length).round(),
        avgLow: low[h].isEmpty
            ? 0
            : (low[h].reduce((a, b) => a + b) / low[h].length).round(),
      ),
  ];
}

List<JwAppSpo2HourBucket> jwAppBuildSpo2Hours(
  List<Object> records,
  DateTime day,
) {
  final buckets = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! JWBloodOxygen) continue;
    if (row.value <= 0) continue;
    buckets[row.time.hour.clamp(0, 23)].add(row.value);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      JwAppSpo2HourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        values: buckets[h],
        maxValue: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.max),
        minValue: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.min),
      ),
  ];
}

List<JwAppTempSlot> jwAppBuildTempSlots(List<Object> records, DateTime day) {
  final buckets = List<List<double>>.generate(48, (_) => <double>[]);
  for (final row in records) {
    if (row is! JWTemperature) continue;
    if (row.skinTemperature <= 0) continue;
    final idx =
        (row.time.hour * 2 + (row.time.minute >= 30 ? 1 : 0)).clamp(0, 47);
    buckets[idx].add(row.skinTemperature);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var i = 0; i < 48; i++)
      JwAppTempSlot(
        index: i,
        time: start.add(Duration(minutes: i * 30)),
        temps: buckets[i],
        avg: buckets[i].isEmpty
            ? 0
            : buckets[i].reduce((a, b) => a + b) / buckets[i].length,
        max: buckets[i].isEmpty ? 0 : buckets[i].reduce(math.max),
        min: buckets[i].isEmpty ? 0 : buckets[i].reduce(math.min),
      ),
  ];
}

List<JwAppHrvHourBucket> jwAppBuildHrvHours(List<Object> records, DateTime day) {
  final buckets = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! JWHrv) continue;
    if (row.sdnn <= 0) continue;
    buckets[row.time.hour.clamp(0, 23)].add(row.sdnn);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      JwAppHrvHourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        values: buckets[h],
        max: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.max),
        min: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.min),
      ),
  ];
}

List<JwAppPressureSlot> jwAppBuildPressureSlots(
  List<Object> records,
  DateTime day,
) {
  final avgs = List<List<int>>.generate(144, (_) => <int>[]);
  for (final row in records) {
    if (row is! JWPressure) continue;
    if (row.value <= 0) continue;
    final idx = ((row.time.hour * 60 + row.time.minute) ~/ 10).clamp(0, 143);
    avgs[idx].add(row.value);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var i = 0; i < 144; i++)
      JwAppPressureSlot(
        index: i,
        time: start.add(Duration(minutes: i * 10)),
        avg: avgs[i].isEmpty
            ? 0
            : (avgs[i].reduce((a, b) => a + b) / avgs[i].length).round(),
        max: avgs[i].isEmpty ? 0 : avgs[i].reduce(math.max),
        min: avgs[i].isEmpty ? 0 : avgs[i].reduce(math.min),
      ),
  ];
}

List<JwAppGluHourBucket> jwAppBuildGluHours(List<Object> records, DateTime day) {
  final buckets = List<List<double>>.generate(24, (_) => <double>[]);
  for (final row in records) {
    if (row is! JWBloodGlucose) continue;
    if (row.value <= 0) continue;
    buckets[row.time.hour.clamp(0, 23)].add(row.value / 10.0);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      JwAppGluHourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        values: buckets[h],
        avg: buckets[h].isEmpty
            ? 0
            : buckets[h].reduce((a, b) => a + b) / buckets[h].length,
        max: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.max),
        min: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.min),
      ),
  ];
}

List<JwAppSportHourBar> jwAppBuildSportHours(
  List<Object> records,
  DateTime day,
) {
  final mins = List<int>.filled(24, 0);
  final sessions = List<List<JWSport>>.generate(24, (_) => <JWSport>[]);
  for (final row in records) {
    if (row is! JWSport) continue;
    final h = row.time.hour.clamp(0, 23);
    mins[h] += (row.duration / 60).round();
    sessions[h].add(row);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      JwAppSportHourBar(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        minutes: mins[h],
        sessions: sessions[h],
      ),
  ];
}
