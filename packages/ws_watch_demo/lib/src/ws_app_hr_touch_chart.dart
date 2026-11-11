import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ws_app_chart_layout.dart';
import 'ws_app_chart_models.dart';
import 'ws_health_app_theme.dart';

final class WsAppHrTouchSelection {
  const WsAppHrTouchSelection({
    required this.hour,
    required this.begin,
    required this.end,
    required this.avgHr,
    required this.maxHr,
    required this.minHr,
    required this.anchorX,
  });

  final int hour;
  final DateTime begin;
  final DateTime end;
  final int avgHr;
  final int maxHr;
  final int minHr;
  final double anchorX;
}

/// 对齐 Android `HeartRateTouchView3`（小时点/折线 + 长按选中）。
class WsAppHrTouchChart extends StatefulWidget {
  const WsAppHrTouchChart({
    super.key,
    required this.hours,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    this.onSelection,
    this.mode = WsAppChartMode.detail,
  });

  final List<WsAppHrHourBucket> hours;
  final int axisMax;
  final int axisMin;
  final double averageRate;
  final ValueChanged<WsAppHrTouchSelection?>? onSelection;
  final WsAppChartMode mode;

  @override
  State<WsAppHrTouchChart> createState() => _JwAppHrTouchChartState();
}

class _JwAppHrTouchChartState extends State<WsAppHrTouchChart> {
  int _touchHour = -1;
  int _downHour = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  @override
  void didUpdateWidget(covariant WsAppHrTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameHours(oldWidget.hours, widget.hours)) {
      _delay?.cancel();
      _touchHour = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection?.call(null);
      });
    }
  }

  bool _sameHours(List<WsAppHrHourBucket> a, List<WsAppHrHourBucket> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hour != b[i].hour ||
          a[i].avgHr != b[i].avgHr ||
          a[i].rates.length != b[i].rates.length) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  void _clear() {
    _delay?.cancel();
    final had = _touchHour != -1;
    _touchHour = -1;
    _armed = false;
    _tracking = false;
    if (had && mounted) setState(() {});
    widget.onSelection?.call(null);
  }

  void _emit(int hour, double width) {
    final bucket = widget.hours.firstWhere(
      (e) => e.hour == hour,
      orElse: () => WsAppHrHourBucket(
        hour: hour,
        startTime: DateTime.now(),
        rates: const [],
        avgHr: 0,
      ),
    );
    final touchPadding = 5.0;
    final eachWidth = (width - 2 * touchPadding) / 23.0;
    final anchorX = touchPadding + eachWidth * hour;
    final rates = bucket.rates.where((e) => e > 0);
    widget.onSelection?.call(
      WsAppHrTouchSelection(
        hour: hour,
        begin: bucket.startTime,
        end: bucket.startTime.add(const Duration(hours: 1)),
        avgHr: bucket.avgHr,
        maxHr: rates.isEmpty ? 0 : rates.reduce(math.max),
        minHr: rates.isEmpty ? 0 : rates.reduce(math.min),
        anchorX: anchorX,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = WsAppChartLayout.interactive(widget.mode);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final touchPadding = 5.0;
        final eachWidth = (width - 2 * touchPadding) / 23.0;
        final paint = CustomPaint(
          size: Size(width, height),
          painter: _HrPainter(
            hours: widget.hours,
            axisMax: widget.axisMax.toDouble(),
            axisMin: widget.axisMin.toDouble(),
            averageRate: widget.averageRate,
            touchHour: interactive ? _touchHour : -1,
            mode: widget.mode,
          ),
        );
        if (!interactive) return paint;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            _delay?.cancel();
            _armed = true;
            _tracking = false;
            _downPos = d.localPosition;
            _downHour = ((d.localPosition.dx - touchPadding) / eachWidth)
                .round()
                .clamp(0, 23);
            _delay = Timer(WsHealthAppTheme.chartTouchDelay, () {
              if (!mounted || !_armed) return;
              setState(() {
                _tracking = true;
                _touchHour = _downHour;
              });
              _emit(_touchHour, width);
            });
          },
          onPanUpdate: (d) {
            final down = _downPos;
            if (down == null) return;
            final dx = (d.localPosition.dx - down.dx).abs();
            final dy = (d.localPosition.dy - down.dy).abs();
            if (!_tracking && dx > 12 && dx > dy) {
              _clear();
              return;
            }
            if (!_tracking) return;
            final hour = ((d.localPosition.dx - touchPadding) / eachWidth)
                .round()
                .clamp(0, 23);
            if (hour != _touchHour) {
              setState(() => _touchHour = hour);
              _emit(hour, width);
            }
          },
          onPanEnd: (_) => _clear(),
          onPanCancel: _clear,
          child: paint,
        );
      },
    );
  }
}

class _HrPainter extends CustomPainter {
  _HrPainter({
    required this.hours,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    required this.touchHour,
    required this.mode,
  });

  final List<WsAppHrHourBucket> hours;
  final double axisMax;
  final double axisMin;
  final double averageRate;
  final int touchHour;
  final WsAppChartMode mode;

  static const _touchPad = 5.0;
  static const _radius = 3.5;

  double get _top => WsAppChartLayout.top(mode);

  double get _bottomText => WsAppChartLayout.bottomText(mode, detail: 20);

  bool get _showYAxis => WsAppChartLayout.showYAxis(mode);

  bool get _showXAxis => WsAppChartLayout.showXAxis(mode);

  double _chartRight(double width) =>
      _showYAxis ? width - _touchPad - 40 : width - _touchPad;

