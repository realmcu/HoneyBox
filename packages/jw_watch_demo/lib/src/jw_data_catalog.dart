import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_data_units.dart';

/// 数据 Tab 类型目录（对齐 App WatchData 卡片 + SDK 可查询类型）。
enum JwDataTypeId {
  activity,
  sleep,
  heartRate,
  bloodPressure,
  bloodOxygen,
  temperature,
  hrv,
  pressure,
  bloodSugar,
  sport,
}

final class JwDataTypeItem {
  const JwDataTypeItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    required this.requiredFunctions,
    this.unitHint,
  });

  final JwDataTypeId id;
  final String title;
  final IconData icon;

  /// 对应同步分类（用于日志/调试对照）；部分类型仅本地表无独立 wire bucket。
  final JWHistorySyncCategory? category;

  /// 任一支持即视为设备支持；空列表表示不依赖能力位。
  final List<JWDeviceFunction> requiredFunctions;
  final String? unitHint;
}

/// Demo 数据首页全量展示的类型列表。
List<JwDataTypeItem> jwDataCatalog() => const [
      JwDataTypeItem(
        id: JwDataTypeId.activity,
        title: '步数',
        icon: Icons.directions_walk_outlined,
        category: JWHistorySyncCategory.activity,
        requiredFunctions: [JWDeviceFunction.step],
        unitHint: '步',
      ),
      JwDataTypeItem(
        id: JwDataTypeId.sleep,
        title: '睡眠',
        icon: Icons.bedtime_outlined,
        category: JWHistorySyncCategory.sleep,
        requiredFunctions: [JWDeviceFunction.sleep],
      ),
      JwDataTypeItem(
        id: JwDataTypeId.heartRate,
        title: '心率',
        icon: Icons.favorite_outline,
        category: JWHistorySyncCategory.heartRate,
        requiredFunctions: [JWDeviceFunction.rate],
        unitHint: 'bpm',
      ),
      JwDataTypeItem(
        id: JwDataTypeId.bloodPressure,
        title: '血压',
        icon: Icons.monitor_heart_outlined,
        category: JWHistorySyncCategory.bloodPressure,
        requiredFunctions: [
          JWDeviceFunction.rtkBp3,
          JWDeviceFunction.bpDetection,
          JWDeviceFunction.bp2,
        ],
        unitHint: 'mmHg',
      ),
      JwDataTypeItem(
        id: JwDataTypeId.bloodOxygen,
        title: '血氧',
        icon: Icons.water_drop_outlined,
        category: JWHistorySyncCategory.bloodOxygen,
        requiredFunctions: [JWDeviceFunction.spo2Measure],
        unitHint: '%',
      ),
      JwDataTypeItem(
        id: JwDataTypeId.temperature,
        title: '体温',
        icon: Icons.thermostat_outlined,
        category: JWHistorySyncCategory.temperature,
        requiredFunctions: [JWDeviceFunction.temperature],
        unitHint: '℃',
      ),
      JwDataTypeItem(
        id: JwDataTypeId.hrv,
        title: 'HRV',
        icon: Icons.show_chart_outlined,
        category: JWHistorySyncCategory.hrv,
        requiredFunctions: [JWDeviceFunction.rtkHrv],
        unitHint: 'ms',
      ),
      JwDataTypeItem(
        id: JwDataTypeId.pressure,
        title: '压力',
        icon: Icons.spa_outlined,
        category: JWHistorySyncCategory.pressure,
        requiredFunctions: [JWDeviceFunction.pressure],
      ),
      JwDataTypeItem(
        id: JwDataTypeId.bloodSugar,
        title: '血糖',
        icon: Icons.bloodtype_outlined,
        category: null,
        requiredFunctions: [JWDeviceFunction.bloodSugar],
        unitHint: 'mmol/L',
      ),
      JwDataTypeItem(
        id: JwDataTypeId.sport,
        title: '运动',
        icon: Icons.fitness_center_outlined,
        category: JWHistorySyncCategory.sport,
        requiredFunctions: [
          JWDeviceFunction.multiSport,
          JWDeviceFunction.appSportRateDetect,
        ],
      ),
    ];

DateTime jwDataDayStart(DateTime day) =>
    DateTime(day.year, day.month, day.day);

DateTime jwDataDayEnd(DateTime day) =>
    jwDataDayStart(day).add(const Duration(days: 1, milliseconds: -1));

