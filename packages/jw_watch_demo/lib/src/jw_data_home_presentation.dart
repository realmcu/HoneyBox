import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_app_chart_models.dart';
import 'jw_data_catalog.dart';
import 'jw_data_units.dart';

/// App 首页图表模式文案（聚合在 Demo 层，只使用 SDK 按时间查记录）。
final class JwDataHomeCardPresentation {
  const JwDataHomeCardPresentation({
    required this.primaryValue,
    this.primaryUnit,
    required this.subtitleLine,
    this.subtitleTrailing,
    required this.chartEmptyHint,
  });

  /// 右上主数值；无数据时为「无」。
  final String primaryValue;
  final String? primaryUnit;

  /// 标题下副文案，如「最近温度：27」/「最近温度：无」。
  final String subtitleLine;

  /// 副行右侧标签，如体温「平均温度」、步数无此项。
  final String? subtitleTrailing;

  /// 图表区空态，对齐详情「暂无 XX」。
  final String chartEmptyHint;

  static const emptyToken = '无';
}

const _empty = JwDataHomeCardPresentation.emptyToken;

JwDataHomeCardPresentation jwDataHomePresentationFallback(JwDataTypeId id) {
  final hint = switch (id) {
    JwDataTypeId.activity => '暂无步数',
    JwDataTypeId.sleep => '暂无睡眠',
    JwDataTypeId.heartRate => '暂无心率',
    JwDataTypeId.bloodPressure => '暂无血压',
    JwDataTypeId.bloodOxygen => '暂无血氧',
    JwDataTypeId.temperature => '暂无体温',
    JwDataTypeId.hrv => '暂无HRV',
    JwDataTypeId.pressure => '暂无压力',
    JwDataTypeId.bloodSugar => '暂无血糖',
    JwDataTypeId.sport => '暂无运动',
  };
  final subtitle = switch (id) {
    JwDataTypeId.activity => '目标步数：8000',
    JwDataTypeId.temperature => '最近温度：$_empty',
    JwDataTypeId.heartRate => '最近心率：$_empty',
    JwDataTypeId.bloodPressure => '最近血压：$_empty',
    JwDataTypeId.bloodOxygen => '最近血氧：$_empty',
    JwDataTypeId.bloodSugar => '最近血糖：$_empty',
    JwDataTypeId.pressure => '最近压力：$_empty',
    JwDataTypeId.hrv => '最近 HRV：$_empty',
    JwDataTypeId.sport => '最近运动：$_empty',
    JwDataTypeId.sleep => '最近：$_empty',
  };
  return JwDataHomeCardPresentation(
    primaryValue: _empty,
    subtitleLine: subtitle,
    chartEmptyHint: hint,
  );
}

