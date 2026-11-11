import 'package:flutter/material.dart';

import 'ws_app_bp_touch_chart.dart';
import 'ws_app_chart_layout.dart';
import 'ws_app_day_chart_bundle.dart';
import 'ws_app_glu_touch_chart.dart';
import 'ws_app_hr_touch_chart.dart';
import 'ws_app_hrv_touch_chart.dart';
import 'ws_app_pressure_touch_chart.dart';
import 'ws_app_sleep_touch_chart.dart';
import 'ws_app_spo2_touch_chart.dart';
import 'ws_app_sport_day_chart.dart';
import 'ws_app_step_touch_chart.dart';
import 'ws_app_temp_touch_chart.dart';
import 'ws_data_catalog.dart';

/// 数据首页缩略图（固定高度、无 Y 轴、无长按）。
class WsDataHomeChart extends StatelessWidget {
  const WsDataHomeChart({
    super.key,
    required this.bundle,
  });

  final WsAppDayChartBundle bundle;

  static const _height = jwAppHomeChartHeight;
  static const _mode = WsAppChartMode.home;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: switch (bundle.id) {
        WsDataTypeId.activity => WsAppStepTouchChart(
            slots: bundle.stepSlots,
            maxSteps: bundle.stepMax,
            mode: _mode,
          ),
        WsDataTypeId.heartRate => WsAppHrTouchChart(
            hours: bundle.hrHours,
            axisMax: bundle.hrAxisMax,
            axisMin: bundle.hrAxisMin,
            averageRate: bundle.hrAvg,
            mode: _mode,
          ),
        WsDataTypeId.sleep => WsAppSleepTouchChart(
            segments: bundle.sleepSegments,
            mode: _mode,
          ),
        WsDataTypeId.bloodPressure => WsAppBpTouchChart(
            hours: bundle.bpHours,
            axisMax: bundle.bpAxisMax,
            axisMin: bundle.bpAxisMin,
            mode: _mode,
          ),
        WsDataTypeId.bloodOxygen => WsAppSpo2TouchChart(
            hours: bundle.spo2Hours,
            axisMax: bundle.spo2AxisMax,
            axisMin: bundle.spo2AxisMin,
            mode: _mode,
          ),
        WsDataTypeId.temperature => WsAppTempTouchChart(
            slots: bundle.tempSlots,
            axisMax: bundle.tempAxisMax,
            axisMin: bundle.tempAxisMin,
            averageRate: bundle.tempAvg,
            mode: _mode,
          ),
        WsDataTypeId.hrv => WsAppHrvTouchChart(
            hours: bundle.hrvHours,
            mode: _mode,
          ),
        WsDataTypeId.pressure => WsAppPressureTouchChart(
            slots: bundle.pressureSlots,
            axisMax: bundle.pressureAxisMax,
            axisMin: 0,
            averageRate: bundle.pressureAvg,
            mode: _mode,
          ),
        WsDataTypeId.bloodSugar => WsAppGluTouchChart(
            hours: bundle.gluHours,
            axisMax: bundle.gluAxisMax,
            axisMin: bundle.gluAxisMin,
            averageRate: bundle.gluAvg,
            mode: _mode,
          ),
        WsDataTypeId.sport => WsAppSportDayChart(
            bars: bundle.sportBars,
            mode: _mode,
          ),
      },
    );
  }
}
