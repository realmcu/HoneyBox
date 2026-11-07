import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'jw_app_chart_models.dart';
import 'jw_health_app_theme.dart';

final class JwAppBpTouchSelection {
  const JwAppBpTouchSelection({
    required this.high,
    required this.low,
    required this.begin,
    required this.end,
    required this.anchorX,
  });

  final int high;
  final int low;
  final DateTime begin;
  final DateTime end;
  final double anchorX;
}

/// 对齐 Android `BpTouchView2`（24 小时血压柱、渐变连线、参考带）。
class JwAppBpTouchChart extends StatefulWidget {
  const JwAppBpTouchChart({
    super.key,
    required this.hours,
    required this.onSelection,
  });

  final List<JwAppBpHourBucket> hours;
  final ValueChanged<JwAppBpTouchSelection?> onSelection;

  @override
  State<JwAppBpTouchChart> createState() => _JwAppBpTouchChartState();
}

class _JwAppBpTouchChartState extends State<JwAppBpTouchChart> {
  static const double _rightLabel = 30;
  static const int _axisMax = 180;
  static const int _axisMin = 30;

  int _touchHour = -1;
  int _downHour = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  @override
  void didUpdateWidget(covariant JwAppBpTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameHours(oldWidget.hours, widget.hours)) {
      _delay?.cancel();
      _touchHour = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection(null);
      });
    }
  }

  bool _sameHours(List<JwAppBpHourBucket> a, List<JwAppBpHourBucket> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hour != b[i].hour ||
          a[i].avgHigh != b[i].avgHigh ||
          a[i].avgLow != b[i].avgLow) {
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
    widget.onSelection(null);
  }

  double _eachWidth(double width) => (width - _rightLabel) / 24.0;

  int _hourFromDx(double dx, double width) {
    final ew = _eachWidth(width);
    var h = (dx / ew).floor();
    if (h < 0) h = 0;
    if (h > 23) h = 23;
    return h;
  }

  bool _hasBp(int hour) {
    final b = _bucket(hour);
    return b.avgHigh > 0 && b.avgLow > 0;
  }

  JwAppBpHourBucket _bucket(int hour) {
    return widget.hours.firstWhere(
      (e) => e.hour == hour,
      orElse: () => JwAppBpHourBucket(
        hour: hour,
        startTime: DateTime.now(),
        avgHigh: 0,
        avgLow: 0,
      ),
    );
  }

  void _emit(int hour, double width) {
    final b = _bucket(hour);
    final ew = _eachWidth(width);
    final anchorX = (hour + 0.5) * ew;
    widget.onSelection(
      JwAppBpTouchSelection(
        high: b.avgHigh,
        low: b.avgLow,
        begin: b.startTime,
        end: b.startTime.add(const Duration(hours: 1)),
        anchorX: anchorX,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final ew = _eachWidth(width);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            _delay?.cancel();
            _downHour = _hourFromDx(d.localPosition.dx, width);
            if (!_hasBp(_downHour)) return;
            _armed = true;
            _tracking = false;
            _downPos = d.localPosition;
            _delay = Timer(JwHealthAppTheme.chartTouchDelay, () {
              if (!mounted || !_armed) return;
              if (!_hasBp(_downHour)) return;
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
            final hour = _hourFromDx(d.localPosition.dx, width);
            if (hour != _touchHour && _hasBp(hour)) {
              setState(() => _touchHour = hour);
              _emit(hour, width);
            }
          },
          onPanEnd: (_) => _clear(),
          onPanCancel: _clear,
          child: CustomPaint(
            size: Size(width, height),
            painter: _BpPainter(
              hours: widget.hours,
              axisMax: _axisMax,
              axisMin: _axisMin,
              touchHour: _touchHour,
              eachWidth: ew,
            ),
          ),
        );
      },
    );
  }
}

class _BpPainter extends CustomPainter {
  _BpPainter({
    required this.hours,
    required this.axisMax,
    required this.axisMin,
    required this.touchHour,
    required this.eachWidth,
  });

  final List<JwAppBpHourBucket> hours;
  final int axisMax;
  final int axisMin;
  final int touchHour;
  final double eachWidth;

  static const double _top = 19;
  static const double _bottomText = 60;
  static const double _rightLabel = 30;
  static const double _labelPadRight = 5;
  static const double _capHalfW = 4.5;
  static const double _capHighH = 5;
  static const double _capLowUp = 5;
  static const double _lineInset = 2.5;
  static const double _gradientStroke = 9;
  static const double _bandHighStrokeFactor = 50;
  static const double _bandLowStrokeFactor = 20;

