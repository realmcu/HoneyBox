import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_history_sync_state.dart';

/// Health categories exposed in the Demo UI (no SDK-internal count-only buckets).
const jwDemoHistorySyncCategories = <JWHistorySyncCategory>[
  JWHistorySyncCategory.activity,
  JWHistorySyncCategory.sleep,
  JWHistorySyncCategory.heartRate,
  JWHistorySyncCategory.temperature,
  JWHistorySyncCategory.bloodPressure,
  JWHistorySyncCategory.sport,
  JWHistorySyncCategory.bloodOxygen,
  JWHistorySyncCategory.hrv,
  JWHistorySyncCategory.pressure,
];

const jwHistorySyncCategoryLabels = <JWHistorySyncCategory, String>{
  JWHistorySyncCategory.activity: '活动 / 计步',
  JWHistorySyncCategory.sleep: '睡眠',
  JWHistorySyncCategory.heartRate: '心率',
  JWHistorySyncCategory.temperature: '体温',
  JWHistorySyncCategory.bloodPressure: '血压',
  JWHistorySyncCategory.sport: '运动',
  JWHistorySyncCategory.bloodOxygen: '血氧',
  JWHistorySyncCategory.hrv: 'HRV',
  JWHistorySyncCategory.pressure: '压力',
};

bool jwHistorySyncCategoryVisibleInDemo(JWHistorySyncCategory category) =>
    jwDemoHistorySyncCategories.contains(category);

String jwHistorySyncPhaseLabel(JwHistorySyncPhase phase) => switch (phase) {
      JwHistorySyncPhase.idle => '等待同步',
      JwHistorySyncPhase.syncing => '同步中',
      JwHistorySyncPhase.success => '同步完成',
      JwHistorySyncPhase.failed => '同步失败',
    };

String jwHistorySyncCategoryLabel(JWHistorySyncCategory category) =>
    jwHistorySyncCategoryLabels[category] ?? category.name;

int? jwDemoPlannedWireCount(
  JWHistorySyncPlan plan,
  JWHistorySyncCategory category,
) {
  if (category == JWHistorySyncCategory.temperature) {
    return null;
  }
  return plan.wireCountsByCategory[category];
}

String jwDemoCategoryPlanSubtitle({
  required JWHistorySyncCategory category,
  required int? planned,
  required int received,
  required int temperatureAttached,
}) {
  if (category == JWHistorySyncCategory.heartRate && temperatureAttached > 0) {
    final base = planned != null
        ? '计划 $planned · 已解析 $received'
        : '已解析 $received';
    return '$base · 附带体温 $temperatureAttached';
  }
  if (category == JWHistorySyncCategory.temperature) {
    return '附带 $received 条';
  }
  if (planned != null) {
    return '计划 $planned · 已解析 $received';
  }
  return '已解析 $received';
}

/// Primary parsed rows for sync summary (excludes temperature split from HR wire).
int jwDemoParsedRowTotal(Map<JWHistorySyncCategory, int> rows) {
  var total = 0;
  for (final category in jwDemoHistorySyncCategories) {
    if (category == JWHistorySyncCategory.temperature) continue;
    total += rows[category] ?? 0;
  }
  return total;
}

int jwDemoTemperatureParsedCount(Map<JWHistorySyncCategory, int> rows) =>
    rows[JWHistorySyncCategory.temperature] ?? 0;

String describeJwHistorySyncFailure(JWHistorySyncFailure failure) {
  return switch (failure.code) {
    JWErrorCode.historySyncIdleTimeout =>
      '超过 10 秒未收到设备数据，本轮同步已结束；若仍连接可重新发起。',
    JWErrorCode.transportDisconnected => '设备连接已断开，同步失败。',
    _ => failure.message.isNotEmpty
        ? failure.message
        : '同步失败，请查看连接状态后重试。',
  };
}
