import 'dart:typed_data';
import '../../services/jw/jw_configuration.dart';
import '../../services/jw/jw_models.dart';
import '../../services/jw/jw_remaining_models.dart';

class JwConsoleParameters {
  final Map<String, String> values;
  const JwConsoleParameters(this.values);
  int integer(String key, int min, int max) {
    final n = int.tryParse(values[key]?.trim() ?? '');
    if (n == null || n < min || n > max) {
      throw FormatException('$key 必须为 $min–$max 的整数');
    }
    return n;
  }

  bool flag(String key) => integer(key, 0, 1) == 1;
  double halfUnit(String key, double max) {
    final n = double.tryParse(values[key]?.trim() ?? '');
    if (n == null ||
        !n.isFinite ||
        n <= 0 ||
        n >= max ||
        n * 2 != (n * 2).round()) {
      throw FormatException('$key 必须在 0 与 $max 之间，精度为 0.5');
    }
    return n;
  }

  int? optional(String key, int max) =>
      (values[key]?.trim() ?? '').isEmpty ? null : integer(key, 1, max);
  JwConfigurationChange change(JwConfigurationDomain d) => d.isScalar
      ? JwConfigurationChange.scalar(
          d,
          integer(
              'value',
              d == JwConfigurationDomain.screenBrightness
                  ? 20
                  : d == JwConfigurationDomain.screenLightTime
                      ? 3
                      : 0,
              d == JwConfigurationDomain.screenBrightness
                  ? 100
                  : d == JwConfigurationDomain.screenLightTime
                      ? 30
                      : 1))
      : d.isMonitor
          ? JwConfigurationChange.monitor(d, flag('enabled'),
              bloodPressureDisplay: d == JwConfigurationDomain.bloodPressureAuto
                  ? flag('display')
                  : null)
          : JwConfigurationChange.temperature(
              displayEnabled: flag('display'),
              compensate: flag('compensate'),
              celsius: flag('celsius'));
  JwHeatStressReminderStatus heat() {
    final bits = (flag('enabled') ? 0x400000 : 0) |
        (integer('startHour', 0, 23) << 17) |
        (integer('startMinute', 0, 59) << 11) |
        (integer('endHour', 0, 23) << 6) |
        integer('endMinute', 0, 59);
    return JwHeatStressReminderStatus(
        Uint8List.fromList([bits >> 16, (bits >> 8) & 255, bits & 255]));
  }

  JwLongSitSettings longSit(JwLongSitSettings before) {
    final raw = before.raw.toList();
    final enabled = flag('enabled');
    int scheduleField(String name, int index, int max) {
      final value = int.tryParse(values[name]?.trim() ?? '');
      // Disabled firmware may retain invalid dormant time bytes. Only the
      // unchanged original byte is accepted; edits and enabling stay strict.
      if (!enabled && value == before.raw[index]) return value!;
      return integer(name, 0, max);
    }

    raw[1] = enabled ? 1 : 0;
    raw[2] = scheduleField('startMinute', 2, 59);
    raw[3] = scheduleField('endMinute', 3, 59);
    raw[4] = integer('interval', 0, 255);
    raw[5] = scheduleField('startHour', 5, 23);
    raw[6] = scheduleField('endHour', 6, 23);
    return JwLongSitSettings(raw);
  }

  JwAlarmRecord alarm({JwAlarmRecord? before}) {
    final text = values['date']?.trim() ?? '';
    final date = DateTime.tryParse(text);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        date == null ||
        date.year < 2000 ||
        date.year > 2063 ||
        date.toIso8601String().substring(0, 10) != text) {
      throw const FormatException('闹钟日期必须为合法的 YYYY-MM-DD（2000–2063）');
    }
    const mask = (63 << 34) |
        (15 << 30) |
        (31 << 25) |
        (31 << 20) |
        (63 << 14) |
        (7 << 11) |
        127;
    final bits = ((before?.packed ?? 0) & ~mask) |
        ((date.year - 2000) << 34) |
        (date.month << 30) |
        (date.day << 25) |
        (integer('hour', 0, 23) << 20) |
        (integer('minute', 0, 59) << 14) |
        (integer('id', 0, 7) << 11) |
        integer('repeat', 0, 127);
    return JwAlarmRecord(
        [for (var i = 4; i >= 0; i--) (bits >> (8 * i)) & 255]);
  }
}

String jwConsoleHex(List<int> raw) =>
    raw.map((n) => n.toRadixString(16).padLeft(2, '0')).join(' ');