String jwDataFormatDay(DateTime day) {
  final now = DateTime.now();
  final today = jwDataDayStart(now);
  final target = jwDataDayStart(day);
  if (target == today) return '今天';
  if (target == today.subtract(const Duration(days: 1))) return '昨天';
  // 对齐 App `DateUtil.toDate3` → `yyyy.MM.dd`
  return '${target.year}.'
      '${target.month.toString().padLeft(2, '0')}.'
      '${target.day.toString().padLeft(2, '0')}';
}

String jwDataFormatTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// 单条记录标题（卡片 / 列表主文案），单位对齐 App。
String jwDataLatestSummary(Object record) {
  return switch (record) {
    JWActivity r => '${r.steps} 步',
    JWSleep r => jwDataSleepModeLabel(r.mode),
    JWHeartRate r => '${r.heartRate} bpm',
    JWBloodPressure r => '${r.systolic}/${r.diastolic} mmHg',
    JWBloodOxygen r => '${r.value}%',
    JWTemperature r => '${r.skinTemperature.toStringAsFixed(1)} ℃',
    JWHrv r => 'SDNN ${r.sdnn} ms',
    JWPressure r => '${r.value}',
    JWBloodGlucose r => '${jwDataFormatMmol(r.value)} mmol/L',
    JWSport r =>
      '${jwDataSportModeLabel(r.mode)} · ${jwDataFormatDuration(r.duration)}',
    _ => '有数据',
  };
}

/// 列表副文案：时间 + 关键指标。
String jwDataRecordDetailLine(Object record) {
  final time = record is JWHistoryRecord
      ? jwDataFormatTime(record.time)
      : null;
  final body = switch (record) {
    JWActivity r =>
      '${r.steps} 步 · ${jwDataFormatKm(r.distance)} km · '
          '${jwDataFormatKcal(r.energy)} kcal',
    JWSleep r => jwDataSleepModeLabel(r.mode),
    JWHeartRate r => '${r.heartRate} bpm',
    JWBloodPressure r => '${r.systolic}/${r.diastolic} mmHg',
    JWBloodOxygen r => r.high != null && r.low != null
        ? '${r.value}%（${r.low}-${r.high}）'
        : '${r.value}%',
    JWTemperature r =>
      '${r.skinTemperature.toStringAsFixed(1)} ℃'
          '${r.worn ? ' · 佩戴' : ''}',
    JWHrv r => 'SDNN ${r.sdnn} ms',
    JWPressure r => '压力 ${r.value}',
    JWBloodGlucose r => '${jwDataFormatMmol(r.value)} mmol/L',
    JWSport r =>
      '${jwDataSportModeLabel(r.mode)} · ${jwDataFormatDuration(r.duration)}'
          '${r.steps > 0 ? ' · ${r.steps} 步' : ''}'
          '${r.distance > 0 ? ' · ${jwDataFormatKm(r.distance)} km' : ''}',
    _ => record.runtimeType.toString(),
  };
  return time == null ? body : '$time · $body';
}

Future<Object?> jwDataQueryLatest({
  required JWHistoryStore store,
  required JWHistoryScope scope,
  required JwDataTypeId id,
}) async {
  final query = JWHistoryQuery(scope: scope, limit: 1, descending: true);
  final list = await jwDataQueryList(store: store, query: query, id: id);
  return list.isEmpty ? null : list.first;
}

Future<List<Object>> jwDataQueryDay({
  required JWHistoryStore store,
  required JWHistoryScope scope,
  required JwDataTypeId id,
  required DateTime day,
}) {
  final query = JWHistoryQuery(
    scope: scope,
    from: jwDataDayStart(day),
    to: jwDataDayEnd(day),
    limit: 2000,
    descending: false,
  );
  return jwDataQueryList(store: store, query: query, id: id);
}

