import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_history_sync_state.dart';

/// Health categories exposed in the Demo UI (no SDK-internal count-only buckets).
const jwDemoHistorySyncCategories = <WSHistorySyncCategory>[
  WSHistorySyncCategory.activity,
  WSHistorySyncCategory.sleep,
  WSHistorySyncCategory.heartRate,
  WSHistorySyncCategory.temperature,
  WSHistorySyncCategory.bloodPressure,
  WSHistorySyncCategory.sport,
  WSHistorySyncCategory.bloodOxygen,
  WSHistorySyncCategory.hrv,
  WSHistorySyncCategory.pressure,
];

const jwHistorySyncCategoryLabels = <WSHistorySyncCategory, String>{
  WSHistorySyncCategory.activity: '活动 / 计步',
  WSHistorySyncCategory.sleep: '睡眠',
  WSHistorySyncCategory.heartRate: '心率',
  WSHistorySyncCategory.temperature: '体温',
  WSHistorySyncCategory.bloodPressure: '血压',
  WSHistorySyncCategory.sport: '运动',
  WSHistorySyncCategory.bloodOxygen: '血氧',
  WSHistorySyncCategory.hrv: 'HRV',
  WSHistorySyncCategory.pressure: '压力',
};

bool jwHistorySyncCategoryVisibleInDemo(WSHistorySyncCategory category) =>
    jwDemoHistorySyncCategories.contains(category);

String jwHistorySyncPhaseLabel(WsHistorySyncPhase phase) => switch (phase) {
      WsHistorySyncPhase.idle => '等待同步',
      WsHistorySyncPhase.syncing => '同步中',
      WsHistorySyncPhase.success => '同步完成',
      WsHistorySyncPhase.failed => '同步失败',
    };

String jwHistorySyncCategoryLabel(WSHistorySyncCategory category) =>
    jwHistorySyncCategoryLabels[category] ?? category.name;

int? jwDemoPlannedWireCount(
  WSHistorySyncPlan plan,
  WSHistorySyncCategory category,
) {
  if (category == WSHistorySyncCategory.temperature) {
    return null;
  }
  return plan.wireCountsByCategory[category];
}

String jwDemoCategoryPlanSubtitle({
  required WSHistorySyncCategory category,
  required int? planned,
  required int received,
  required int temperatureAttached,
}) {
  if (category == WSHistorySyncCategory.heartRate && temperatureAttached > 0) {
    final base = planned != null
        ? '计划 $planned · 已解析 $received'
        : '已解析 $received';
    return '$base · 附带体温 $temperatureAttached';
  }
  if (category == WSHistorySyncCategory.temperature) {
    return '附带 $received 条';
  }
  if (planned != null) {
    return '计划 $planned · 已解析 $received';
  }
  return '已解析 $received';
}

/// Primary parsed rows for sync summary (excludes temperature split from HR wire).
int jwDemoParsedRowTotal(Map<WSHistorySyncCategory, int> rows) {
  var total = 0;
  for (final category in jwDemoHistorySyncCategories) {
    if (category == WSHistorySyncCategory.temperature) continue;
    total += rows[category] ?? 0;
  }
  return total;
}

int jwDemoTemperatureParsedCount(Map<WSHistorySyncCategory, int> rows) =>
    rows[WSHistorySyncCategory.temperature] ?? 0;

String describeWsHistorySyncFailure(WSHistorySyncFailure failure) {
  return switch (failure.code) {
    WSErrorCode.historySyncIdleTimeout =>
      '超过 ${kWSHistorySyncIdleTimeout.inSeconds} 秒无同步进展，本轮同步已结束；若仍连接可重新发起。',
    WSErrorCode.transportDisconnected => '设备连接已断开，同步失败。',
    _ => failure.message.isNotEmpty
        ? failure.message
        : '同步失败，请查看连接状态后重试。',
  };
}
