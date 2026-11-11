import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_app_day_chart_bundle.dart';
import 'ws_data_home_presentation.dart';
import 'ws_data_units.dart';
import 'compat/ws_demo_compat.dart';

/// 数据 Tab 类型目录（对齐 App WatchData 卡片 + SDK 可查询类型）。
enum WsDataTypeId {
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

final class WsDataTypeItem {
  const WsDataTypeItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    required this.requiredFunctions,
    this.unitHint,
  });

  final WsDataTypeId id;
  final String title;
  final IconData icon;

  /// 对应同步分类（用于日志/调试对照）；部分类型仅本地表无独立 wire bucket。
  final WSHistorySyncCategory? category;

  /// 任一支持即视为设备支持；空列表表示不依赖能力位。
  final List<WSDeviceFunction> requiredFunctions;
  final String? unitHint;
}

final class WsDataHomeCardData {
  const WsDataHomeCardData({
    required this.presentation,
    required this.bundle,
  });

  final WsDataHomeCardPresentation presentation;
  final WsAppDayChartBundle bundle;
}

WsSleepDaySummary jwDataSummarizeSleepDay(List<Object> records) =>
    _summarizeSleepMinutes(records);

Future<WsDataHomeCardData> jwDataLoadHomeCard({
  required WSHistoryStore store,
  required WSHistoryScope scope,
  required WsDataTypeItem item,
  DateTime? day,
}) async {
  final targetDay = jwDataDayStart(day ?? DateTime.now());
  final dayRows = await jwDataQueryDay(
    store: store,
    scope: scope,
    id: item.id,
    day: targetDay,
  );
  final bundle = WsAppDayChartBundle.build(
    id: item.id,
    rows: dayRows,
    day: targetDay,
  );
  final presentation = await jwDataBuildHomePresentation(
    id: item.id,
    dayRows: dayRows,
    day: targetDay,
    store: store,
    scope: scope,
  );
  return WsDataHomeCardData(
    presentation: presentation,
    bundle: bundle,
  );
}

/// Demo 数据首页全量展示的类型列表。
List<WsDataTypeItem> jwDataCatalog() => const [
      WsDataTypeItem(
        id: WsDataTypeId.activity,
        title: '步数',
        icon: Icons.directions_walk_outlined,
        category: WSHistorySyncCategory.activity,
        requiredFunctions: [WSDeviceFunction.step],
        unitHint: '步',
      ),
      WsDataTypeItem(
        id: WsDataTypeId.sleep,
        title: '睡眠',
        icon: Icons.bedtime_outlined,
        category: WSHistorySyncCategory.sleep,
        requiredFunctions: [WSDeviceFunction.sleep],
      ),
      WsDataTypeItem(
        id: WsDataTypeId.heartRate,
        title: '心率',
        icon: Icons.favorite_outline,
        category: WSHistorySyncCategory.heartRate,
        requiredFunctions: [WSDeviceFunction.rate],
        unitHint: 'bpm',
      ),
      WsDataTypeItem(
        id: WsDataTypeId.bloodPressure,
        title: '血压',
        icon: Icons.monitor_heart_outlined,
        category: WSHistorySyncCategory.bloodPressure,
        requiredFunctions: [
          WSDeviceFunction.rtkBp3,
          WSDeviceFunction.bpDetection,
          WSDeviceFunction.bp2,
        ],
        unitHint: 'mmHg',
      ),
      WsDataTypeItem(
        id: WsDataTypeId.bloodOxygen,
        title: '血氧',
        icon: Icons.water_drop_outlined,
        category: WSHistorySyncCategory.bloodOxygen,
        requiredFunctions: [WSDeviceFunction.spo2Measure],
        unitHint: '%',
      ),
      WsDataTypeItem(
        id: WsDataTypeId.temperature,
        title: '体温',
        icon: Icons.thermostat_outlined,
        category: WSHistorySyncCategory.temperature,
        requiredFunctions: [WSDeviceFunction.temperature],
        unitHint: '℃',
      ),
      WsDataTypeItem(
        id: WsDataTypeId.hrv,
        title: 'HRV',
        icon: Icons.show_chart_outlined,
        category: WSHistorySyncCategory.hrv,
        requiredFunctions: [WSDeviceFunction.rtkHrv],
        unitHint: 'ms',
      ),
      WsDataTypeItem(
        id: WsDataTypeId.pressure,
        title: '压力',
        icon: Icons.spa_outlined,
        category: WSHistorySyncCategory.pressure,
        requiredFunctions: [WSDeviceFunction.pressure],
      ),
      WsDataTypeItem(
        id: WsDataTypeId.bloodSugar,
        title: '血糖',
        icon: Icons.bloodtype_outlined,
        category: null,
        requiredFunctions: [WSDeviceFunction.bloodSugar],
        unitHint: 'mmol/L',
      ),
      WsDataTypeItem(
        id: WsDataTypeId.sport,
        title: '运动',
        icon: Icons.fitness_center_outlined,
        category: WSHistorySyncCategory.sport,
        requiredFunctions: [
          WSDeviceFunction.multiSport,
          WSDeviceFunction.appSportRateDetect,
        ],
      ),
    ];

