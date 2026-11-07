import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_data_catalog.dart';
import 'jw_data_units.dart';
import 'jw_settings_app_theme.dart';

/// 详情页日汇总 + 简易图表（CustomPaint，对齐 App 日视图指标）。
final class JwDataDayStats {
  const JwDataDayStats({
    required this.primary,
    required this.secondary,
    required this.chart,
  });

  final String primary;
  final List<String> secondary;
  final Widget? chart;
}

JwDataDayStats? jwDataBuildDayStats({
  required JwDataTypeId id,
  required List<Object> records,
}) {
  if (records.isEmpty) return null;
  return switch (id) {
    JwDataTypeId.heartRate => _heartRateStats(records),
    JwDataTypeId.activity => _activityStats(records),
    JwDataTypeId.bloodOxygen => _scalarLineStats(
        records: records,
        extract: (r) => r is JWBloodOxygen ? r.value.toDouble() : null,
        timeOf: (r) => (r as JWBloodOxygen).time,
        unit: '%',
        primaryLabel: (avg) => '平均 ${avg.round()}%',
        lineColor: const Color(0xFF2F80ED),
        fillColor: const Color(0x332F80ED),
        chartKey: 'bloodOxygen',
        yPad: 2,
        yClampMin: 70,
        yClampMax: 100,
      ),
    JwDataTypeId.temperature => _scalarLineStats(
        records: records,
        extract: (r) => r is JWTemperature ? r.skinTemperature : null,
        timeOf: (r) => (r as JWTemperature).time,
        unit: '℃',
        primaryLabel: (avg) => '平均 ${avg.toStringAsFixed(1)} ℃',
        lineColor: const Color(0xFFEB5757),
        fillColor: const Color(0x33EB5757),
        chartKey: 'temperature',
        yPad: 0.5,
        formatValue: (v) => v.toStringAsFixed(1),
      ),
    JwDataTypeId.hrv => _scalarLineStats(
        records: records,
        extract: (r) => r is JWHrv ? r.sdnn.toDouble() : null,
        timeOf: (r) => (r as JWHrv).time,
        unit: 'ms',
        primaryLabel: (avg) => '平均 SDNN ${avg.round()} ms',
        lineColor: const Color(0xFF9B51E0),
        fillColor: const Color(0x339B51E0),
        chartKey: 'hrv',
        yPad: 5,
      ),
    JwDataTypeId.pressure => _scalarLineStats(
        records: records,
        extract: (r) => r is JWPressure ? r.value.toDouble() : null,
        timeOf: (r) => (r as JWPressure).time,
        unit: '',
        primaryLabel: (avg) => '平均 ${avg.round()}',
        lineColor: const Color(0xFF27AE60),
        fillColor: const Color(0x3327AE60),
        chartKey: 'pressure',
        yPad: 2,
      ),
    JwDataTypeId.bloodSugar => _scalarLineStats(
        records: records,
        extract: (r) => r is JWBloodGlucose ? r.value / 10.0 : null,
        timeOf: (r) => (r as JWBloodGlucose).time,
        unit: 'mmol/L',
        primaryLabel: (avg) => '平均 ${avg.toStringAsFixed(1)} mmol/L',
        lineColor: const Color(0xFFF2994A),
        fillColor: const Color(0x33F2994A),
        chartKey: 'bloodSugar',
        yPad: 0.5,
        formatValue: (v) => v.toStringAsFixed(1),
      ),
    JwDataTypeId.bloodPressure => _bloodPressureStats(records),
    JwDataTypeId.sleep => _sleepStats(records),
    JwDataTypeId.sport => _sportStats(records),
  };
}

JwDataDayStats _heartRateStats(List<Object> records) {
  final points = <JwChartPoint>[];
  var min = 999;
  var max = 0;
  var sum = 0;
  for (final row in records) {
    if (row is! JWHeartRate) continue;
    final bpm = row.heartRate;
    if (bpm <= 0) continue;
    min = math.min(min, bpm);
    max = math.max(max, bpm);
    sum += bpm;
    points.add(JwChartPoint(x: _dayFraction(row.time), y: bpm.toDouble()));
  }
  if (points.isEmpty) {
    return const JwDataDayStats(
      primary: '暂无有效心率',
      secondary: [],
      chart: null,
    );
  }
  final avg = (sum / points.length).round();
  return JwDataDayStats(
    primary: '平均 $avg bpm',
    secondary: [
      '最高 $max bpm',
      '最低 $min bpm',
      '共 ${points.length} 次',
    ],
    chart: JwLineChart(
      key: const Key('jw.demo.data.chart.heartRate'),
      points: points,
      yMin: math.max(40, (min - 10).toDouble()),
      yMax: math.min(220, (max + 10).toDouble()),
      lineColor: const Color(0xFFFF2D55),
      fillColor: const Color(0x33FF2D55),
      xLabels: const ['0', '6', '12', '18', '24'],
    ),
  );
}

