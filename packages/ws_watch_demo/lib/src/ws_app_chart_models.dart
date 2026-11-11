import 'dart:math' as math;

import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_data_units.dart';
import 'ws_demo_time.dart';

/// App `SportStepBean` 日图半小时桶。
final class WsAppStepSlot {
  const WsAppStepSlot({
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
final class WsAppHrHourBucket {
  const WsAppHrHourBucket({
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
final class WsAppSleepSegment {
  const WsAppSleepSegment({
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
final class WsAppBpHourBucket {
  const WsAppBpHourBucket({
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
final class WsAppSpo2HourBucket {
  const WsAppSpo2HourBucket({
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
final class WsAppTempSlot {
  const WsAppTempSlot({
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
final class WsAppHrvHourBucket {
  const WsAppHrvHourBucket({
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
final class WsAppPressureSlot {
  const WsAppPressureSlot({
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
final class WsAppGluHourBucket {
  const WsAppGluHourBucket({
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
final class WsAppSportHourBar {
  const WsAppSportHourBar({
    required this.hour,
    required this.startTime,
    required this.minutes,
    required this.sessions,
  });

  final int hour;
  final DateTime startTime;
  final int minutes;
  final List<WSSport> sessions;
}

List<WsAppStepSlot> jwAppBuildStepSlots(List<Object> records, DateTime day) {
  final steps = List<int>.filled(48, 0);
  final energy = List<int>.filled(48, 0);
  for (final row in records) {
    if (row is! WSActivity) continue;
    final idx =
        (row.time.hour * 2 + (row.time.minute >= 30 ? 1 : 0)).clamp(0, 47);
    steps[idx] += row.steps;
    energy[idx] += row.energy;
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var i = 0; i < 48; i++)
      WsAppStepSlot(
        index: i,
        time: start.add(Duration(minutes: i * 30)),
        steps: steps[i],
        kcal: jwDataCalToKcal(energy[i]).round(),
      ),
  ];
}

List<WsAppHrHourBucket> jwAppBuildHrHours(List<Object> records, DateTime day) {
  final buckets = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! WSHeartRate) continue;
    if (row.bpm <= 0) continue;
    buckets[wsDemoWallTimeToLocal(row.time).hour.clamp(0, 23)].add(row.bpm);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      WsAppHrHourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        rates: buckets[h],
        avgHr: buckets[h].isEmpty
            ? 0
            : (buckets[h].reduce((a, b) => a + b) / buckets[h].length).round(),
      ),
  ];
}

/// 对齐 App 日图 Y 轴：步数 `WatchStepDataFragment` → `((max/1000)+1)*1000`，下限 0。
int jwAppStepMaxAxis(List<WsAppStepSlot> slots) {
  var max = 0;
  for (final s in slots) {
    if (s.steps > max) max = s.steps;
  }
  if (max <= 0) return 2000;
  return ((max ~/ 1000) + 1) * 1000;
}

/// 对齐 App 心率日图：`max2=(max/10+2)*10`，`min2=(min/10-2)*10`；空数据 160/40。
({int max, int min, double avg}) jwAppHrAxis(List<WsAppHrHourBucket> hours) {
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
  var axisMax = (max ~/ 10 + 2) * 10;
  // App 可能算出负值；绘图侧按 0 兜底，避免 invert。
  var axisMin = math.max(0, (min ~/ 10 - 2) * 10);
  if (axisMax <= axisMin) axisMax = axisMin + 40;
  return (max: axisMax, min: axisMin, avg: avg);
}

/// 对齐 App `BpTouchView2`：max=`max(160,high)` 后再 `(max/10+2)*10`；min 固定 30。
({int max, int min}) jwAppBpAxis(List<WsAppBpHourBucket> hours) {
  var maxHigh = 0;
  var n = 0;
  for (final h in hours) {
    if (h.avgHigh > 0) {
      maxHigh = math.max(maxHigh, h.avgHigh);
      n++;
    }
  }
  if (n == 0) return (max: 180, min: 30);
  var axisMax = math.max(160, maxHigh);
  axisMax = (axisMax ~/ 10 + 2) * 10;
  return (max: axisMax, min: 30);
}

/// 对齐 App `WatchBloodOxygenCommonDataFragment`：默认 100/85；
/// max=`min(100, dataMax+1)`；min 在 dataMin<85 时降到 `max(70, dataMin-1)`。
({int max, int min}) jwAppSpo2Axis(List<WsAppSpo2HourBucket> hours) {
  const defaultMax = 100;
  const defaultMin = 85;
  var dataMax = 0;
  var dataMin = 1000;
  for (final h in hours) {
    if (h.maxValue > dataMax) dataMax = h.maxValue;
    if (h.minValue > 0 && h.minValue < dataMin) dataMin = h.minValue;
  }
  if (dataMax <= 0 || dataMin == 1000) {
    return (max: defaultMax, min: defaultMin);
  }
  var chartMax = math.min(defaultMax, dataMax + 1);
  chartMax = math.max(chartMax, defaultMin + 1);
  var chartMin = defaultMin;
  if (dataMin > 0 && dataMin < defaultMin) {
    chartMin = math.max(70, dataMin - 1);
  }
  chartMin = math.min(chartMin, chartMax - 1);
  return (max: chartMax, min: chartMin);
}

/// 对齐 App `TempHeadAdapter`：`max*1.1+0.3` / `max(0, min*0.9-0.3)`；空 50/0。
({double max, double min, double avg}) jwAppTempAxis(List<WsAppTempSlot> slots) {
  double? maxT;
  double? minT;
  var sum = 0.0;
  var n = 0;
  for (final s in slots) {
    for (final t in s.temps) {
      if (t <= 0) continue;
      maxT = maxT == null ? t : math.max(maxT, t);
      minT = minT == null ? t : math.min(minT, t);
      sum += t;
      n++;
    }
  }
  if (n == 0) return (max: 50.0, min: 0.0, avg: 0.0);
  final avg = sum / n;
  var axisMax = maxT! * 1.1 + 0.3;
  var axisMin = math.max(0.0, minT! * 0.9 - 0.3);
  if (axisMax <= axisMin) {
    axisMax = 50;
    axisMin = 0;
  }
  return (max: axisMax, min: axisMin, avg: avg);
}

/// 对齐 App `FloatUtil.formatGLuMax/Min`：`max+max*0.1` / `min-min*0.2`；空 15/0。
({double max, double min, double avg}) jwAppGluAxis(
  List<WsAppGluHourBucket> hours,
) {
  double? maxV;
  double? minV;
  var sum = 0.0;
  var n = 0;
  for (final h in hours) {
    for (final v in h.values) {
      if (v <= 0) continue;
      maxV = maxV == null ? v : math.max(maxV, v);
      minV = minV == null ? v : math.min(minV, v);
      sum += v;
      n++;
    }
  }
  if (n == 0) {
    // bean 空值 15/0，经 format 后仍是 16.5 / 0
    return (max: 15 + 15 * 0.1, min: 0.0, avg: 0.0);
  }
  final avg = sum / n;
  final axisMax = maxV! + maxV * 0.1;
  final axisMin = math.max(0.0, minV! - minV * 0.2);
  return (max: axisMax, min: axisMin, avg: avg);
}

/// 对齐 App `PressureHeadAdapter`：Y max=`formatPressureChartMax`；Y min 固定 0。
({int axisMax, int avg}) jwAppPressureAxis(List<WsAppPressureSlot> slots) {
  var maxV = 0;
  var sum = 0;
  var n = 0;
  for (final s in slots) {
    if (s.avg <= 0) continue;
    final slotMax = s.max > 0 ? s.max : s.avg;
    if (slotMax > maxV) maxV = slotMax;
    sum += s.avg;
    n++;
  }
  // FloatUtil.formatPressureChartMax
  int axisMax;
  if (maxV <= 0) {
    axisMax = 100;
  } else {
    var padded = (maxV * 1.1).ceil();
    final rem = padded % 25;
    if (rem != 0) padded += 25 - rem;
    axisMax = padded;
  }
  final avg = n == 0 ? 0 : (sum / n).round();
  return (axisMax: axisMax, avg: avg);
}

/// 对齐 App HRV：`max(210, round((dataMax+60)/10)*10)`，下限 0。
int jwAppHrvChartMax(List<WsAppHrvHourBucket> hours) {
  var dataMax = 0;
  for (final h in hours) {
    if (h.max > dataMax) dataMax = h.max;
    for (final v in h.values) {
      if (v > dataMax) dataMax = v;
    }
  }
  final padded = dataMax + 60;
  final stepped = ((padded / 10.0).round() * 10);
  return math.max(210, stepped);
}

/// 运动时长柱：下限 0；上限取数据最大值（至少 60）。
int jwAppSportMaxMinutesAxis(List<WsAppSportHourBar> bars) {
  var m = 0;
  for (final b in bars) {
    if (b.minutes > m) m = b.minutes;
  }
  return m <= 0 ? 60 : m;
}

/// JW mode → App sleep chart type：1浅→1，2深→0，3退出→4，4 REM→2。
int jwAppSleepModeToAppType(int mode) => switch (mode) {
      1 => 1,
      2 => 0,
      3 => 4,
      4 => 2,
      _ => 1,
    };

List<WsAppSleepSegment> jwAppBuildSleepSegments(List<Object> records) {
  final events = <WSSleep>[
    for (final row in records)
      if (row is WSSleep) row,
  ]..sort((a, b) => a.time.compareTo(b.time));
  if (events.length < 2) return const [];
  final out = <WsAppSleepSegment>[];
  for (var i = 0; i < events.length - 1; i++) {
    final cur = events[i];
    final next = events[i + 1];
    final minutes = next.time.difference(cur.time).inMinutes;
    if (minutes <= 0) continue;
    // 退出睡眠节点本身不画段；段归属当前状态。
    if (cur.mode == 3) continue;
    out.add(
      WsAppSleepSegment(
        begin: cur.time,
        end: next.time,
        appType: jwAppSleepModeToAppType(cur.mode),
        minutes: minutes,
      ),
    );
  }
  return out;
}

List<WsAppBpHourBucket> jwAppBuildBpHours(List<Object> records, DateTime day) {
  final high = List<List<int>>.generate(24, (_) => <int>[]);
  final low = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! WSBloodPressure) continue;
    if (row.systolic <= 0 || row.diastolic <= 0) continue;
    final h = row.time.hour.clamp(0, 23);
    high[h].add(row.systolic);
    low[h].add(row.diastolic);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      WsAppBpHourBucket(
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

List<WsAppSpo2HourBucket> jwAppBuildSpo2Hours(
  List<Object> records,
  DateTime day,
) {
  final buckets = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! WSBloodOxygen) continue;
    if (row.value <= 0) continue;
    buckets[row.time.hour.clamp(0, 23)].add(row.value);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      WsAppSpo2HourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        values: buckets[h],
        maxValue: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.max),
        minValue: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.min),
      ),
  ];
}

List<WsAppTempSlot> jwAppBuildTempSlots(List<Object> records, DateTime day) {
  final buckets = List<List<double>>.generate(48, (_) => <double>[]);
  for (final row in records) {
    if (row is! WSTemperature) continue;
    if (row.skinTemperature <= 0) continue;
    final idx =
        (row.time.hour * 2 + (row.time.minute >= 30 ? 1 : 0)).clamp(0, 47);
    buckets[idx].add(row.skinTemperature);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var i = 0; i < 48; i++)
      WsAppTempSlot(
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

List<WsAppHrvHourBucket> jwAppBuildHrvHours(List<Object> records, DateTime day) {
  final buckets = List<List<int>>.generate(24, (_) => <int>[]);
  for (final row in records) {
    if (row is! WSHrv) continue;
    if (row.sdnn <= 0) continue;
    buckets[row.time.hour.clamp(0, 23)].add(row.sdnn);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      WsAppHrvHourBucket(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        values: buckets[h],
        max: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.max),
        min: buckets[h].isEmpty ? 0 : buckets[h].reduce(math.min),
      ),
  ];
}

List<WsAppPressureSlot> jwAppBuildPressureSlots(
  List<Object> records,
  DateTime day,
) {
  final avgs = List<List<int>>.generate(144, (_) => <int>[]);
  for (final row in records) {
    if (row is! WSPressure) continue;
    if (row.value <= 0) continue;
    final idx = ((row.time.hour * 60 + row.time.minute) ~/ 10).clamp(0, 143);
    avgs[idx].add(row.value);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var i = 0; i < 144; i++)
      WsAppPressureSlot(
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

List<WsAppGluHourBucket> jwAppBuildGluHours(List<Object> records, DateTime day) {
  final buckets = List<List<double>>.generate(24, (_) => <double>[]);
  for (final row in records) {
    if (row is! WSBloodGlucose) continue;
    if (row.value <= 0) continue;
    buckets[row.time.hour.clamp(0, 23)].add(row.value / 10.0);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      WsAppGluHourBucket(
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

List<WsAppSportHourBar> jwAppBuildSportHours(
  List<Object> records,
  DateTime day,
) {
  final mins = List<int>.filled(24, 0);
  final sessions = List<List<WSSport>>.generate(24, (_) => <WSSport>[]);
  for (final row in records) {
    if (row is! WSSport) continue;
    final h = row.time.hour.clamp(0, 23);
    mins[h] += (row.duration / 60).round();
    sessions[h].add(row);
  }
  final start = DateTime(day.year, day.month, day.day);
  return [
    for (var h = 0; h < 24; h++)
      WsAppSportHourBar(
        hour: h,
        startTime: start.add(Duration(hours: h)),
        minutes: mins[h],
        sessions: sessions[h],
      ),
  ];
}