DateTime jwDataDayStart(DateTime day) =>
    DateTime(day.year, day.month, day.day);

DateTime jwDataDayEnd(DateTime day) =>
    jwDataDayStart(day).add(const Duration(days: 1, milliseconds: -1));

/// [WSHistoryQuery] 的 from/to 与库存时间均为 **Unix 毫秒**（见 [WSHistoryStore._wallTime]）。
int wsHistoryQueryMillis(DateTime time) => time.millisecondsSinceEpoch;

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
    WSActivity r => '${r.steps} 步',
    WSSleep r => jwDataSleepModeLabel(r.mode),
    WSHeartRate r => '${r.bpm} bpm',
    WSBloodPressure r => '${r.systolic}/${r.diastolic} mmHg',
    WSBloodOxygen r => '${r.value}%',
    WSTemperature r => '${r.skinTemperature.toStringAsFixed(1)} ℃',
    WSHrv r => 'SDNN ${r.sdnn} ms',
    WSPressure r => '${r.value}',
    WSBloodGlucose r => '${jwDataFormatMmol(r.value)} mmol/L',
    WSSport r =>
      '${jwDataSportModeLabel(r.mode)} · ${jwDataFormatDuration(r.duration)}',
    _ => '有数据',
  };
}

/// 列表副文案：时间 + 关键指标。
String jwDataRecordDetailLine(Object record) {
  final time = record is WSHistoryRecord
      ? jwDataFormatTime(record.time)
      : null;
  final body = switch (record) {
    WSActivity r =>
      '${r.steps} 步 · ${jwDataFormatKm(r.distance)} km · '
          '${jwDataFormatKcal(r.energy)} kcal',
    WSSleep r => jwDataSleepModeLabel(r.mode),
    WSHeartRate r => '${r.bpm} bpm',
    WSBloodPressure r => '${r.systolic}/${r.diastolic} mmHg',
    WSBloodOxygen r => r.high != null && r.low != null
        ? '${r.value}%（${r.low}-${r.high}）'
        : '${r.value}%',
    WSTemperature r =>
      '${r.skinTemperature.toStringAsFixed(1)} ℃'
          '${r.worn ? ' · 佩戴' : ''}',
    WSHrv r => 'SDNN ${r.sdnn} ms',
    WSPressure r => '压力 ${r.value}',
    WSBloodGlucose r => '${jwDataFormatMmol(r.value)} mmol/L',
    WSSport r =>
      '${jwDataSportModeLabel(r.mode)} · ${jwDataFormatDuration(r.duration)}'
          '${r.steps > 0 ? ' · ${r.steps} 步' : ''}'
          '${r.distance > 0 ? ' · ${jwDataFormatKm(r.distance)} km' : ''}',
    _ => record.runtimeType.toString(),
  };
  return time == null ? body : '$time · $body';
}

Future<Object?> jwDataQueryLatest({
  required WSHistoryStore store,
  required WSHistoryScope scope,
  required WsDataTypeId id,
}) async {
  final query = WSHistoryQuery(scope: scope, limit: 1, descending: true);
  final list = await jwDataQueryList(store: store, query: query, id: id);
  return list.isEmpty ? null : list.first;
}

