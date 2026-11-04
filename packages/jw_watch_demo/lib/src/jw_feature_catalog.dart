import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

/// UI metadata belongs to the Demo; [JWFeature] remains SDK-facing and free of
/// routes, Flutter icons, document URLs, and implementation status.
class JWFeatureCatalogEntry {
  const JWFeatureCatalogEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.features,
    required this.example,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<JWFeature> features;
  final String example;
}

const jwFeatureCatalog = <JWFeatureCatalogEntry>[
  JWFeatureCatalogEntry(
    id: 'device',
    title: '设备信息与能力',
    subtitle: '型号、固件、电量、连接与支持能力',
    icon: Icons.watch_outlined,
    features: [JWFeature.connection, JWFeature.deviceInformation],
    example: '''final summary = watch.device.summary;
final support = watch.features.of(JWFeature.measurements);''',
  ),
  JWFeatureCatalogEntry(
    id: 'settings',
    title: '用户与设备设置',
    subtitle: '时间、语言、单位、显示与目标',
    icon: Icons.tune_outlined,
    features: [JWFeature.settings, JWFeature.reminders],
    example: '''await watch.settings.setLanguage(DeviceLanguage.zhHans);
await watch.settings.setUnitSystem(UnitSystem.metric);''',
  ),
  JWFeatureCatalogEntry(
    id: 'measurements',
    title: '健康测量与实时数据',
    subtitle: '心率、血压、血氧、体温与专项健康数据',
    icon: Icons.monitor_heart_outlined,
    features: [JWFeature.measurements, JWFeature.advancedHealth],
    example: '''await watch.measurements.startHeartRate();
final sample = await watch.measurements.heartRateResults.first;''',
  ),
  JWFeatureCatalogEntry(
    id: 'history',
    title: '数据同步与健康记录',
    subtitle: '同步进度、批次、本地查询与历史记录',
    icon: Icons.sync_outlined,
    features: [JWFeature.history],
    example: '''final run = watch.history.sync();
await for (final progress in run.progress) {
  // Update the UI.
}''',
  ),
  JWFeatureCatalogEntry(
    id: 'notifications',
    title: '通知、提醒与手机交互',
    subtitle: '来电、消息、闹钟、久坐与设备主动事件',
    icon: Icons.notifications_outlined,
    features: [JWFeature.notifications, JWFeature.reminders],
    example: '''await watch.notifications.sendCall(
  displayName: 'Alice',
);''',
  ),
  JWFeatureCatalogEntry(
    id: 'controls',
    title: '设备控制、定制与表盘',
    subtitle: '找设备、音乐、天气、自定义 UI 与样式',
    icon: Icons.tune_outlined,
    features: [JWFeature.controls],
    example: '''await watch.controls.setFindDevice(enabled: true);''',
  ),
  JWFeatureCatalogEntry(
    id: 'sport',
    title: '运动与专项健康能力',
    subtitle: '设备端运动状态、实时运动数据与专项能力',
    icon: Icons.directions_run_outlined,
    features: [JWFeature.sport, JWFeature.advancedHealth],
    example: '''await watch.sport.start(type: DeviceSportType.running);''',
  ),
];