JwDataDayStats _activityStats(List<Object> records) {
  // App 日视图按半小时粒度；协议本身是 15 分钟桶，合并到 30 分钟更易读。
  final halfHour = List<double>.filled(48, 0);
  var totalSteps = 0;
  var totalDistance = 0;
  var totalEnergy = 0;
  var segments = 0;
  for (final row in records) {
    if (row is! JWActivity) continue;
    if (row.steps <= 0 && row.distance <= 0 && row.energy <= 0) continue;
    segments += 1;
    totalSteps += row.steps;
    totalDistance += row.distance;
    totalEnergy += row.energy;
    final slot =
        ((row.time.hour * 60 + row.time.minute) ~/ 30).clamp(0, 47);
    halfHour[slot] += row.steps.toDouble();
  }
  final bars = [
    for (var i = 0; i < 48; i++) JwChartBar(index: i, value: halfHour[i]),
  ];
  return JwDataDayStats(
    primary: '$totalSteps 步',
    secondary: [
      '距离 ${jwDataFormatKm(totalDistance)} km',
      '热量 ${jwDataFormatKcal(totalEnergy)} kcal',
      '共 $segments 段',
    ],
    chart: JwBarChart(
      key: const Key('jw.demo.data.chart.activity'),
      bars: bars,
      barColor: const Color(0xFF5C5CE0),
      xLabels: const ['0', '6', '12', '18', '24'],
    ),
  );
}

JwDataDayStats _bloodPressureStats(List<Object> records) {
  final sys = <JwChartPoint>[];
  final dia = <JwChartPoint>[];
  var sysSum = 0;
  var diaSum = 0;
  var sysMin = 999;
  var sysMax = 0;
  var diaMin = 999;
  var diaMax = 0;
  for (final row in records) {
    if (row is! JWBloodPressure) continue;
    final x = _dayFraction(row.time);
    sys.add(JwChartPoint(x: x, y: row.systolic.toDouble()));
    dia.add(JwChartPoint(x: x, y: row.diastolic.toDouble()));
    sysSum += row.systolic;
    diaSum += row.diastolic;
    sysMin = math.min(sysMin, row.systolic);
    sysMax = math.max(sysMax, row.systolic);
    diaMin = math.min(diaMin, row.diastolic);
    diaMax = math.max(diaMax, row.diastolic);
  }
  if (sys.isEmpty) {
    return const JwDataDayStats(
      primary: '暂无有效血压',
      secondary: [],
      chart: null,
    );
  }
  final avgSys = (sysSum / sys.length).round();
  final avgDia = (diaSum / dia.length).round();
  return JwDataDayStats(
    primary: '平均 $avgSys/$avgDia mmHg',
    secondary: [
      '收缩 $sysMin–$sysMax',
      '舒张 $diaMin–$diaMax',
      '共 ${sys.length} 次',
    ],
    chart: JwLineChart(
      key: const Key('jw.demo.data.chart.bloodPressure'),
      points: sys,
      secondaryPoints: dia,
      yMin: math.max(40, (math.min(sysMin, diaMin) - 10).toDouble()),
      yMax: math.min(220, (math.max(sysMax, diaMax) + 10).toDouble()),
      lineColor: const Color(0xFFEB5757),
      fillColor: const Color(0x22EB5757),
      secondaryColor: const Color(0xFF2F80ED),
      xLabels: const ['0', '6', '12', '18', '24'],
    ),
  );
}

JwDataDayStats _sleepStats(List<Object> records) {
  final summary = jwDataSummarizeSleep(records);
  final total = summary.totalMinutes;
  final primary = total > 0
      ? '睡眠 ${jwDataFormatDuration(total * 60)}'
      : '暂无有效睡眠段';
  return JwDataDayStats(
    primary: primary,
    secondary: [
      '浅睡 ${jwDataFormatDuration(summary.lightMinutes * 60)}',
      '深睡 ${jwDataFormatDuration(summary.deepMinutes * 60)}',
      if (summary.remMinutes > 0)
        '快速眼动 ${jwDataFormatDuration(summary.remMinutes * 60)}',
      if (summary.awakeMinutes > 0)
        '清醒 ${jwDataFormatDuration(summary.awakeMinutes * 60)}',
      '事件 ${records.whereType<JWSleep>().length} 次',
    ],
    chart: JwSleepStageChart(
      key: const Key('jw.demo.data.chart.sleep'),
      lightMinutes: summary.lightMinutes,
      deepMinutes: summary.deepMinutes,
      awakeMinutes: summary.awakeMinutes,
      remMinutes: summary.remMinutes,
    ),
  );
}

