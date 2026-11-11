import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_data_catalog.dart';
import 'ws_demo_controller.dart';
import 'compat/ws_demo_compat.dart';

enum WSMeasureModuleKind {
  heartRate,
  bloodOxygen,
  bloodPressure,
  temperature,
  bloodGlucose,
  pressure;

  static List<WSMeasureModuleKind> visibleModules(WSDemoController controller) {
    return values.where((k) => k.visible(controller)).toList(growable: false);
  }
}

extension WSMeasureModuleKindX on WSMeasureModuleKind {
  String get title => switch (this) {
        WSMeasureModuleKind.heartRate => '心率',
        WSMeasureModuleKind.bloodOxygen => '血氧',
        WSMeasureModuleKind.bloodPressure => '血压',
        WSMeasureModuleKind.temperature => '体温',
        WSMeasureModuleKind.bloodGlucose => '血糖',
        WSMeasureModuleKind.pressure => '压力',
      };

  IconData get icon => switch (this) {
        WSMeasureModuleKind.heartRate => Icons.favorite_rounded,
        WSMeasureModuleKind.bloodOxygen => Icons.water_drop_outlined,
        WSMeasureModuleKind.bloodPressure => Icons.monitor_heart_outlined,
        WSMeasureModuleKind.temperature => Icons.thermostat_outlined,
        WSMeasureModuleKind.bloodGlucose => Icons.bloodtype_outlined,
        WSMeasureModuleKind.pressure => Icons.self_improvement_outlined,
      };

  Key get hubTileKey => Key('jw.demo.measure.module.$name');

  Key get detailPageKey => Key('jw.demo.measure.detail.$name');

  bool visible(WSDemoController controller) {
    final info = controller.functionInfo;
    if (info == null) return false;
    return switch (this) {
      WSMeasureModuleKind.heartRate =>
        info.supports(WSDeviceFunction.rate),
      WSMeasureModuleKind.bloodOxygen =>
        info.supports(WSDeviceFunction.spo2Measure) ||
            info.supports(WSDeviceFunction.spo2Continuous),
      WSMeasureModuleKind.bloodPressure =>
        info.supports(WSDeviceFunction.bpDetection) ||
            info.supports(WSDeviceFunction.rtkBp3),
      WSMeasureModuleKind.temperature =>
        info.supports(WSDeviceFunction.temperature),
      WSMeasureModuleKind.bloodGlucose =>
        info.supports(WSDeviceFunction.bloodSugar),
      WSMeasureModuleKind.pressure =>
        info.supports(WSDeviceFunction.pressure),
    };
  }

  bool autoMonitorAvailable(WSDeviceFunctionInfo? info) {
    if (info == null) return false;
    return switch (this) {
      WSMeasureModuleKind.heartRate => info.supports(WSDeviceFunction.rate),
      WSMeasureModuleKind.bloodOxygen =>
        info.supports(WSDeviceFunction.spo2Continuous),
      WSMeasureModuleKind.bloodPressure =>
        info.supports(WSDeviceFunction.rtkBp3),
      WSMeasureModuleKind.bloodGlucose =>
        info.supports(WSDeviceFunction.bloodSugar),
      WSMeasureModuleKind.temperature =>
        info.supports(WSDeviceFunction.temperature),
      WSMeasureModuleKind.pressure => info.supports(WSDeviceFunction.pressure),
    };
  }

  bool get supportsSpotMeasure => switch (this) {
        WSMeasureModuleKind.pressure => false,
        _ => true,
      };

  bool get spotHasCheck => switch (this) {
        WSMeasureModuleKind.bloodOxygen ||
        WSMeasureModuleKind.temperature =>
          true,
        _ => false,
      };

  String get autoMonitorLabel => switch (this) {
        WSMeasureModuleKind.temperature => '手环显示体温',
        WSMeasureModuleKind.pressure => '压力自动监测',
        _ => '自动监测',
      };

  String get autoMonitorHint => switch (this) {
        WSMeasureModuleKind.heartRate =>
          '间隔由设备能力决定，常见为 1 / 5 / 10 / 30 / 60 分钟',
        WSMeasureModuleKind.bloodOxygen =>
          '进入页时会读取设备上的连续监测开关与间隔；下方间隔为读回值，不是 Demo 预设',
        WSMeasureModuleKind.bloodPressure =>
          '进入页时会读设备自动监测参数；间隔为读回值',
        WSMeasureModuleKind.bloodGlucose =>
          '进入页时会读设备自动监测参数；间隔为读回值',
        WSMeasureModuleKind.temperature =>
          '开启后手环界面展示体温；补偿与单位可在下方调整',
        WSMeasureModuleKind.pressure => '连续监测开关',
      };

  String spotUnitPlaceholder(WSDemoController controller) => switch (this) {
        WSMeasureModuleKind.heartRate => 'bpm',
        WSMeasureModuleKind.bloodOxygen => '%',
        WSMeasureModuleKind.bloodPressure => 'mmHg',
        WSMeasureModuleKind.temperature => '°C',
        WSMeasureModuleKind.bloodGlucose => 'mmol/L',
        WSMeasureModuleKind.pressure => '',
      };

  Color accentColor(ColorScheme scheme) => switch (this) {
        WSMeasureModuleKind.heartRate => scheme.error,
        WSMeasureModuleKind.bloodOxygen => scheme.primary,
        WSMeasureModuleKind.bloodPressure => scheme.tertiary,
        WSMeasureModuleKind.temperature => scheme.secondary,
        WSMeasureModuleKind.bloodGlucose => const Color(0xFF7B1FA2),
        WSMeasureModuleKind.pressure => scheme.primary,
      };

}

String jwMeasureModuleSubtitle(WSMeasureModuleKind kind, WSDemoController c) {
  final info = c.functionInfo;
  final parts = <String>[];
  if (kind.autoMonitorAvailable(info)) parts.add('自动监测');
  if (kind.supportsSpotMeasure) parts.add('点测');
  if (parts.isEmpty) return '设备能力';
  return parts.join(' · ');
}

/// 数据详情页可跳转的手动点测模块；无点测能力的类型返回 `null`。
WSMeasureModuleKind? jwSpotMeasureModuleForDataType(WsDataTypeId id) =>
    switch (id) {
      WsDataTypeId.heartRate => WSMeasureModuleKind.heartRate,
      WsDataTypeId.bloodOxygen => WSMeasureModuleKind.bloodOxygen,
      WsDataTypeId.bloodPressure => WSMeasureModuleKind.bloodPressure,
      WsDataTypeId.temperature => WSMeasureModuleKind.temperature,
      WsDataTypeId.bloodSugar => WSMeasureModuleKind.bloodGlucose,
      WsDataTypeId.pressure => WSMeasureModuleKind.pressure,
      _ => null,
    };

bool jwDataManualMeasureAvailable(
  WsDataTypeId id,
  WSDemoController controller,
) {
  final kind = jwSpotMeasureModuleForDataType(id);
  if (kind == null || !kind.supportsSpotMeasure) return false;
  return kind.visible(controller);
}

Key jwDataManualMeasureButtonKey(WsDataTypeId id) =>
    Key('jw.demo.data.detail.manual_measure.${id.name}');