Future<List<Object>> jwDataQueryDay({
  required WSHistoryStore store,
  required WSHistoryScope scope,
  required WsDataTypeId id,
  required DateTime day,
}) {
  final query = WSHistoryQuery(
    scope: scope,
    from: wsHistoryQueryMillis(jwDataDayStart(day)),
    to: wsHistoryQueryMillis(jwDataDayEnd(day)),
    limit: 2000,
    descending: false,
  );
  return jwDataQueryList(store: store, query: query, id: id);
}

/// 首页卡片摘要：步数用「当日合计」，其它优先当日最近一条，否则全局最近一条。
Future<String> jwDataQueryCardSummary({
  required WSHistoryStore store,
  required WSHistoryScope scope,
  required WsDataTypeId id,
  DateTime? day,
}) async {
  final targetDay = jwDataDayStart(day ?? DateTime.now());
  final dayRows = await jwDataQueryDay(
    store: store,
    scope: scope,
    id: id,
    day: targetDay,
  );

  if (id == WsDataTypeId.activity && dayRows.isNotEmpty) {
    var steps = 0;
    for (final row in dayRows) {
      if (row is WSActivity) steps += row.steps;
    }
    final label = jwDataFormatDay(targetDay);
    return '$label $steps 步';
  }

  if (id == WsDataTypeId.sleep && dayRows.isNotEmpty) {
    final sleep = _summarizeSleepMinutes(dayRows);
    if (sleep.totalMinutes > 0) {
      return '${jwDataFormatDay(targetDay)} '
          '${jwDataFormatDuration(sleep.totalMinutes * 60)}';
    }
  }

  if (id == WsDataTypeId.sport && dayRows.isNotEmpty) {
    var seconds = 0;
    for (final row in dayRows) {
      if (row is WSSport) seconds += row.duration;
    }
    return '${jwDataFormatDay(targetDay)} '
        '${dayRows.length} 次 · ${jwDataFormatDuration(seconds)}';
  }

  if (dayRows.isNotEmpty) {
    final latest = dayRows.last;
    final summary = jwDataLatestSummary(latest);
    final time = latest is WSHistoryRecord
        ? jwDataFormatTime(latest.time)
        : null;
    return time == null
        ? '${jwDataFormatDay(targetDay)} $summary'
        : '${jwDataFormatDay(targetDay)} $time · $summary';
  }

  final latest = await jwDataQueryLatest(store: store, scope: scope, id: id);
  if (latest == null) return '暂无数据';
  final time = latest is WSHistoryRecord ? latest.time : null;
  final summary = jwDataLatestSummary(latest);
  if (time == null) return summary;
  return '$summary · ${jwDataFormatDay(time)} ${jwDataFormatTime(time)}';
}

Future<List<Object>> jwDataQueryList({
  required WSHistoryStore store,
  required WSHistoryQuery query,
  required WsDataTypeId id,
}) async {
  switch (id) {
    case WsDataTypeId.activity:
      return store.queryActivities(query);
    case WsDataTypeId.sleep:
      return store.querySleeps(query);
    case WsDataTypeId.heartRate:
      return store.queryHeartRates(query);
    case WsDataTypeId.bloodPressure:
      return store.queryBloodPressures(query);
    case WsDataTypeId.bloodOxygen:
      return store.queryBloodOxygens(query);
    case WsDataTypeId.temperature:
      return store.queryTemperatures(query);
    case WsDataTypeId.hrv:
      return store.queryHrvs(query);
    case WsDataTypeId.pressure:
      return store.queryPressures(query);
    case WsDataTypeId.bloodSugar:
      return store.queryBloodGlucoses(query);
    case WsDataTypeId.sport:
      return store.querySports(query);
  }
}

final class WsSleepDaySummary {
  const WsSleepDaySummary({
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
WsSleepDaySummary _summarizeSleepMinutes(List<Object> records) {
  final events = <WSSleep>[
    for (final row in records)
      if (row is WSSleep) row,
  ]..sort((a, b) => a.time.compareTo(b.time));
  if (events.length < 2) {
    return const WsSleepDaySummary(
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
  return WsSleepDaySummary(
    lightMinutes: light,
    deepMinutes: deep,
    awakeMinutes: awake,
    remMinutes: rem,
  );
}

WsSleepDaySummary jwDataSummarizeSleep(List<Object> records) =>
    _summarizeSleepMinutes(records);
