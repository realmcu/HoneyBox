import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_data_units.dart';

String jwHistoryRecordSummary(Object record) {
  return switch (record) {
    JWActivity r =>
      '${r.time.toIso8601String()} · 步数 ${r.steps} · '
          '${jwDataFormatKm(r.distance)} km · ${jwDataFormatKcal(r.energy)} kcal',
    JWSleep r =>
      '${r.time.toIso8601String()} · ${jwDataSleepModeLabel(r.mode)}',
    JWHeartRate r =>
      '${r.time.toIso8601String()} · 心率 ${r.heartRate} bpm',
    JWTemperature r =>
      '${r.time.toIso8601String()} · 皮温 ${r.skinTemperature} ℃ · 热应激 ${r.heatStress}',
    JWBloodPressure r =>
      '${r.time.toIso8601String()} · ${r.systolic}/${r.diastolic} mmHg',
    JWBloodOxygen r =>
      '${r.time.toIso8601String()} · SpO₂ ${r.value}%'
          '${r.high != null ? ' (${r.low}-${r.high})' : ''}',
    JWHrv r => '${r.time.toIso8601String()} · SDNN ${r.sdnn} ms',
    JWPressure r => '${r.time.toIso8601String()} · 压力 ${r.value}',
    JWBloodGlucose r =>
      '${r.time.toIso8601String()} · ${jwDataFormatMmol(r.value)} mmol/L',
    JWSport r =>
      '${r.time.toIso8601String()} · ${jwDataSportModeLabel(r.mode)} · '
          '${jwDataFormatDuration(r.duration)} · 步 ${r.steps}',
    _ => record.runtimeType.toString(),
  };
}

Map<String, Object?> jwHistoryRecordFields(Object record) {
  return switch (record) {
    JWActivity r => {
        'time': r.time.toIso8601String(),
        'steps': r.steps,
        'distanceMeters': r.distance,
        'distanceKm': jwDataMetersToKm(r.distance),
        'energyCal': r.energy,
        'energyKcal': jwDataCalToKcal(r.energy),
        'activeTime': r.activeTime,
        'mode': r.mode,
      },
    JWSleep r => {
        'time': r.time.toIso8601String(),
        'mode': r.mode,
        'modeLabel': jwDataSleepModeLabel(r.mode),
      },
    JWHeartRate r => {
        'time': r.time.toIso8601String(),
        'heartRate': r.heartRate,
      },
    JWTemperature r => {
        'time': r.time.toIso8601String(),
        'skinTemperature': r.skinTemperature,
        'heatStress': r.heatStress,
        'worn': r.worn,
        'compensated': r.compensated,
      },
    JWBloodPressure r => {
        'time': r.time.toIso8601String(),
        'systolic': r.systolic,
        'diastolic': r.diastolic,
      },
    JWBloodOxygen r => {
        'time': r.time.toIso8601String(),
        'value': r.value,
        'high': r.high,
        'low': r.low,
      },
    JWHrv r => {
        'time': r.time.toIso8601String(),
        'sdnn': r.sdnn,
      },
    JWPressure r => {
        'time': r.time.toIso8601String(),
        'value': r.value,
      },
    JWSport r => {
        'time': r.time.toIso8601String(),
        'mode': r.mode,
        'modeLabel': jwDataSportModeLabel(r.mode),
        'duration': r.duration,
        'pauseCount': r.pauseCount,
        'pauseDuration': r.pauseDuration,
        'steps': r.steps,
        'distance': r.distance,
        'energy': r.energy,
        'heartRateMax': r.heartRateMax,
        'heartRateAverage': r.heartRateAverage,
        'heartRateMin': r.heartRateMin,
      },
    _ => {'runtimeType': record.runtimeType.toString()},
  };
}