String jwConsoleValue(Object? value) {
  if (value is JwConfigurationWriteResult) {
    return '原值：${jwConsoleValue(value.before)}\n请求值：${jwConsoleValue(value.requested)}\n读回值：${jwConsoleValue(value.observed)}\n独立读回一致';
  }
  if (value is JwVerifiedChange) {
    return '原值：${jwConsoleValue(value.before)}\n请求值：${jwConsoleValue(value.requested)}\n读回值：${jwConsoleValue(value.observed)}\n独立读回一致';
  }
  if (value is JwConfigurationValue) {
    final text = value.domain.isScalar
        ? '值=${value.scalarValue}${value.scalarDefault == null ? '' : '，固件默认=${value.scalarDefault}'}'
        : value.domain.isMonitor
            ? '开启=${value.enabled}${value.bloodPressureDisplay == null ? '' : '，血压显示=${value.bloodPressureDisplay}'}'
            : '显示=${value.displayEnabled}，补偿=${value.compensate}，摄氏=${value.celsius}';
    return '$text，raw=${jwConsoleHex(value.raw)}${value.companionRaw == null ? '' : '，companion=${jwConsoleHex(value.companionRaw!)}'}${value.writable ? '' : '；未知位 / 不可安全写入'}';
  }
  if (value is JwSubmission) {
    return '${value.acknowledged ? '收到 ACK，仅提交证据' : 'IAS 写入已返回，仅提交证据'}${value.responseRaw == null ? '' : '；模式回包=${jwConsoleHex(value.responseRaw!)}'}；${value.command.toRadixString(16)}/${value.key.toRadixString(16)} raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwUserInfoSubmission) {
    return '资料 / 目标：${value.submissions.length} 条命令收到 ACK；无独立读回，不能确认已应用。';
  }
  if (value is JwHealthStatus) {
    return '手动心率=${value.hrManualReported}，连续心率=${value.hrContinuousReported}，手动血压=${value.bpManualReported}，连续血压=${value.bpContinuousReported}，手动血氧=${value.spo2ManualReported}，连续血氧=${value.spo2ContinuousReported}，手动压力=${value.stressManualReported}，连续压力=${value.stressContinuousReported}，运动=${value.exerciseReported}，ECG=${value.ecgReported}；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwTurnOverWristStatus) {
    return '抬腕=${value.savedEnabled}；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwHeatStressReminderStatus) {
    return '时间过滤=${value.timeWindowEnabled}，${value.allDayAllowedByTimeGate ? '全天允许（不代表关闭提醒）' : '${_minutes(value.startMinutes)}–${_minutes(value.endMinutes)}'}；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwLongSitSettings) {
    return '开启=${value.enabled}，${value.hasValidSchedule ? '${value.startHour}:${value.startMinute}–${value.endHour}:${value.endMinute}，间隔=${value.intervalMinutes} 分钟' : '休眠时段无效：不能直接开启，需输入完整合法时分'}；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwAlarmTable) {
    return '闹钟 ${value.records.length}/20 条${value.roundTrippable ? '' : '；保留字段无法往返，编辑已锁定'}\n${[
      for (var i = 0; i < value.records.length; i++)
        '下标 $i：ID=${value.records[i].id} ${value.records[i].year}-${value.records[i].month}-${value.records[i].day} ${value.records[i].hour}:${value.records[i].minute} 星期掩码=${value.records[i].repeatDays} raw=${jwConsoleHex(value.records[i].raw)}'
    ].join('\n')}';
  }
  if (value is JwDisturbStatus) {
    return '勿扰 enabled=${value.enabled}，active=${value.active}，${_minutes(value.startMinutes)}–${_minutes(value.endMinutes)}；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwHeartRateReminderDiagnostic) {
    return '报告标志=${value.reportedFlag}，阈值=${value.threshold}；只读诊断；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwSpO2PermissionReport) {
    return '设备报告血氧可用=${value.availableReported}；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwSupportedSportTypes) {
    return '当前设备 UK 类型代码：${value.ukTypes.join(', ')}；raw=${jwConsoleHex(value.raw)}';
  }
  if (value is JwSportStatus) {
    return '运动结果码=${value.result}，状态码=${value.state}，UK 类型代码=${value.sportType}；${value.operationAccepted ? '设备接受命令' : '设备拒绝命令'}；raw=${jwConsoleHex(value.raw)}';
  }
  return value?.toString() ?? '命令已返回';
}

String _minutes(int n) =>
    '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
