import 'ws_app_chart_models.dart';
import 'ws_data_catalog.dart';

/// 单日图表建模结果，供详情页与数据首页共用。
final class WsAppDayChartBundle {
  const WsAppDayChartBundle._({
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

  final WsDataTypeId id;
  final List<WsAppStepSlot> stepSlots;
  final int stepMax;
  final List<WsAppHrHourBucket> hrHours;
  final int hrAxisMax;
  final int hrAxisMin;
  final double hrAvg;
  final List<WsAppSleepSegment> sleepSegments;
  final List<WsAppBpHourBucket> bpHours;
  final int bpAxisMax;
  final int bpAxisMin;
  final List<WsAppSpo2HourBucket> spo2Hours;
  final int spo2AxisMax;
  final int spo2AxisMin;
  final List<WsAppTempSlot> tempSlots;
  final double tempAxisMax;
  final double tempAxisMin;
  final double tempAvg;
  final List<WsAppHrvHourBucket> hrvHours;
  final List<WsAppPressureSlot> pressureSlots;
  final int pressureAxisMax;
  final int pressureAvg;
  final List<WsAppGluHourBucket> gluHours;
  final double gluAxisMax;
  final double gluAxisMin;
  final double gluAvg;
  final List<WsAppSportHourBar> sportBars;

  static WsAppDayChartBundle build({
    required WsDataTypeId id,
    required List<Object> rows,
    required DateTime day,
  }) {
    switch (id) {
      case WsDataTypeId.activity:
        final slots = jwAppBuildStepSlots(rows, day);
        return WsAppDayChartBundle._(
          id: id,
          stepSlots: slots,
          stepMax: jwAppStepMaxAxis(slots),
        );
      case WsDataTypeId.heartRate:
        final hours = jwAppBuildHrHours(rows, day);
        final axis = jwAppHrAxis(hours);
        return WsAppDayChartBundle._(
          id: id,
          hrHours: hours,
          hrAxisMax: axis.max,
          hrAxisMin: axis.min,
          hrAvg: axis.avg,
        );
      case WsDataTypeId.sleep:
        return WsAppDayChartBundle._(
          id: id,
          sleepSegments: jwAppBuildSleepSegments(rows),
        );
      case WsDataTypeId.bloodPressure:
        final bpHours = jwAppBuildBpHours(rows, day);
        final bp = jwAppBpAxis(bpHours);
        return WsAppDayChartBundle._(
          id: id,
          bpHours: bpHours,
          bpAxisMax: bp.max,
          bpAxisMin: bp.min,
        );
      case WsDataTypeId.bloodOxygen:
        final spo2Hours = jwAppBuildSpo2Hours(rows, day);
        final spo2 = jwAppSpo2Axis(spo2Hours);
        return WsAppDayChartBundle._(
          id: id,
          spo2Hours: spo2Hours,
          spo2AxisMax: spo2.max,
          spo2AxisMin: spo2.min,
        );
      case WsDataTypeId.temperature:
        final tempSlots = jwAppBuildTempSlots(rows, day);
        final t = jwAppTempAxis(tempSlots);
        return WsAppDayChartBundle._(
          id: id,
          tempSlots: tempSlots,
          tempAxisMax: t.max,
          tempAxisMin: t.min,
          tempAvg: t.avg,
        );
      case WsDataTypeId.hrv:
        return WsAppDayChartBundle._(
          id: id,
          hrvHours: jwAppBuildHrvHours(rows, day),
        );
      case WsDataTypeId.pressure:
        final pressureSlots = jwAppBuildPressureSlots(rows, day);
        final p = jwAppPressureAxis(pressureSlots);
        return WsAppDayChartBundle._(
          id: id,
          pressureSlots: pressureSlots,
          pressureAxisMax: p.axisMax,
          pressureAvg: p.avg,
        );
      case WsDataTypeId.bloodSugar:
        final gluHours = jwAppBuildGluHours(rows, day);
        final g = jwAppGluAxis(gluHours);
        return WsAppDayChartBundle._(
          id: id,
          gluHours: gluHours,
          gluAxisMax: g.max,
          gluAxisMin: g.min,
          gluAvg: g.avg,
        );
      case WsDataTypeId.sport:
        return WsAppDayChartBundle._(
          id: id,
          sportBars: jwAppBuildSportHours(rows, day),
        );
    }
  }
}
