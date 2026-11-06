import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';

enum JWMeasureModuleKind {
  heartRate,
  bloodOxygen,
  bloodPressure,
  temperature,
  bloodGlucose,
  pressure;

  static List<JWMeasureModuleKind> visibleModules(JWDemoController controller) {
    return values.where((k) => k.visible(controller)).toList(growable: false);
  }
}

extension JWMeasureModuleKindX on JWMeasureModuleKind {
  String get title => switch (this) {
        JWMeasureModuleKind.heartRate => '心率',
        JWMeasureModuleKind.bloodOxygen => '血氧',
        JWMeasureModuleKind.bloodPressure => '血压',
        JWMeasureModuleKind.temperature => '体温',
        JWMeasureModuleKind.bloodGlucose => '血糖',
        JWMeasureModuleKind.pressure => '压力',
      };

  IconData get icon => switch (this) {
        JWMeasureModuleKind.heartRate => Icons.favorite_rounded,
        JWMeasureModuleKind.bloodOxygen => Icons.water_drop_outlined,
        JWMeasureModuleKind.bloodPressure => Icons.monitor_heart_outlined,
        JWMeasureModuleKind.temperature => Icons.thermostat_outlined,
        JWMeasureModuleKind.bloodGlucose => Icons.bloodtype_outlined,
        JWMeasureModuleKind.pressure => Icons.self_improvement_outlined,
      };

  Key get hubTileKey => Key('jw.demo.measure.module.$name');

  Key get detailPageKey => Key('jw.demo.measure.detail.$name');

  bool visible(JWDemoController controller) {
    final info = controller.state.functionInfo;
    if (info == null) return false;
    return switch (this) {
      JWMeasureModuleKind.heartRate =>
        info.supports(JWDeviceFunction.rate),
      JWMeasureModuleKind.bloodOxygen =>
        info.supports(JWDeviceFunction.spo2Measure) ||
            info.supports(JWDeviceFunction.spo2Continuous),
      JWMeasureModuleKind.bloodPressure =>
        info.supports(JWDeviceFunction.bpDetection) ||
            info.supports(JWDeviceFunction.rtkBp3),
      JWMeasureModuleKind.temperature =>
        info.supports(JWDeviceFunction.temperature),
      JWMeasureModuleKind.bloodGlucose =>
        info.supports(JWDeviceFunction.bloodSugar),
      JWMeasureModuleKind.pressure =>
        info.supports(JWDeviceFunction.pressure),
    };
  }

  bool autoMonitorAvailable(JWDeviceFunctionInfo? info) {
    if (info == null) return false;
    return switch (this) {
      JWMeasureModuleKind.heartRate => info.supports(JWDeviceFunction.rate),
      JWMeasureModuleKind.bloodOxygen =>
        info.supports(JWDeviceFunction.spo2Continuous),
      JWMeasureModuleKind.bloodPressure =>
        info.supports(JWDeviceFunction.rtkBp3),
      JWMeasureModuleKind.bloodGlucose =>
        info.supports(JWDeviceFunction.bloodSugar),
      JWMeasureModuleKind.temperature =>
        info.supports(JWDeviceFunction.temperature),
      JWMeasureModuleKind.pressure => info.supports(JWDeviceFunction.pressure),
    };
  }

  bool get supportsSpotMeasure => switch (this) {
        JWMeasureModuleKind.pressure => false,
        _ => true,
      };

  bool get spotHasCheck => switch (this) {
        JWMeasureModuleKind.bloodOxygen ||
        JWMeasureModuleKind.temperature =>
          true,
        _ => false,
      };

  String get autoMonitorLabel => switch (this) {
        JWMeasureModuleKind.temperature => '手环显示体温',
        JWMeasureModuleKind.pressure => '压力自动监测',
        _ => '自动监测',
      };

  String get autoMonitorHint => switch (this) {
        JWMeasureModuleKind.heartRate =>
          '间隔由设备能力决定，常见为 1 / 5 / 10 / 30 / 60 分钟',
        JWMeasureModuleKind.bloodOxygen =>
          '进入页时会读取设备上的连续监测开关与间隔；下方间隔为读回值，不是 Demo 预设',
        JWMeasureModuleKind.bloodPressure =>
          '进入页时会读设备自动监测参数；间隔为读回值',
        JWMeasureModuleKind.bloodGlucose =>
          '进入页时会读设备自动监测参数；间隔为读回值',
        JWMeasureModuleKind.temperature =>
          '开启后手环界面展示体温；补偿与单位可在下方调整',
        JWMeasureModuleKind.pressure => '连续监测开关',
      };

  String spotUnitPlaceholder(JWDemoController controller) => switch (this) {
        JWMeasureModuleKind.heartRate => 'bpm',
        JWMeasureModuleKind.bloodOxygen => '%',
        JWMeasureModuleKind.bloodPressure => 'mmHg',
        JWMeasureModuleKind.temperature => '°C',
        JWMeasureModuleKind.bloodGlucose => 'mmol/L',
        JWMeasureModuleKind.pressure => '',
      };

  Color accentColor(ColorScheme scheme) => switch (this) {
        JWMeasureModuleKind.heartRate => scheme.error,
        JWMeasureModuleKind.bloodOxygen => scheme.primary,
        JWMeasureModuleKind.bloodPressure => scheme.tertiary,
        JWMeasureModuleKind.temperature => scheme.secondary,
        JWMeasureModuleKind.bloodGlucose => const Color(0xFF7B1FA2),
        JWMeasureModuleKind.pressure => scheme.primary,
      };

}

String jwMeasureModuleSubtitle(JWMeasureModuleKind kind, JWDemoController c) {
  final info = c.state.functionInfo;
  final parts = <String>[];
  if (kind.autoMonitorAvailable(info)) parts.add('自动监测');
  if (kind.supportsSpotMeasure) parts.add('点测');
  if (parts.isEmpty) return '设备能力';
  return parts.join(' · ');
}
