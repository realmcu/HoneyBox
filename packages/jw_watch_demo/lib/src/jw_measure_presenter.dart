import 'package:jw_watch_sdk/jw_watch_sdk.dart';

String jwMeasureBatchSummary(String label, List<Object> batch) {
  if (batch.isEmpty) return '$label：空批次';
  final lines = batch.map(jwMeasureSampleLine).toList();
  return '$label ${batch.length} 条\n${lines.join('\n')}';
}

String jwMeasureSampleLine(Object sample) {
  return switch (sample) {
    JWHeartRate r =>
      '${_shortTime(r.time)} · 心率 ${r.heartRate} bpm',
    JWTemperature r =>
      '${_shortTime(r.time)} · 皮温 ${r.skinTemperature}°C'
      '${r.worn ? ' · 已佩戴' : ''}',
    JWBloodPressure r =>
      '${_shortTime(r.time)} · ${r.systolic}/${r.diastolic} mmHg',
    JWBloodOxygen r =>
      '${_shortTime(r.time)} · SpO₂ ${r.value}%'
      '${r.low != null && r.high != null ? ' (${r.low}-${r.high})' : ''}',
    JWBloodGlucose r =>
      '${_shortTime(r.time)} · 血糖 ${(r.value / 10).toStringAsFixed(1)} mmol/L',
    _ => sample.toString(),
  };
}

/// Compact value for spot-measure row subtitle.
String? jwMeasureSpotValueLabel(Object? sample) {
  if (sample == null) return null;
  return switch (sample) {
    JWHeartRate r => '${r.heartRate} bpm',
    JWTemperature r => '${r.skinTemperature}°C',
    JWBloodPressure r => '${r.systolic}/${r.diastolic} mmHg',
    JWBloodOxygen r => 'SpO₂ ${r.value}%',
    JWBloodGlucose r => '${(r.value / 10).toStringAsFixed(1)} mmol/L',
    _ => null,
  };
}

String _shortTime(DateTime time) {
  final local = time.toLocal();
  return '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
}

String jwAutoMeasureConfigLabel(JWAutoMeasureConfig config) =>
    '${config.enabled ? '开' : '关'} · 间隔 ${config.intervalMinutes} 分钟';

String jwBloodSugarAutoConfigLabel(JWBloodSugarAutoMeasureConfig config) =>
    '${config.enabled ? '开' : '关'}'
    '${config.intervalMinutes > 0 ? ' · 间隔 ${config.intervalMinutes} 分钟' : ''}';

String jwTemperatureControlLabel(JWTemperatureControlSetting setting) =>
    '${setting.enabled ? '显示' : '隐藏'} · '
    '${setting.adjust ? '补偿开' : '补偿关'} · '
    '${setting.celsius ? '摄氏' : '华氏'}';