Future<JwDataHomeCardPresentation> jwDataBuildHomePresentation({
  required JwDataTypeId id,
  required List<Object> dayRows,
  required DateTime day,
  required JWHistoryStore store,
  required JWHistoryScope scope,
}) async {
  final latestGlobal = await jwDataQueryLatest(store: store, scope: scope, id: id);

  String recentOrEmpty(Object? latest, String Function(Object) format) {
    if (latest == null) return _empty;
    return format(latest);
  }

  switch (id) {
    case JwDataTypeId.activity:
      var steps = 0;
      for (final row in dayRows) {
        if (row is JWActivity) steps += row.steps;
      }
      const target = 8000;
      final percent = steps > 0 ? (steps * 100 / target).round().clamp(0, 999) : 0;
      return JwDataHomeCardPresentation(
        primaryValue: dayRows.isEmpty ? _empty : '$percent',
        primaryUnit: dayRows.isEmpty ? null : '%',
        subtitleLine: '目标步数：$target',
        chartEmptyHint: '暂无步数',
      );
    case JwDataTypeId.sleep:
      final sleep = jwDataSummarizeSleepDay(dayRows);
      final total = sleep.totalMinutes;
      final recent = dayRows.isNotEmpty
          ? jwDataFormatTime((dayRows.last as JWHistoryRecord).time)
          : (latestGlobal is JWHistoryRecord
              ? jwDataFormatTime(latestGlobal.time)
              : _empty);
      return JwDataHomeCardPresentation(
        primaryValue: total > 0 ? jwDataFormatDuration(total * 60) : _empty,
        subtitleLine: '最近：$recent',
        chartEmptyHint: '暂无睡眠',
      );
    case JwDataTypeId.heartRate:
      final hours = jwAppBuildHrHours(dayRows, day);
      final axis = jwAppHrAxis(hours);
      final recentHr = dayRows.whereType<JWHeartRate>().where((e) => e.heartRate > 0);
      final recentVal = recentHr.isEmpty
          ? (latestGlobal is JWHeartRate && latestGlobal.heartRate > 0
              ? '${latestGlobal.heartRate}'
              : _empty)
          : '${recentHr.last.heartRate}';
      return JwDataHomeCardPresentation(
        primaryValue: axis.avg > 0 ? '${axis.avg.round()}' : _empty,
        primaryUnit: axis.avg > 0 ? 'bpm' : null,
        subtitleLine: '最近心率：$recentVal${recentVal == _empty ? '' : ' bpm'}',
        chartEmptyHint: '暂无心率',
      );
    case JwDataTypeId.bloodPressure:
      final h = jwAppBuildBpHours(dayRows, day);
      var highSum = 0;
      var lowSum = 0;
      var n = 0;
      for (final b in h) {
        if (b.avgHigh > 0 && b.avgLow > 0) {
          highSum += b.avgHigh;
          lowSum += b.avgLow;
          n++;
        }
      }
      final avgStr = n > 0 ? '${(highSum / n).round()}/${(lowSum / n).round()}' : _empty;
      final recent = dayRows.whereType<JWBloodPressure>().where(
            (e) => e.systolic > 0 && e.diastolic > 0,
          );
      final recentStr = recent.isEmpty
          ? recentOrEmpty(
              latestGlobal,
              (r) =>
                  '${(r as JWBloodPressure).systolic}/${r.diastolic}',
            )
          : '${recent.last.systolic}/${recent.last.diastolic}';
      return JwDataHomeCardPresentation(
        primaryValue: avgStr,
        primaryUnit: avgStr == _empty ? null : 'mmHg',
        subtitleLine: '最近血压：$recentStr${recentStr == _empty ? '' : ' mmHg'}',
        subtitleTrailing: '平均血压',
        chartEmptyHint: '暂无血压',
      );
    case JwDataTypeId.bloodOxygen:
      final buckets = jwAppBuildSpo2Hours(dayRows, day);
      var sum = 0;
      var n = 0;
      for (final b in buckets) {
        if (b.values.isEmpty) continue;
        for (final v in b.values) {
          if (v > 0) {
            sum += v;
            n++;
          }
        }
      }
      final avg = n > 0 ? (sum / n).round() : 0;
      final recent = dayRows.whereType<JWBloodOxygen>().where((e) => e.value > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(latestGlobal, (r) => '${(r as JWBloodOxygen).value}')
          : '${recent.last.value}';
      return JwDataHomeCardPresentation(
        primaryValue: avg > 0 ? '$avg' : _empty,
        primaryUnit: avg > 0 ? '%' : null,
        subtitleLine: '最近血氧：$recentStr${recentStr == _empty ? '' : '%'}',
        subtitleTrailing: '平均血氧',
        chartEmptyHint: '暂无血氧',
      );
    case JwDataTypeId.temperature:
      final slots = jwAppBuildTempSlots(dayRows, day);
      final t = jwAppTempAxis(slots);
      final recent = dayRows.whereType<JWTemperature>().where(
            (e) => e.skinTemperature > 0,
          );
      final recentStr = recent.isEmpty
          ? recentOrEmpty(
              latestGlobal,
              (r) => (r as JWTemperature).skinTemperature.toStringAsFixed(1),
            )
          : recent.last.skinTemperature.toStringAsFixed(1);
      return JwDataHomeCardPresentation(
        primaryValue: t.avg > 0 ? t.avg.toStringAsFixed(1) : _empty,
        primaryUnit: t.avg > 0 ? '℃' : null,
        subtitleLine: '最近温度：$recentStr${recentStr == _empty ? '' : '℃'}',
        subtitleTrailing: '平均温度',
        chartEmptyHint: '暂无体温',
      );
    case JwDataTypeId.hrv:
      final hrv = jwAppBuildHrvHours(dayRows, day);
      var sum = 0;
      var n = 0;
      for (final b in hrv) {
        for (final v in b.values) {
          if (v > 0) {
            sum += v;
            n++;
          }
        }
      }
      final avg = n > 0 ? (sum / n).round() : 0;
      final recent = dayRows.whereType<JWHrv>().where((e) => e.sdnn > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(latestGlobal, (r) => '${(r as JWHrv).sdnn}')
          : '${recent.last.sdnn}';
      return JwDataHomeCardPresentation(
        primaryValue: avg > 0 ? '$avg' : _empty,
        primaryUnit: avg > 0 ? 'ms' : null,
        subtitleLine: '最近 HRV：$recentStr${recentStr == _empty ? '' : ' ms'}',
        subtitleTrailing: '平均',
        chartEmptyHint: '暂无HRV',
      );
    case JwDataTypeId.pressure:
      final slots = jwAppBuildPressureSlots(dayRows, day);
      final p = jwAppPressureAxis(slots);
      final recent = dayRows.whereType<JWPressure>().where((e) => e.value > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(latestGlobal, (r) => '${(r as JWPressure).value}')
          : '${recent.last.value}';
      return JwDataHomeCardPresentation(
        primaryValue: p.avg > 0 ? '${p.avg.round()}' : _empty,
        subtitleLine: '最近压力：$recentStr',
        subtitleTrailing: '最高',
        chartEmptyHint: '暂无压力',
      );
    case JwDataTypeId.bloodSugar:
      final g = jwAppGluAxis(jwAppBuildGluHours(dayRows, day));
      final recent = dayRows.whereType<JWBloodGlucose>().where((e) => e.value > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(
              latestGlobal,
              (r) => jwDataFormatMmol((r as JWBloodGlucose).value),
            )
          : jwDataFormatMmol(recent.last.value);
      return JwDataHomeCardPresentation(
        primaryValue:
            g.avg > 0 ? g.avg.toStringAsFixed(1) : _empty,
        primaryUnit: g.avg > 0 ? 'mmol/L' : null,
        subtitleLine: '最近血糖：$recentStr${recentStr == _empty ? '' : ' mmol/L'}',
        chartEmptyHint: '暂无血糖',
      );
    case JwDataTypeId.sport:
      var seconds = 0;
      for (final row in dayRows) {
        if (row is JWSport) seconds += row.duration;
      }
      final recent = dayRows.whereType<JWSport>().where((e) => e.duration > 0);
      final recentStr = recent.isEmpty
          ? _empty
          : jwDataFormatDuration(recent.last.duration);
      return JwDataHomeCardPresentation(
        primaryValue:
            seconds > 0 ? jwDataFormatDuration(seconds) : _empty,
        subtitleLine: '最近运动：$recentStr',
        chartEmptyHint: '暂无运动',
      );
  }
}
