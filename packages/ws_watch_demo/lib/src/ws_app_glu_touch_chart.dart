import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ws_app_chart_layout.dart';
import 'ws_app_chart_models.dart';
import 'ws_health_app_theme.dart';

final class WsAppGluTouchSelection {
  const WsAppGluTouchSelection({
    required this.hour,
    required this.begin,
    required this.end,
    required this.avg,
    required this.max,
    required this.min,
    required this.anchorX,
  });

  final int hour;
  final DateTime begin;
  final DateTime end;
  final double avg;
  final double max;
  final double min;
  final double anchorX;
}

/// 对齐 Android `BloodSugarTouchView3`：散点 + 有数据小时的均值折线、全身均值虚线。
class WsAppGluTouchChart extends StatefulWidget {
  const WsAppGluTouchChart({
    super.key,
    required this.hours,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    this.onSelection,
    this.mode = WsAppChartMode.detail,
  });

  final List<WsAppGluHourBucket> hours;
  final double axisMax;
  final double axisMin;
  final double averageRate;
  final ValueChanged<WsAppGluTouchSelection?>? onSelection;
  final WsAppChartMode mode;

  @override
  State<WsAppGluTouchChart> createState() => _JwAppGluTouchChartState();
}

class _JwAppGluTouchChartState extends State<WsAppGluTouchChart> {
  static const _touchPad = 5.0;