JwDataDayStats _sportStats(List<Object> records) {
  final sports = records.whereType<JWSport>().toList();
  if (sports.isEmpty) {
    return const JwDataDayStats(
      primary: '暂无运动记录',
      secondary: [],
      chart: null,
    );
  }
  var duration = 0;
  var steps = 0;
  var distance = 0;
  var energy = 0;
  final bars = <JwChartBar>[];
  for (var i = 0; i < sports.length; i++) {
    final s = sports[i];
    duration += s.duration;
    steps += s.steps;
    distance += s.distance;
    energy += s.energy;
    bars.add(JwChartBar(index: i, value: s.duration.toDouble()));
  }
  return JwDataDayStats(
    primary: '${sports.length} 次 · ${jwDataFormatDuration(duration)}',
    secondary: [
      if (steps > 0) '步数 $steps',
      if (distance > 0) '距离 ${jwDataFormatKm(distance)} km',
      if (energy > 0) '热量 ${jwDataFormatKcal(energy)} kcal',
    ],
    chart: JwBarChart(
      key: const Key('jw.demo.data.chart.sport'),
      bars: bars,
      barColor: const Color(0xFF56CCF2),
      xLabels: sports.length <= 1
          ? const ['本次']
          : [
              '1',
              if (sports.length > 2) '${(sports.length / 2).ceil()}',
              '${sports.length}',
            ],
    ),
  );
}

JwDataDayStats _scalarLineStats({
  required List<Object> records,
  required double? Function(Object row) extract,
  required DateTime Function(Object row) timeOf,
  required String unit,
  required String Function(double avg) primaryLabel,
  required Color lineColor,
  required Color fillColor,
  required String chartKey,
  double yPad = 1,
  double? yClampMin,
  double? yClampMax,
  String Function(double value)? formatValue,
}) {
  final points = <JwChartPoint>[];
  var min = double.infinity;
  var max = -double.infinity;
  var sum = 0.0;
  for (final row in records) {
    final value = extract(row);
    if (value == null) continue;
    min = math.min(min, value);
    max = math.max(max, value);
    sum += value;
    points.add(JwChartPoint(x: _dayFraction(timeOf(row)), y: value));
  }
  if (points.isEmpty) {
    return const JwDataDayStats(
      primary: '暂无有效数据',
      secondary: [],
      chart: null,
    );
  }
  final avg = sum / points.length;
  final fmt = formatValue ?? (v) => v.round().toString();
  var yMin = min - yPad;
  var yMax = max + yPad;
  if (yClampMin != null) yMin = math.max(yClampMin, yMin);
  if (yClampMax != null) yMax = math.min(yClampMax, yMax);
  if (yMax <= yMin) yMax = yMin + 1;
  final unitSuffix = unit.isEmpty ? '' : ' $unit';
  return JwDataDayStats(
    primary: primaryLabel(avg),
    secondary: [
      '最高 ${fmt(max)}$unitSuffix',
      '最低 ${fmt(min)}$unitSuffix',
      '共 ${points.length} 次',
    ],
    chart: JwLineChart(
      key: Key('jw.demo.data.chart.$chartKey'),
      points: points,
      yMin: yMin,
      yMax: yMax,
      lineColor: lineColor,
      fillColor: fillColor,
      xLabels: const ['0', '6', '12', '18', '24'],
    ),
  );
}

double _dayFraction(DateTime time) =>
    (time.hour * 60 + time.minute) / (24 * 60);

final class JwChartPoint {
  const JwChartPoint({required this.x, required this.y});
  final double x; // 0..1
  final double y;
}

final class JwChartBar {
  const JwChartBar({required this.index, required this.value});
  final int index;
  final double value;
}

class JwLineChart extends StatelessWidget {
  const JwLineChart({
    super.key,
    required this.points,
    required this.yMin,
    required this.yMax,
    required this.lineColor,
    required this.fillColor,
    required this.xLabels,
    this.secondaryPoints,
    this.secondaryColor,
  });

