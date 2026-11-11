import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ws_app_chart_layout.dart';
import 'ws_app_chart_models.dart';
import 'ws_health_app_theme.dart';

final class WsAppPressureTouchSelection {
  const WsAppPressureTouchSelection({
    required this.index,
    required this.begin,
    required this.end,
    required this.avg,
    required this.max,
    required this.min,
    required this.anchorX,
  });

  final int index;
  final DateTime begin;
  final DateTime end;
  final int avg;
  final int max;
  final int min;
  final double anchorX;
}

/// 对齐 Android `PressureTouchView3`：144 个 10 分钟槽、按档位着色、选中竖条半透明。
class WsAppPressureTouchChart extends StatefulWidget {
  const WsAppPressureTouchChart({
    super.key,
    required this.slots,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    this.onSelection,
    this.mode = WsAppChartMode.detail,
  });

  final List<WsAppPressureSlot> slots;
  final int axisMax;
  final int axisMin;
  final int averageRate;
  final ValueChanged<WsAppPressureTouchSelection?>? onSelection;
  final WsAppChartMode mode;

  @override
  State<WsAppPressureTouchChart> createState() =>
      _JwAppPressureTouchChartState();
}

class _JwAppPressureTouchChartState extends State<WsAppPressureTouchChart> {
  static const _groupCount = 144;
  static const _touchPad = 5.0;
  static const _barRatio = 4.0;
  static const _spaceRatio = 1.0;

  int _touchPos = -1;
  int _downPos = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downOffset;