  Offset _point(double value, int hour, double width, double height) {
    final eachWidth = (width - 2 * _touchPad) / 23.0;
    final eachHeight = (height - _top - _bottomText) / (axisMax - axisMin);
    final x = _touchPad + eachWidth * hour;
    final y = _top + (axisMax - value) * eachHeight;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartBottom = size.height - _bottomText;
    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: WsHealthAppTheme.hrAxisLabel,
      fontSize: 10.6,
    );

    final chartRight = _chartRight(size.width);
    if (_showYAxis) {
      text.text = TextSpan(text: '${axisMax.round()}', style: labelStyle);
      text.layout();
      text.paint(canvas, Offset(size.width - _touchPad - text.width, _top - 12));
      text.text = TextSpan(text: '${axisMin.round()}', style: labelStyle);
      text.layout();
      text.paint(
        canvas,
        Offset(size.width - _touchPad - text.width, chartBottom - 12),
      );
    }

    final axisPaint = Paint()
      ..color = WsHealthAppTheme.hrHeadLine
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(_touchPad, _top),
      Offset(chartRight, _top),
      axisPaint,
    );
    canvas.drawLine(
      Offset(_touchPad, chartBottom),
      Offset(chartRight, chartBottom),
      axisPaint,
    );

    if (_showXAxis) {
      for (var j = 0; j < 24; j++) {
        final x = _touchPad + ((size.width - 2 * _touchPad) / 23.0) * j;
        if (j == 0 || j == 23) {
          canvas.drawCircle(
            Offset(x, WsAppChartLayout.xAxisDotY(size.height, _bottomText)),
            1.5,
            Paint()..color = WsHealthAppTheme.hrAxisLabel,
          );
        } else if (j % 4 == 0) {
          final str = '${j.toString().padLeft(2, '0')}:00';
          text.text = TextSpan(text: str, style: labelStyle);
          text.layout();
          text.paint(
            canvas,
            Offset(
              x - text.width / 2,
              WsAppChartLayout.xAxisLabelY(size.height, _bottomText),
            ),
          );
        }
      }
    }

    final hasData = hours.any((h) => h.rates.any((r) => r > 0));
    if (!hasData && WsAppChartLayout.showEmptyHint(mode)) {
      text.text = TextSpan(
        text: '暂无心率',
        style: TextStyle(
          color: WsHealthAppTheme.hrEmpty,
          fontSize: WsAppChartLayout.emptyHintFontSize(mode),
        ),
      );
      text.layout();
      text.paint(
        canvas,
        Offset(
          (size.width - text.width) / 2,
          _top + (chartBottom - _top) / 2 - 8,
        ),
      );
      return;
    }

    final samplePaint = Paint()
      ..color = WsHealthAppTheme.hrSampleDot
      ..style = PaintingStyle.fill;
    for (final h in hours) {
      for (final r in h.rates) {
        if (r <= 0) continue;
        final p = _point(r.toDouble(), h.hour, size.width, size.height);
        canvas.drawCircle(p, _radius, samplePaint);
      }
    }

    final linePaint = Paint()
      ..color = WsHealthAppTheme.hrLine
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final avgDot = Paint()
      ..color = WsHealthAppTheme.hrLine
      ..style = PaintingStyle.fill;
    Offset? prev;
    for (final h in hours) {
      if (h.avgHr <= 0) continue;
      final p = _point(h.avgHr.toDouble(), h.hour, size.width, size.height);
      if (prev != null && (p.dx - prev.dx).abs() <= 1.5 * ((size.width - 10) / 23)) {
        canvas.drawLine(prev, p, linePaint);
        canvas.drawCircle(prev, _radius, avgDot);
      }
      canvas.drawCircle(p, _radius, avgDot);
      prev = p;
    }

    // hollow center
    final hole = Paint()
      ..color = WsHealthAppTheme.hrChartBg
      ..style = PaintingStyle.fill;
    for (final h in hours) {
      if (h.avgHr <= 0) continue;
      final p = _point(h.avgHr.toDouble(), h.hour, size.width, size.height);
      canvas.drawCircle(p, 2, hole);
    }

    if (_showYAxis && averageRate > axisMin && averageRate < axisMax) {
      final avgY = _top + (axisMax - averageRate) * ((chartBottom - _top) / (axisMax - axisMin));
      final dash = Paint()
        ..color = WsHealthAppTheme.hrAvgDash
        ..strokeWidth = 1;
      for (var k = 0; k < (size.width / 3).floor(); k++) {
        if (k.isEven) {
          canvas.drawLine(
            Offset(_touchPad + k * 3, avgY),
            Offset(_touchPad + (k + 1) * 3.0, avgY),
            dash,
          );
        }
      }
      // avg tag
      final tag = '${averageRate.round()}';
      text.text = TextSpan(
        text: tag,
        style: const TextStyle(
          color: WsHealthAppTheme.hrAvgText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      text.layout();
      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width - _touchPad - text.width - 16,
          avgY - 10,
          text.width + 14,
          20,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(tagRect, Paint()..color = WsHealthAppTheme.hrAvgDash);
      text.paint(
        canvas,
        Offset(size.width - _touchPad - text.width - 9, avgY - 7),
      );
    }

    if (touchHour >= 0 && touchHour < 24) {
      final x = _touchPad + ((size.width - 2 * _touchPad) / 23.0) * touchHour;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartBottom),
        Paint()
          ..color = WsHealthAppTheme.hrThumbBg
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HrPainter oldDelegate) =>
      oldDelegate.hours != hours ||
      oldDelegate.axisMax != axisMax ||
      oldDelegate.axisMin != axisMin ||
      oldDelegate.averageRate != averageRate ||
      oldDelegate.touchHour != touchHour ||
      oldDelegate.mode != mode;
}