  final List<JwChartPoint> points;
  final List<JwChartPoint>? secondaryPoints;
  final double yMin;
  final double yMax;
  final Color lineColor;
  final Color fillColor;
  final Color? secondaryColor;
  final List<String> xLabels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: points,
              secondaryPoints: secondaryPoints,
              yMin: yMin,
              yMax: yMax,
              lineColor: lineColor,
              fillColor: fillColor,
              secondaryColor: secondaryColor,
              gridColor: JwSettingsAppTheme.divider,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in xLabels)
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: JwSettingsAppTheme.muted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class JwBarChart extends StatelessWidget {
  const JwBarChart({
    super.key,
    required this.bars,
    required this.barColor,
    required this.xLabels,
  });

  final List<JwChartBar> bars;
  final Color barColor;
  final List<String> xLabels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarChartPainter(
              bars: bars,
              barColor: barColor,
              gridColor: JwSettingsAppTheme.divider,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in xLabels)
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: JwSettingsAppTheme.muted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class JwSleepStageChart extends StatelessWidget {
  const JwSleepStageChart({
    super.key,
    required this.lightMinutes,
    required this.deepMinutes,
    required this.awakeMinutes,
    this.remMinutes = 0,
  });

  final int lightMinutes;
  final int deepMinutes;
  final int awakeMinutes;
  final int remMinutes;

  @override
  Widget build(BuildContext context) {
    final total = lightMinutes + deepMinutes + awakeMinutes + remMinutes;
    if (total <= 0) {
      return const SizedBox(
        height: 24,
        child: Text(
          '无足够状态切换点估算时长',
          style: TextStyle(fontSize: 12, color: JwSettingsAppTheme.muted),
        ),
      );
    }
    Widget seg(Color color, int minutes, String label) {
      if (minutes <= 0) return const SizedBox.shrink();
      return Expanded(
        flex: minutes,
        child: Tooltip(
          message: '$label ${jwDataFormatDuration(minutes * 60)}',
          child: Container(color: color),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                seg(const Color(0xFF56CCF2), lightMinutes, '浅睡'),
                seg(const Color(0xFF2F80ED), deepMinutes, '深睡'),
                seg(const Color(0xFF9B51E0), remMinutes, '快速眼动'),
                seg(const Color(0xFFBDBDBD), awakeMinutes, '清醒'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            const _LegendDot(color: Color(0xFF56CCF2), label: '浅睡'),
            const _LegendDot(color: Color(0xFF2F80ED), label: '深睡'),
            if (remMinutes > 0)
              const _LegendDot(color: Color(0xFF9B51E0), label: '快速眼动'),
            const _LegendDot(color: Color(0xFFBDBDBD), label: '清醒'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: JwSettingsAppTheme.muted),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.secondaryPoints,
    required this.yMin,
    required this.yMax,
    required this.lineColor,
    required this.fillColor,
    required this.secondaryColor,
    required this.gridColor,
  });

  final List<JwChartPoint> points;
  final List<JwChartPoint>? secondaryPoints;
  final double yMin;
  final double yMax;
  final Color lineColor;
  final Color fillColor;
  final Color? secondaryColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    _paintSeries(
      canvas,
      chart,
      points,
      lineColor,
      fillColor,
      fill: true,
    );
    final secondary = secondaryPoints;
    if (secondary != null && secondary.isNotEmpty && secondaryColor != null) {
      _paintSeries(
        canvas,
        chart,
        secondary,
        secondaryColor!,
        secondaryColor!.withValues(alpha: 0.12),
        fill: false,
      );
    }
  }

  void _paintSeries(
    Canvas canvas,
    Rect chart,
    List<JwChartPoint> series,
    Color stroke,
    Color fillColor, {
    required bool fill,
  }) {
    if (series.isEmpty || yMax <= yMin) return;
    final path = Path();
    final fillPath = Path();
    Offset? last;
    for (var i = 0; i < series.length; i++) {
      final p = series[i];
      final dx = chart.left + chart.width * p.x.clamp(0.0, 1.0);
      final dy = chart.bottom -
          chart.height * ((p.y - yMin) / (yMax - yMin)).clamp(0.0, 1.0);
      final offset = Offset(dx, dy);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
        fillPath.moveTo(offset.dx, chart.bottom);
        fillPath.lineTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
        fillPath.lineTo(offset.dx, offset.dy);
      }
      last = offset;
    }
    if (fill && last != null) {
      fillPath.lineTo(last.dx, chart.bottom);
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = fillColor);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.secondaryPoints != secondaryPoints ||
      oldDelegate.yMin != yMin ||
      oldDelegate.yMax != yMax;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.bars,
    required this.barColor,
    required this.gridColor,
  });

  final List<JwChartBar> bars;
  final Color barColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    if (bars.isEmpty) return;
    final maxValue = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    if (maxValue <= 0) return;
    final slot = chart.width / bars.length;
    final barWidth = math.max(2.0, slot * 0.55);
    final paint = Paint()..color = barColor;
    for (final bar in bars) {
      if (bar.value <= 0) continue;
      final h = chart.height * (bar.value / maxValue);
      final left = chart.left + slot * bar.index + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, chart.bottom - h, barWidth, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.bars != bars;
}