/// 首页卡片摘要：步数用「当日合计」，其它优先当日最近一条，否则全局最近一条。
Future<String> jwDataQueryCardSummary({
  required JWHistoryStore store,
  required JWHistoryScope scope,
  required JwDataTypeId id,
  DateTime? day,
}) async {
  final targetDay = jwDataDayStart(day ?? DateTime.now());
  final dayRows = await jwDataQueryDay(
    store: store,
    scope: scope,
    id: id,
    day: targetDay,
  );

  if (id == JwDataTypeId.activity && dayRows.isNotEmpty) {
    var steps = 0;
    for (final row in dayRows) {
      if (row is JWActivity) steps += row.steps;
    }
    final label = jwDataFormatDay(targetDay);
    return '$label $steps 步';
  }

  if (id == JwDataTypeId.sleep && dayRows.isNotEmpty) {
    final sleep = _summarizeSleepMinutes(dayRows);
    if (sleep.totalMinutes > 0) {
      return '${jwDataFormatDay(targetDay)} '
          '${jwDataFormatDuration(sleep.totalMinutes * 60)}';
    }
  }

  if (id == JwDataTypeId.sport && dayRows.isNotEmpty) {
    var seconds = 0;
    for (final row in dayRows) {
      if (row is JWSport) seconds += row.duration;
    }
    return '${jwDataFormatDay(targetDay)} '
        '${dayRows.length} 次 · ${jwDataFormatDuration(seconds)}';
  }

  if (dayRows.isNotEmpty) {
    final latest = dayRows.last;
    final summary = jwDataLatestSummary(latest);
    final time = latest is JWHistoryRecord
        ? jwDataFormatTime(latest.time)
        : null;
    return time == null
        ? '${jwDataFormatDay(targetDay)} $summary'
        : '${jwDataFormatDay(targetDay)} $time · $summary';
  }

  final latest = await jwDataQueryLatest(store: store, scope: scope, id: id);
  if (latest == null) return '暂无数据';
  final time = latest is JWHistoryRecord ? latest.time : null;
  final summary = jwDataLatestSummary(latest);
  if (time == null) return summary;
  return '$summary · ${jwDataFormatDay(time)} ${jwDataFormatTime(time)}';
}

Future<List<Object>> jwDataQueryList({
  required JWHistoryStore store,
  required JWHistoryQuery query,
  required JwDataTypeId id,
}) async {
  switch (id) {
    case JwDataTypeId.activity:
      return store.queryActivities(query);
    case JwDataTypeId.sleep:
      return store.querySleeps(query);
    case JwDataTypeId.heartRate:
      return store.queryHeartRates(query);
    case JwDataTypeId.bloodPressure:
      return store.queryBloodPressures(query);
    case JwDataTypeId.bloodOxygen:
      return store.queryBloodOxygens(query);
    case JwDataTypeId.temperature:
      return store.queryTemperatures(query);
    case JwDataTypeId.hrv:
      return store.queryHrvs(query);
    case JwDataTypeId.pressure:
      return store.queryPressures(query);
    case JwDataTypeId.bloodSugar:
      return store.queryBloodGlucoses(query);
    case JwDataTypeId.sport:
      return store.querySports(query);
  }
}

final class JwSleepDaySummary {
  const JwSleepDaySummary({
    required this.lightMinutes,
    required this.deepMinutes,
    required this.awakeMinutes,
    this.remMinutes = 0,
  });

  final int lightMinutes;
  final int deepMinutes;
  final int awakeMinutes;

  /// REM（快速眼动）时长；协议 mode 4。
  final int remMinutes;

  int get totalMinutes => lightMinutes + deepMinutes + remMinutes;
}

/// 按状态切换点估算各阶段时长（对齐协议：1 浅睡 / 2 深睡 / 3 退出）。
JwSleepDaySummary _summarizeSleepMinutes(List<Object> records) {
  final events = <JWSleep>[
    for (final row in records)
      if (row is JWSleep) row,
  ]..sort((a, b) => a.time.compareTo(b.time));
  if (events.length < 2) {
    return const JwSleepDaySummary(
      lightMinutes: 0,
      deepMinutes: 0,
      awakeMinutes: 0,
      remMinutes: 0,
    );
  }
  var light = 0;
  var deep = 0;
  var awake = 0;
  var rem = 0;
  for (var i = 0; i < events.length - 1; i++) {
    final cur = events[i];
    final next = events[i + 1];
    final minutes = next.time.difference(cur.time).inMinutes;
    if (minutes <= 0) continue;
    switch (cur.mode) {
      case 1:
        light += minutes;
      case 2:
        deep += minutes;
      case 3:
        awake += minutes;
      case 4:
        rem += minutes;
      default:
        break;
    }
  }
  return JwSleepDaySummary(
    lightMinutes: light,
    deepMinutes: deep,
    awakeMinutes: awake,
    remMinutes: rem,
  );
}

JwSleepDaySummary jwDataSummarizeSleep(List<Object> records) =>
    _summarizeSleepMinutes(records);
