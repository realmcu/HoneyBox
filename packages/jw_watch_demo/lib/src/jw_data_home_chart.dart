import 'package:flutter/material.dart';

import 'jw_app_bp_touch_chart.dart';
import 'jw_app_chart_layout.dart';
import 'jw_app_day_chart_bundle.dart';
import 'jw_app_glu_touch_chart.dart';
import 'jw_app_hr_touch_chart.dart';
import 'jw_app_hrv_touch_chart.dart';
import 'jw_app_pressure_touch_chart.dart';
import 'jw_app_sleep_touch_chart.dart';
import 'jw_app_spo2_touch_chart.dart';
import 'jw_app_sport_day_chart.dart';
import 'jw_app_step_touch_chart.dart';
import 'jw_app_temp_touch_chart.dart';
import 'jw_data_catalog.dart';

/// 数据首页缩略图（固定高度、无 Y 轴、无长按）。
class JwDataHomeChart extends StatelessWidget {
  const JwDataHomeChart({
    super.key,
    required this.bundle,
  });

  final JwAppDayChartBundle bundle;

  static const _height = jwAppHomeChartHeight;
  static const _mode = JwAppChartMode.home;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: switch (bundle.id) {
        JwDataTypeId.activity => JwAppStepTouchChart(
            slots: bundle.stepSlots,
            maxSteps: bundle.stepMax,
            mode: _mode,
          ),
        JwDataTypeId.heartRate => JwAppHrTouchChart(
            hours: bundle.hrHours,
            axisMax: bundle.hrAxisMax,
            axisMin: bundle.hrAxisMin,
            averageRate: bundle.hrAvg,
            mode: _mode,
          ),
        JwDataTypeId.sleep => JwAppSleepTouchChart(
            segments: bundle.sleepSegments,
            mode: _mode,
          ),
        JwDataTypeId.bloodPressure => JwAppBpTouchChart(
            hours: bundle.bpHours,
            axisMax: bundle.bpAxisMax,
            axisMin: bundle.bpAxisMin,
            mode: _mode,
          ),
        JwDataTypeId.bloodOxygen => JwAppSpo2TouchChart(
            hours: bundle.spo2Hours,
            axisMax: bundle.spo2AxisMax,
            axisMin: bundle.spo2AxisMin,
            mode: _mode,
          ),
        JwDataTypeId.temperature => JwAppTempTouchChart(
            slots: bundle.tempSlots,
            axisMax: bundle.tempAxisMax,
            axisMin: bundle.tempAxisMin,
            averageRate: bundle.tempAvg,
            mode: _mode,
          ),
        JwDataTypeId.hrv => JwAppHrvTouchChart(
            hours: bundle.hrvHours,
            mode: _mode,
          ),
        JwDataTypeId.pressure => JwAppPressureTouchChart(
            slots: bundle.pressureSlots,
            axisMax: bundle.pressureAxisMax,
            axisMin: 0,
            averageRate: bundle.pressureAvg,
            mode: _mode,
          ),
        JwDataTypeId.bloodSugar => JwAppGluTouchChart(
            hours: bundle.gluHours,
            axisMax: bundle.gluAxisMax,
            axisMin: bundle.gluAxisMin,
            averageRate: bundle.gluAvg,
            mode: _mode,
          ),
        JwDataTypeId.sport => JwAppSportDayChart(
            bars: bundle.sportBars,
            mode: _mode,
          ),
      },
    );
  }
}
