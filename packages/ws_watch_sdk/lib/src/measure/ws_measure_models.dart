/// 0x02 健康监测「自动监测」7 字节载荷（开关 + 时段 + 间隔分钟，大端）。
final class WSAutoMeasureSchedule {
  const WSAutoMeasureSchedule({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.intervalMinutes,
  });

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;

  bool get isAllDay =>
      startHour == endHour && startMinute == endMinute;

  /// Demo 简化模型：全天 + 间隔。
  factory WSAutoMeasureSchedule.fromSimple({
    required bool enabled,
    required int intervalMinutes,
  }) =>
      WSAutoMeasureSchedule(
        enabled: enabled,
        startHour: 0,
        startMinute: 0,
        endHour: 0,
        endMinute: 0,
        intervalMinutes: intervalMinutes,
      );

  WSAutoMeasureSchedule copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? intervalMinutes,
  }) =>
      WSAutoMeasureSchedule(
        enabled: enabled ?? this.enabled,
        startHour: startHour ?? this.startHour,
        startMinute: startMinute ?? this.startMinute,
        endHour: endHour ?? this.endHour,
        endMinute: endMinute ?? this.endMinute,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      );
}

/// 与 Demo/JW 对齐的自动监测配置（默认全天时段）。
final class WSAutoMeasureConfig {
  const WSAutoMeasureConfig({
    required this.enabled,
    required this.intervalMinutes,
  });

  final bool enabled;
  final int intervalMinutes;

  WSAutoMeasureSchedule toSchedule() =>
      WSAutoMeasureSchedule.fromSimple(
        enabled: enabled,
        intervalMinutes: intervalMinutes,
      );

  factory WSAutoMeasureConfig.fromSchedule(WSAutoMeasureSchedule schedule) =>
      WSAutoMeasureConfig(
        enabled: schedule.enabled,
        intervalMinutes: schedule.intervalMinutes,
      );
}

final class WSBloodSugarAutoMeasureConfig {
  const WSBloodSugarAutoMeasureConfig({
    required this.enabled,
    required this.intervalMinutes,
  });

  final bool enabled;
  final int intervalMinutes;

  WSAutoMeasureSchedule toSchedule() =>
      WSAutoMeasureSchedule.fromSimple(
        enabled: enabled,
        intervalMinutes: intervalMinutes,
      );

  factory WSBloodSugarAutoMeasureConfig.fromSchedule(
    WSAutoMeasureSchedule schedule,
  ) =>
      WSBloodSugarAutoMeasureConfig(
        enabled: schedule.enabled,
        intervalMinutes: schedule.intervalMinutes,
      );
}

/// 体温自动监测 + 手表显示单位（0x58 + 0x5A）。
final class WSTemperatureControlSetting {
  const WSTemperatureControlSetting({
    required this.enabled,
    required this.adjust,
    required this.celsius,
  });

  final bool enabled;

  /// 协议未单独定义「校准」位；Sim 状态保留供 Demo 展示。
  final bool adjust;
  final bool celsius;
}

/// 心率过高告警（0x41 告警块中的「过高」项）。
final class WSHeartRateHighAlarm {
  const WSHeartRateHighAlarm({
    required this.enabled,
    required this.thresholdBpm,
  });

  final bool enabled;
  final int thresholdBpm;
}

/// 血氧过低告警（0x51 告警块中的「过低」项）。
final class WSSpO2LowAlarm {
  const WSSpO2LowAlarm({
    required this.enabled,
    required this.thresholdPercent,
  });

  final bool enabled;
  final int thresholdPercent;
}