  double _yForBp(double value, double chartBottom) {
    final eh = (chartBottom - _top) / (axisMax - axisMin);
    return _top + (axisMax - value) * eh;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartRight = size.width - _rightLabel;
    final chartBottom = size.height - _bottomText;
    final eh = (chartBottom - _top) / (axisMax - axisMin);
    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    const labelStyle = TextStyle(
      color: JwHealthAppTheme.bpText,
      fontSize: 10.6,
    );

    // 背景带（与 BpTouchView2 粗线等效）
    final y105 = _yForBp(105, chartBottom);
    final y70 = _yForBp(70, chartBottom);
    final bandHighPaint = Paint()
      ..color = JwHealthAppTheme.bpBandHigh
      ..strokeWidth = _bandHighStrokeFactor * eh
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    final bandLowPaint = Paint()
      ..color = JwHealthAppTheme.bpBandLow
      ..strokeWidth = _bandLowStrokeFactor * eh
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    canvas.drawLine(Offset(0, y105), Offset(chartRight, y105), bandHighPaint);
    canvas.drawLine(Offset(0, y70), Offset(chartRight, y70), bandLowPaint);

    final axisPaint = Paint()
      ..color = JwHealthAppTheme.bpHeadLine
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, _top), Offset(chartRight, _top), axisPaint);
    canvas.drawLine(
      Offset(0, _yForBp(axisMin.toDouble(), chartBottom)),
      Offset(chartRight, _yForBp(axisMin.toDouble(), chartBottom)),
      axisPaint,
    );

    for (var i = 0; i < 24; i++) {
      final x = (i + 0.5) * eachWidth;
      if (i == 0 || i == 23) {
        canvas.drawCircle(
          Offset(x, size.height - _bottomText + 20),
          1.5,
          Paint()..color = JwHealthAppTheme.bpText,
        );
      } else if (i % 4 == 0) {
        final str = '${i.toString().padLeft(2, '0')}:00';
        text.text = TextSpan(text: str, style: labelStyle);
        text.layout();
        text.paint(
          canvas,
          Offset(x - text.width / 2, size.height - _bottomText + 23),
        );
      }
    }

    final hasData =
        hours.any((h) => h.avgHigh > 0 && h.avgLow > 0);
    if (!hasData) {
      text.text = const TextSpan(
        text: '暂无血压',
        style: TextStyle(color: JwHealthAppTheme.bpEmpty, fontSize: 23),
      );
      text.layout();
      text.paint(
        canvas,
        Offset(
          chartRight / 2 - text.width / 2,
          _top + (chartBottom - _top) / 2 - 8,
        ),
      );
    } else {
      final linePaint = Paint()
        ..strokeWidth = _gradientStroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke;

      for (final h in hours) {
        if (h.avgHigh <= 0 || h.avgLow <= 0) continue;
        final cx = (h.hour + 0.5) * eachWidth;
        final yHi = _yForBp(h.avgHigh.toDouble(), chartBottom) + _lineInset;
        final yLo = _yForBp(h.avgLow.toDouble(), chartBottom) - _lineInset;
        linePaint.shader = ui.Gradient.linear(
          Offset(cx, yHi),
          Offset(cx, yLo),
          const [JwHealthAppTheme.bpHigh, JwHealthAppTheme.bpLow],
        );
        canvas.drawLine(Offset(cx, yHi), Offset(cx, yLo), linePaint);

        final highRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx - _capHalfW,
            _yForBp(h.avgHigh.toDouble(), chartBottom),
            cx + _capHalfW,
            _yForBp(h.avgHigh.toDouble(), chartBottom) + _capHighH,
          ),
          const Radius.circular(1.3),
        );
        canvas.drawRRect(
          highRect,
          Paint()..color = JwHealthAppTheme.bpHigh,
        );
        final lowRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx - _capHalfW,
            _yForBp(h.avgLow.toDouble(), chartBottom) - _capLowUp,
            cx + _capHalfW,
            _yForBp(h.avgLow.toDouble(), chartBottom),
          ),
          const Radius.circular(1.3),
        );
        canvas.drawRRect(
          lowRect,
          Paint()..color = JwHealthAppTheme.bpLow,
        );
      }

      if (touchHour >= 0 &&
          touchHour < 24 &&
          _bucket(touchHour).avgHigh > 0 &&
          _bucket(touchHour).avgLow > 0) {
        final b = _bucket(touchHour);
        final cx = (touchHour + 0.5) * eachWidth;
        final yHi = _yForBp(b.avgHigh.toDouble(), chartBottom);
        final yLo = _yForBp(b.avgLow.toDouble(), chartBottom);
        final thumb = Paint()
          ..color = JwHealthAppTheme.bpThumbBg
          ..strokeWidth = 1;
        canvas.drawLine(Offset(cx, 0), Offset(cx, yHi - 1), thumb);
        canvas.drawLine(Offset(cx, yLo + 1), Offset(cx, chartBottom), thumb);
      }
    }

    final labelRight = size.width - _labelPadRight;
    const labelDy = 12.0;
    text.text = TextSpan(text: '$axisMax', style: labelStyle);
    text.layout();
    text.paint(canvas, Offset(labelRight - text.width, _top - labelDy));

    text.text = const TextSpan(text: '130', style: TextStyle(color: JwHealthAppTheme.bpText, fontSize: 10.6));
    text.layout();
    text.paint(canvas, Offset(labelRight - text.width, _yForBp(130, chartBottom) - labelDy));

    text.text = const TextSpan(text: '80', style: TextStyle(color: JwHealthAppTheme.bpText, fontSize: 10.6));
    text.layout();
    text.paint(canvas, Offset(labelRight - text.width, _yForBp(80, chartBottom) - labelDy));

    text.text = const TextSpan(text: '60', style: TextStyle(color: JwHealthAppTheme.bpText, fontSize: 10.6));
    text.layout();
    text.paint(canvas, Offset(labelRight - text.width, _yForBp(60, chartBottom) - labelDy));

    text.text = TextSpan(text: '$axisMin', style: labelStyle);
    text.layout();
    text.paint(
      canvas,
      Offset(labelRight - text.width, _yForBp(axisMin.toDouble(), chartBottom) - labelDy),
    );
  }

  JwAppBpHourBucket _bucket(int hour) {
    return hours.firstWhere(
      (e) => e.hour == hour,
      orElse: () => JwAppBpHourBucket(
        hour: hour,
        startTime: DateTime.now(),
        avgHigh: 0,
        avgLow: 0,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _BpPainter oldDelegate) =>
      oldDelegate.hours != hours ||
      oldDelegate.touchHour != touchHour ||
      oldDelegate.eachWidth != eachWidth;
}
