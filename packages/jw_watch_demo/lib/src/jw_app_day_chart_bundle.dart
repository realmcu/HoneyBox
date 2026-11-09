import 'jw_app_chart_models.dart';
import 'jw_data_catalog.dart';

/// 单日图表建模结果，供详情页与数据首页共用。
final class JwAppDayChartBundle {
  const JwAppDayChartBundle._({
    required this.id,
    this.stepSlots = const [],
    this.stepMax = 1000,
    this.hrHours = const [],
    this.hrAxisMax = 120,
    this.hrAxisMin = 50,
    this.hrAvg = 0,
    this.sleepSegments = const [],
    this.bpHours = const [],
    this.bpAxisMax = 120,
    this.bpAxisMin = 30,
    this.spo2Hours = const [],
    this.spo2AxisMax = 100,
    this.spo2AxisMin = 85,
    this.tempSlots = const [],
    this.tempAxisMax = 37.5,
    this.tempAxisMin = 35.0,
    this.tempAvg = 0,
    this.hrvHours = const [],
    this.pressureSlots = const [],
    this.pressureAxisMax = 100,
    this.pressureAvg = 0,
    this.gluHours = const [],
    this.gluAxisMax = 7.0,
    this.gluAxisMin = 3.0,
    this.gluAvg = 0,
    this.sportBars = const [],
  });

  final JwDataTypeId id;
  final List<JwAppStepSlot> stepSlots;
  final int stepMax;
  final List<JwAppHrHourBucket> hrHours;
  final int hrAxisMax;
  final int hrAxisMin;
  final double hrAvg;
  final List<JwAppSleepSegment> sleepSegments;
  final List<JwAppBpHourBucket> bpHours;
  final int bpAxisMax;
  final int bpAxisMin;
  final List<JwAppSpo2HourBucket> spo2Hours;
  final int spo2AxisMax;
  final int spo2AxisMin;
  final List<JwAppTempSlot> tempSlots;
  final double tempAxisMax;
  final double tempAxisMin;
  final double tempAvg;
  final List<JwAppHrvHourBucket> hrvHours;
  final List<JwAppPressureSlot> pressureSlots;
  final int pressureAxisMax;
  final int pressureAvg;
  final List<JwAppGluHourBucket> gluHours;
  final double gluAxisMax;
  final double gluAxisMin;
  final double gluAvg;
  final List<JwAppSportHourBar> sportBars;

  static JwAppDayChartBundle build({
    required JwDataTypeId id,
    required List<Object> rows,
    required DateTime day,
  }) {
    switch (id) {
      case JwDataTypeId.activity:
        final slots = jwAppBuildStepSlots(rows, day);
        return JwAppDayChartBundle._(
          id: id,
          stepSlots: slots,
          stepMax: jwAppStepMaxAxis(slots),
        );
      case JwDataTypeId.heartRate:
        final hours = jwAppBuildHrHours(rows, day);
        final axis = jwAppHrAxis(hours);
        return JwAppDayChartBundle._(
          id: id,
          hrHours: hours,
          hrAxisMax: axis.max,
          hrAxisMin: axis.min,
          hrAvg: axis.avg,
        );
      case JwDataTypeId.sleep:
        return JwAppDayChartBundle._(
          id: id,
          sleepSegments: jwAppBuildSleepSegments(rows),
        );
      case JwDataTypeId.bloodPressure:
        final bpHours = jwAppBuildBpHours(rows, day);
        final bp = jwAppBpAxis(bpHours);
        return JwAppDayChartBundle._(
          id: id,
          bpHours: bpHours,
          bpAxisMax: bp.max,
          bpAxisMin: bp.min,
        );
      case JwDataTypeId.bloodOxygen:
        final spo2Hours = jwAppBuildSpo2Hours(rows, day);
        final spo2 = jwAppSpo2Axis(spo2Hours);
        return JwAppDayChartBundle._(
          id: id,
          spo2Hours: spo2Hours,
          spo2AxisMax: spo2.max,
          spo2AxisMin: spo2.min,
        );
      case JwDataTypeId.temperature:
        final tempSlots = jwAppBuildTempSlots(rows, day);
        final t = jwAppTempAxis(tempSlots);
        return JwAppDayChartBundle._(
          id: id,
          tempSlots: tempSlots,
          tempAxisMax: t.max,
          tempAxisMin: t.min,
          tempAvg: t.avg,
        );
      case JwDataTypeId.hrv:
        return JwAppDayChartBundle._(
          id: id,
          hrvHours: jwAppBuildHrvHours(rows, day),
        );
      case JwDataTypeId.pressure:
        final pressureSlots = jwAppBuildPressureSlots(rows, day);
        final p = jwAppPressureAxis(pressureSlots);
        return JwAppDayChartBundle._(
          id: id,
          pressureSlots: pressureSlots,
          pressureAxisMax: p.axisMax,
          pressureAvg: p.avg,
        );
      case JwDataTypeId.bloodSugar:
        final gluHours = jwAppBuildGluHours(rows, day);
        final g = jwAppGluAxis(gluHours);
        return JwAppDayChartBundle._(
          id: id,
          gluHours: gluHours,
          gluAxisMax: g.max,
          gluAxisMin: g.min,
          gluAvg: g.avg,
        );
      case JwDataTypeId.sport:
        return JwAppDayChartBundle._(
          id: id,
          sportBars: jwAppBuildSportHours(rows, day),
        );
    }
  }
}