  @override
  void didUpdateWidget(covariant WsAppPressureTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSlots(oldWidget.slots, widget.slots) ||
        oldWidget.axisMax != widget.axisMax ||
        oldWidget.axisMin != widget.axisMin ||
        oldWidget.averageRate != widget.averageRate) {
      _delay?.cancel();
      _touchPos = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection?.call(null);
      });
    }
  }

  bool _sameSlots(List<WsAppPressureSlot> a, List<WsAppPressureSlot> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].index != b[i].index ||
          a[i].avg != b[i].avg ||
          a[i].max != b[i].max ||
          a[i].min != b[i].min) {
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
    final had = _touchPos != -1;
    _touchPos = -1;
    _armed = false;
    _tracking = false;
    if (had && mounted) setState(() {});
    widget.onSelection?.call(null);
  }

  double _eachWidth(double width) {
    return (width - 2 * _touchPad) / _groupCount;
  }

  double _barWidth(double eachWidth) {
    final ratioSum = _barRatio + _spaceRatio;
    return eachWidth * _barRatio / ratioSum;
  }

  int _indexFromDx(double dx, double width) {
    final each = _eachWidth(width);
    final x = dx - _touchPad;
    final i = (x / each).floor();
    return i.clamp(0, _groupCount - 1);
  }

  void _emit(int index, double width) {
    if (index < 0 || index >= widget.slots.length) {
      widget.onSelection?.call(null);
      return;
    }
    final s = widget.slots[index];
    if (s.avg <= 0) {
      widget.onSelection?.call(null);
      return;
    }
    final each = _eachWidth(width);
    final barW = _barWidth(each);
    final barL = _touchPad + index * each;
    final anchorX = barL + barW / 2;
    widget.onSelection?.call(
      WsAppPressureTouchSelection(
        index: index,
        begin: s.time,
        end: s.time.add(const Duration(minutes: 10)),
        avg: s.avg,
        max: s.max,
        min: s.min,
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
          painter: _PressurePainter(
            slots: widget.slots,
            axisMax: widget.axisMax,
            axisMin: widget.axisMin,
            averageRate: widget.averageRate,
            touchPos: interactive ? _touchPos : -1,
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
            _downOffset = d.localPosition;
            _downPos = _indexFromDx(d.localPosition.dx, width);
            if (_downPos != _touchPos) {
              _delay = Timer(WsHealthAppTheme.chartTouchDelay, () {
                if (!mounted || !_armed) return;
                setState(() {
                  _tracking = true;
                  _touchPos = _downPos;
                });
                _emit(_touchPos, width);
              });
            }
          },
          onPanUpdate: (d) {
            final down = _downOffset;
            if (down == null) return;
            final dx = (d.localPosition.dx - down.dx).abs();
            final dy = (d.localPosition.dy - down.dy).abs();
            if (!_tracking && dx > 12 && dx > dy) {
              _clear();
              return;
            }
            if (!_tracking) return;
            final cur = _indexFromDx(d.localPosition.dx, width);
            if (cur == _downPos || cur == _touchPos) {
              return;
            }
            if (_tracking) {
              setState(() {
                _touchPos = cur;
              });
              _emit(cur, width);
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

class _PressurePainter extends CustomPainter {
  _PressurePainter({
    required this.slots,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    required this.touchPos,
    required this.mode,
  });

  final List<WsAppPressureSlot> slots;
  final int axisMax;
  final int axisMin;
  final int averageRate;
  final int touchPos;
  final WsAppChartMode mode;

  double get _top => WsAppChartLayout.top(mode);

  double get _bottomText => WsAppChartLayout.bottomText(mode, detail: 20);

  bool get _showYAxis => WsAppChartLayout.showYAxis(mode);

  bool get _showXAxis => WsAppChartLayout.showXAxis(mode);
  static const _touchPad = 5.0;
  static const _groupCount = 144;
  static const _barRatio = 4.0;
  static const _spaceRatio = 1.0;
  static const _lineLabelGap = 5.0;

  Color _barColor(int value) {
    if (value <= 29) return WsHealthAppTheme.pressureLow;
    if (value <= 59) return WsHealthAppTheme.pressureNormal;
    if (value <= 79) return WsHealthAppTheme.pressureMedium;
    return WsHealthAppTheme.pressureHigh;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final displayMin = axisMin;
    final displayMax = axisMax > axisMin ? axisMax : 100;
    final valueRange = (displayMax - displayMin).clamp(1, 1 << 30);
    final chartH = size.height - _top - _bottomText;
    final eachWidth = (size.width - 2 * _touchPad) / _groupCount;
    final ratioSum = _barRatio + _spaceRatio;
    final barWidth = eachWidth * _barRatio / ratioSum;
    final chartBottom = size.height - _bottomText;

    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: WsHealthAppTheme.pressureText,
      fontSize: 10.6,
    );

    final labelRight = size.width - _touchPad;
    final topStr = '$displayMax';
    final bottomStr = '$displayMin';
    var topLineEndX = size.width;
    var bottomLineEndX = size.width;
    if (_showYAxis) {
      text.text = TextSpan(text: topStr, style: labelStyle);
      text.layout();
      topLineEndX = labelRight - text.width - _lineLabelGap;
      text.text = TextSpan(text: bottomStr, style: labelStyle);
      text.layout();
      bottomLineEndX = labelRight - text.width - _lineLabelGap;
    }

    final axisPaint = Paint()
      ..color = WsHealthAppTheme.pressureHeadLine
      ..strokeWidth = 1;

    if (_showXAxis) {
      const labelHours = [0, 6, 12, 18, 24];
      final ly = WsAppChartLayout.xAxisLabelY(size.height, _bottomText);
      for (final h in labelHours) {
      final label = '${h.toString().padLeft(2, '0')}:00';
      text.text = TextSpan(text: label, style: labelStyle);
      text.layout();
      final lx = _touchPad + h * 6 * eachWidth;
      final tw = text.width;
      if (h == 0) {
        text.paint(canvas, Offset(lx, ly));
      } else if (h == 24) {
        text.paint(canvas, Offset(lx - tw, ly));
      } else {
        text.paint(canvas, Offset(lx - tw / 2, ly));
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

    final hasData = averageRate > 0 &&
        slots.isNotEmpty &&
        slots.any((s) => s.avg > 0);

    if (!hasData && WsAppChartLayout.showEmptyHint(mode)) {
      text.text = TextSpan(
        text: '暂无压力',
        style: TextStyle(
          color: WsHealthAppTheme.pressureEmpty,
          fontSize: WsAppChartLayout.emptyHintFontSize(mode),
        ),
      );
      text.layout();
      text.paint(
        canvas,
        Offset(
          (size.width - text.width) / 2,
          _top + chartH / 2 - 8,
        ),
      );
      return;
    }
    if (hasData) {
      final len = slots.length < _groupCount ? slots.length : _groupCount;
      final barPaint = Paint()..isAntiAlias = true;
      for (var i = 0; i < len; i++) {
        final bean = slots[i];
        final value = bean.avg;
        if (value <= 0) continue;
        final v = value.clamp(displayMin, displayMax);
        final barL = _touchPad + i * eachWidth;
        final barR = barL + barWidth;
        final barT = _top + (displayMax - v) * chartH / valueRange;
        final barB = chartBottom;
        barPaint.color = _barColor(value);
        canvas.drawRect(Rect.fromLTRB(barL, barT, barR, barB), barPaint);
      }

      if (touchPos >= 0 && touchPos < len) {
        final bean = slots[touchPos];
        if (bean.avg > 0) {
          final barL = _touchPad + touchPos * eachWidth;
          final barR = barL + barWidth;
          final thumb = Paint()
            ..color = WsHealthAppTheme.pressureThumbBg.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill;
          canvas.drawRect(Rect.fromLTRB(barL, 0, barR, chartBottom), thumb);
        }
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
  bool shouldRepaint(covariant _PressurePainter oldDelegate) =>
      oldDelegate.slots != slots ||
      oldDelegate.axisMax != axisMax ||
      oldDelegate.axisMin != axisMin ||
      oldDelegate.averageRate != averageRate ||
      oldDelegate.touchPos != touchPos ||
      oldDelegate.mode != mode;
}
