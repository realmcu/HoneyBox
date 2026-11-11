import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_app_chart_models.dart';
import 'ws_data_catalog.dart';
import 'ws_data_units.dart';

/// App 首页图表模式文案（聚合在 Demo 层，只使用 SDK 按时间查记录）。
final class WsDataHomeCardPresentation {
  const WsDataHomeCardPresentation({
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

const _empty = WsDataHomeCardPresentation.emptyToken;

WsDataHomeCardPresentation jwDataHomePresentationFallback(WsDataTypeId id) {
  final hint = switch (id) {
    WsDataTypeId.activity => '暂无步数',
    WsDataTypeId.sleep => '暂无睡眠',
    WsDataTypeId.heartRate => '暂无心率',
    WsDataTypeId.bloodPressure => '暂无血压',
    WsDataTypeId.bloodOxygen => '暂无血氧',
    WsDataTypeId.temperature => '暂无体温',
    WsDataTypeId.hrv => '暂无HRV',
    WsDataTypeId.pressure => '暂无压力',
    WsDataTypeId.bloodSugar => '暂无血糖',
    WsDataTypeId.sport => '暂无运动',
  };
  final subtitle = switch (id) {
    WsDataTypeId.activity => '目标步数：8000',
    WsDataTypeId.temperature => '最近温度：$_empty',
    WsDataTypeId.heartRate => '最近心率：$_empty',
    WsDataTypeId.bloodPressure => '最近血压：$_empty',
    WsDataTypeId.bloodOxygen => '最近血氧：$_empty',
    WsDataTypeId.bloodSugar => '最近血糖：$_empty',
    WsDataTypeId.pressure => '最近压力：$_empty',
    WsDataTypeId.hrv => '最近 HRV：$_empty',
    WsDataTypeId.sport => '最近运动：$_empty',
    WsDataTypeId.sleep => '最近：$_empty',
  };
  return WsDataHomeCardPresentation(
    primaryValue: _empty,
    subtitleLine: subtitle,
    chartEmptyHint: hint,
  );
}

Future<WsDataHomeCardPresentation> jwDataBuildHomePresentation({
  required WsDataTypeId id,
  required List<Object> dayRows,
  required DateTime day,
  required WSHistoryStore store,
  required WSHistoryScope scope,
}) async {
  final latestGlobal = await jwDataQueryLatest(store: store, scope: scope, id: id);

  String recentOrEmpty(Object? latest, String Function(Object) format) {
    if (latest == null) return _empty;
    return format(latest);
  }

  switch (id) {
    case WsDataTypeId.activity:
      var steps = 0;
      for (final row in dayRows) {
        if (row is WSActivity) steps += row.steps;
      }
      const target = 8000;
      final percent = steps > 0 ? (steps * 100 / target).round().clamp(0, 999) : 0;
      return WsDataHomeCardPresentation(
        primaryValue: dayRows.isEmpty ? _empty : '$percent',
        primaryUnit: dayRows.isEmpty ? null : '%',
        subtitleLine: '目标步数：$target',
        chartEmptyHint: '暂无步数',
      );
    case WsDataTypeId.sleep:
      final sleep = jwDataSummarizeSleepDay(dayRows);
      final total = sleep.totalMinutes;
      final recent = dayRows.isNotEmpty
          ? jwDataFormatTime((dayRows.last as WSHistoryRecord).time)
          : (latestGlobal is WSHistoryRecord
              ? jwDataFormatTime(latestGlobal.time)
              : _empty);
      return WsDataHomeCardPresentation(
        primaryValue: total > 0 ? jwDataFormatDuration(total * 60) : _empty,
        subtitleLine: '最近：$recent',
        chartEmptyHint: '暂无睡眠',
      );
    case WsDataTypeId.heartRate:
      final hours = jwAppBuildHrHours(dayRows, day);
      final axis = jwAppHrAxis(hours);
      final recentHr = dayRows.whereType<WSHeartRate>().where((e) => e.bpm > 0);
      final recentVal = recentHr.isEmpty
          ? (latestGlobal is WSHeartRate && latestGlobal.bpm > 0
              ? '${latestGlobal.bpm}'
              : _empty)
          : '${recentHr.last.bpm}';
      return WsDataHomeCardPresentation(
        primaryValue: axis.avg > 0 ? '${axis.avg.round()}' : _empty,
        primaryUnit: axis.avg > 0 ? 'bpm' : null,
        subtitleLine: '最近心率：$recentVal${recentVal == _empty ? '' : ' bpm'}',
        chartEmptyHint: '暂无心率',
      );
    case WsDataTypeId.bloodPressure:
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
      final recent = dayRows.whereType<WSBloodPressure>().where(
            (e) => e.systolic > 0 && e.diastolic > 0,
          );
      final recentStr = recent.isEmpty
          ? recentOrEmpty(
              latestGlobal,
              (r) =>
                  '${(r as WSBloodPressure).systolic}/${r.diastolic}',
            )
          : '${recent.last.systolic}/${recent.last.diastolic}';
      return WsDataHomeCardPresentation(
        primaryValue: avgStr,
        primaryUnit: avgStr == _empty ? null : 'mmHg',
        subtitleLine: '最近血压：$recentStr${recentStr == _empty ? '' : ' mmHg'}',
        subtitleTrailing: '平均血压',
        chartEmptyHint: '暂无血压',
      );
    case WsDataTypeId.bloodOxygen:
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
      final recent = dayRows.whereType<WSBloodOxygen>().where((e) => e.value > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(latestGlobal, (r) => '${(r as WSBloodOxygen).value}')
          : '${recent.last.value}';
      return WsDataHomeCardPresentation(
        primaryValue: avg > 0 ? '$avg' : _empty,
        primaryUnit: avg > 0 ? '%' : null,
        subtitleLine: '最近血氧：$recentStr${recentStr == _empty ? '' : '%'}',
        subtitleTrailing: '平均血氧',
        chartEmptyHint: '暂无血氧',
      );
    case WsDataTypeId.temperature:
      final slots = jwAppBuildTempSlots(dayRows, day);
      final t = jwAppTempAxis(slots);
      final recent = dayRows.whereType<WSTemperature>().where(
            (e) => e.skinTemperature > 0,
          );
      final recentStr = recent.isEmpty
          ? recentOrEmpty(
              latestGlobal,
              (r) => (r as WSTemperature).skinTemperature.toStringAsFixed(1),
            )
          : recent.last.skinTemperature.toStringAsFixed(1);
      return WsDataHomeCardPresentation(
        primaryValue: t.avg > 0 ? t.avg.toStringAsFixed(1) : _empty,
        primaryUnit: t.avg > 0 ? '℃' : null,
        subtitleLine: '最近温度：$recentStr${recentStr == _empty ? '' : '℃'}',
        subtitleTrailing: '平均温度',
        chartEmptyHint: '暂无体温',
      );
    case WsDataTypeId.hrv:
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
      final recent = dayRows.whereType<WSHrv>().where((e) => e.sdnn > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(latestGlobal, (r) => '${(r as WSHrv).sdnn}')
          : '${recent.last.sdnn}';
      return WsDataHomeCardPresentation(
        primaryValue: avg > 0 ? '$avg' : _empty,
        primaryUnit: avg > 0 ? 'ms' : null,
        subtitleLine: '最近 HRV：$recentStr${recentStr == _empty ? '' : ' ms'}',
        subtitleTrailing: '平均',
        chartEmptyHint: '暂无HRV',
      );
    case WsDataTypeId.pressure:
      final slots = jwAppBuildPressureSlots(dayRows, day);
      final p = jwAppPressureAxis(slots);
      final recent = dayRows.whereType<WSPressure>().where((e) => e.value > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(latestGlobal, (r) => '${(r as WSPressure).value}')
          : '${recent.last.value}';
      return WsDataHomeCardPresentation(
        primaryValue: p.avg > 0 ? '${p.avg.round()}' : _empty,
        subtitleLine: '最近压力：$recentStr',
        subtitleTrailing: '最高',
        chartEmptyHint: '暂无压力',
      );
    case WsDataTypeId.bloodSugar:
      final g = jwAppGluAxis(jwAppBuildGluHours(dayRows, day));
      final recent = dayRows.whereType<WSBloodGlucose>().where((e) => e.value > 0);
      final recentStr = recent.isEmpty
          ? recentOrEmpty(
              latestGlobal,
              (r) => jwDataFormatMmol((r as WSBloodGlucose).value),
            )
          : jwDataFormatMmol(recent.last.value);
      return WsDataHomeCardPresentation(
        primaryValue:
            g.avg > 0 ? g.avg.toStringAsFixed(1) : _empty,
        primaryUnit: g.avg > 0 ? 'mmol/L' : null,
        subtitleLine: '最近血糖：$recentStr${recentStr == _empty ? '' : ' mmol/L'}',
        chartEmptyHint: '暂无血糖',
      );
    case WsDataTypeId.sport:
      var seconds = 0;
      for (final row in dayRows) {
        if (row is WSSport) seconds += row.duration;
      }
      final recent = dayRows.whereType<WSSport>().where((e) => e.duration > 0);
      final recentStr = recent.isEmpty
          ? _empty
          : jwDataFormatDuration(recent.last.duration);
      return WsDataHomeCardPresentation(
        primaryValue:
            seconds > 0 ? jwDataFormatDuration(seconds) : _empty,
        subtitleLine: '最近运动：$recentStr',
        chartEmptyHint: '暂无运动',
      );
  }
}