  int _touchHour = -1;
  int _downHour = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  @override
  void didUpdateWidget(covariant WsAppGluTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameHours(oldWidget.hours, widget.hours) ||
        oldWidget.axisMax != widget.axisMax ||
        oldWidget.axisMin != widget.axisMin ||
        oldWidget.averageRate != widget.averageRate) {
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

  bool _sameHours(List<WsAppGluHourBucket> a, List<WsAppGluHourBucket> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hour != b[i].hour ||
          a[i].avg != b[i].avg ||
          a[i].max != b[i].max ||
          a[i].min != b[i].min ||
          a[i].values.length != b[i].values.length) {
        return false;
      }
      for (var j = 0; j < a[i].values.length; j++) {
        if (a[i].values[j] != b[i].values[j]) return false;
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

  double _eachWidth(double width) {
    return (width - 2 * _touchPad) / 23.0;
  }

  int _hourFromDx(double dx, double width) {
    final each = _eachWidth(width);
    final x = dx - _touchPad;
    final h = (x / each).round();
    return h.clamp(0, 23);
  }

  WsAppGluHourBucket? _bucketForHour(int hour) {
    for (final h in widget.hours) {
      if (h.hour == hour) return h;
    }
    return null;
  }

  void _emit(int hour, double width) {
    final b = _bucketForHour(hour);
    if (b == null || b.avg <= 0) {
      widget.onSelection?.call(null);
      return;
    }
    final each = _eachWidth(width);
    final anchorX = _touchPad + hour * each;
    widget.onSelection?.call(
      WsAppGluTouchSelection(
        hour: hour,
        begin: b.startTime,
        end: b.startTime.add(const Duration(hours: 1)),
        avg: b.avg,
        max: b.max,
        min: b.min,
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
        final paint = CustomPaint(
          size: Size(width, height),
          painter: _GluPainter(
            hours: widget.hours,
            axisMax: widget.axisMax,
            axisMin: widget.axisMin,
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
            _downHour = _hourFromDx(d.localPosition.dx, width);
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
            final hour = _hourFromDx(d.localPosition.dx, width);
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

class _GluPainter extends CustomPainter {
  _GluPainter({
    required this.hours,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    required this.touchHour,
    required this.mode,
  });

  final List<WsAppGluHourBucket> hours;
  final double axisMax;
  final double axisMin;
  final double averageRate;
  final int touchHour;
  final WsAppChartMode mode;

  double get _top => WsAppChartLayout.top(mode);

  double get _bottomText => WsAppChartLayout.bottomText(mode, detail: 20);

  bool get _showYAxis => WsAppChartLayout.showYAxis(mode);

  bool get _showXAxis => WsAppChartLayout.showXAxis(mode);
  static const _touchPad = 5.0;
  static const _radius = 3.5;
  static const _lineLabelGap = 5.0;

  static const _defaultMax = 15.0;
  static const _defaultMin = 0.0;

  String _fmtAxis(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  double _valueSpan(double maxV, double minV) {
    final span = maxV - minV;
    return span <= 0 ? 0.0001 : span;
  }

  Offset _point(double rate, int hourIndex, double width, double chartBottom) {
    final displayMax = axisMax > axisMin ? axisMax : _defaultMax;
    final displayMin = axisMax > axisMin ? axisMin : _defaultMin;
    final span = _valueSpan(displayMax, displayMin);
    final eachHeight = (chartBottom - _top) / span;
    final eachWidth = (width - 2 * _touchPad) / 23.0;
    final x = _touchPad + hourIndex * eachWidth;
    double y;
    if (rate < displayMin) {
      y = _top + (displayMax - displayMin) * eachHeight;
    } else if (rate > displayMax) {
      y = _top;
    } else {
      y = _top + (displayMax - rate) * eachHeight;
    }
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final displayMax = axisMax > axisMin ? axisMax : _defaultMax;
    final displayMin = axisMax > axisMin ? axisMin : _defaultMin;
    final chartBottom = size.height - _bottomText;
    final eachWidth = (size.width - 2 * _touchPad) / 23.0;
    final span = _valueSpan(displayMax, displayMin);
    final eachHeight = (chartBottom - _top) / span;

    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: WsHealthAppTheme.gluText,
      fontSize: 10.6,
    );

    final labelRight = size.width - _touchPad;
    final topStr = _fmtAxis(displayMax);
    final bottomStr = _fmtAxis(displayMin);
    var topLineEndX = size.width - _touchPad;
    var bottomLineEndX = size.width - _touchPad;
    if (_showYAxis) {
      text.text = TextSpan(text: topStr, style: labelStyle);
      text.layout();
      topLineEndX = labelRight - text.width - _lineLabelGap;
      text.text = TextSpan(text: bottomStr, style: labelStyle);
      text.layout();
      bottomLineEndX = labelRight - text.width - _lineLabelGap;
    }

    final axisPaint = Paint()
      ..color = WsHealthAppTheme.gluHeadLine
      ..strokeWidth = 1;

    if (_showXAxis) {
      final dotY = WsAppChartLayout.xAxisDotY(size.height, _bottomText);
      final labelY = WsAppChartLayout.xAxisLabelY(size.height, _bottomText);
      for (var j = 0; j < 24; j++) {
        if (j == 0) {
          canvas.drawCircle(
            Offset(_touchPad + 1.5, dotY),
            1.5,
            Paint()..color = WsHealthAppTheme.gluText,
          );
        } else if (j == 23) {
          canvas.drawCircle(
            Offset(size.width - _touchPad - 1.5, dotY),
            1.5,
            Paint()..color = WsHealthAppTheme.gluText,
          );
        } else if (j % 4 == 0) {
          final str = '${j.toString().padLeft(2, '0')}:00';
          text.text = TextSpan(text: str, style: labelStyle);
          text.layout();
          final cx = _touchPad + eachWidth * j;
          text.paint(canvas, Offset(cx - text.width / 2, labelY));
        }
      }
    }

    canvas.drawLine(
      Offset(_touchPad, _top),
      Offset(topLineEndX, _top),
      axisPaint,
    );
    canvas.drawLine(
      Offset(_touchPad, chartBottom),
      Offset(bottomLineEndX, chartBottom),
      axisPaint,
    );

    final hasAny = hours.any(
      (h) => h.values.any((v) => v > 0) || h.avg > 0,
    );

    if ((!hasAny || averageRate <= 0) &&
        WsAppChartLayout.showEmptyHint(mode)) {
      text.text = TextSpan(
        text: '暂无血糖',
        style: TextStyle(
          color: WsHealthAppTheme.gluEmpty,
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
      if (_showYAxis) {
        text.text = TextSpan(text: topStr, style: labelStyle);
        text.layout();
        text.paint(canvas, Offset(labelRight - text.width, _top - 12));
        text.text = TextSpan(text: bottomStr, style: labelStyle);
        text.layout();
        text.paint(canvas, Offset(labelRight - text.width, chartBottom - 12));
      }
      return;
    }

    final samplePaint = Paint()
      ..color = WsHealthAppTheme.gluDot
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = WsHealthAppTheme.gluLine
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final holePaint = Paint()
      ..color = WsHealthAppTheme.hrChartBg
      ..style = PaintingStyle.fill;

    for (final h in hours) {
      final pos = h.hour.clamp(0, 23);
      for (final v in h.values) {
        if (v <= 0) continue;
        final p = _point(v, pos, size.width, chartBottom);
        canvas.drawCircle(p, _radius, samplePaint);
      }
    }

    Offset? prev;
    for (final h in hours) {
      if (h.avg <= 0) continue;
      final pos = h.hour.clamp(0, 23);
      final p = _point(h.avg, pos, size.width, chartBottom);
      if (prev != null &&
          (p.dx - prev.dx).abs() <= 1.5 * eachWidth) {
        canvas.drawLine(prev, p, linePaint);
        canvas.drawCircle(prev, _radius, linePaint);
      }
      canvas.drawCircle(p, _radius, linePaint);
      prev = p;
    }

    for (final h in hours) {
      if (h.avg <= 0) continue;
      final pos = h.hour.clamp(0, 23);
      final p = _point(h.avg, pos, size.width, chartBottom);
      canvas.drawCircle(p, 2, holePaint);
    }

    if (_showYAxis && averageRate > axisMin && averageRate < axisMax) {
      final avgY = _top + (displayMax - averageRate) * eachHeight;
      final dash = Paint()
        ..color = WsHealthAppTheme.gluAvgDash
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
      final tag = _fmtAxis(averageRate);
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
      canvas.drawRRect(tagRect, Paint()..color = WsHealthAppTheme.gluAvgDash);
      text.paint(
        canvas,
        Offset(size.width - _touchPad - text.width - 9, avgY - 7),
      );
    }

    if (touchHour >= 0 && touchHour < 24) {
      WsAppGluHourBucket? sel;
      for (final h in hours) {
        if (h.hour == touchHour && h.avg > 0) {
          sel = h;
          break;
        }
      }
      if (sel != null) {
        final point = _point(sel.avg, touchHour, size.width, chartBottom);
        final x = _touchPad + touchHour * eachWidth;
        final thumb = Paint()..color = WsHealthAppTheme.gluThumbBg;
        canvas.drawLine(Offset(x, 0), Offset(x, point.dy - 4), thumb);
        canvas.drawLine(Offset(x, point.dy + 4), Offset(x, chartBottom), thumb);
        canvas.drawCircle(
          point,
          1,
          Paint()..color = WsHealthAppTheme.gluBuoy,
        );
      }
    }

    if (_showYAxis) {
      text.text = TextSpan(text: topStr, style: labelStyle);
      text.layout();
      text.paint(canvas, Offset(labelRight - text.width, _top - 12));
      text.text = TextSpan(text: bottomStr, style: labelStyle);
      text.layout();
      text.paint(canvas, Offset(labelRight - text.width, chartBottom - 12));
    }
  }

  @override
  bool shouldRepaint(covariant _GluPainter oldDelegate) =>
      oldDelegate.hours != hours ||
      oldDelegate.axisMax != axisMax ||
      oldDelegate.axisMin != axisMin ||
      oldDelegate.averageRate != averageRate ||
      oldDelegate.touchHour != touchHour ||
      oldDelegate.mode != mode;
}
