import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'jw_app_chart_models.dart';
import 'jw_health_app_theme.dart';

final class JwAppTempTouchSelection {
  const JwAppTempTouchSelection({
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
  final double avg;
  final double max;
  final double min;
  final double anchorX;
}

/// 对齐 Android `TempTouchView`：48 个半小时槽、`~8dp` 柱宽、点值与均值虚线。
class JwAppTempTouchChart extends StatefulWidget {
  const JwAppTempTouchChart({
    super.key,
    required this.slots,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    required this.onSelection,
  });

  final List<JwAppTempSlot> slots;
  final double axisMax;
  final double axisMin;
  final double averageRate;
  final ValueChanged<JwAppTempTouchSelection?> onSelection;

  @override
  State<JwAppTempTouchChart> createState() => _JwAppTempTouchChartState();
}

class _JwAppTempTouchChartState extends State<JwAppTempTouchChart> {
  static const _slotCount = 48;
  static const _leftPadding = 2.0;
  static const _itemWidth = 8.0;

  int _touchIndex = -1;
  int _downIndex = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  @override
  void didUpdateWidget(covariant JwAppTempTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSlots(oldWidget.slots, widget.slots) ||
        oldWidget.axisMax != widget.axisMax ||
        oldWidget.axisMin != widget.axisMin ||
        oldWidget.averageRate != widget.averageRate) {
      _delay?.cancel();
      _touchIndex = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection(null);
      });
    }
  }

  bool _sameSlots(List<JwAppTempSlot> a, List<JwAppTempSlot> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].index != b[i].index ||
          a[i].avg != b[i].avg ||
          a[i].max != b[i].max ||
          a[i].min != b[i].min ||
          a[i].temps.length != b[i].temps.length) {
        return false;
      }
      for (var j = 0; j < a[i].temps.length; j++) {
        if (a[i].temps[j] != b[i].temps[j]) return false;
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
    final had = _touchIndex != -1;
    _touchIndex = -1;
    _armed = false;
    _tracking = false;
    if (had && mounted) setState(() {});
    widget.onSelection(null);
  }

  double _slotPitch(double width) {
    final itemPadding =
        ((width - 2 * _leftPadding) / _slotCount - _itemWidth) / 2.0;
    return _itemWidth + 2 * itemPadding;
  }

  double _slotCenterX(int index, double width) {
    final itemPadding =
        ((width - 2 * _leftPadding) / _slotCount - _itemWidth) / 2.0;
    return _leftPadding +
        _itemWidth / 2 +
        itemPadding +
        index * (_itemWidth + 2 * itemPadding);
  }

  int _indexFromDx(double dx, double width) {
    final pitch = _slotPitch(width);
    final x = dx - _leftPadding;
    final i = (x / pitch).floor();
    return i.clamp(0, _slotCount - 1);
  }

  void _emit(int index, double width) {
    final slot = widget.slots.firstWhere(
      (e) => e.index == index,
      orElse: () => JwAppTempSlot(
        index: index,
        time: DateTime.now(),
        temps: const [],
        avg: 0,
        max: 0,
        min: 0,
      ),
    );
    widget.onSelection(
      JwAppTempTouchSelection(
        index: index,
        begin: slot.time,
        end: slot.time.add(const Duration(minutes: 30)),
        avg: slot.avg,
        max: slot.max,
        min: slot.min,
        anchorX: _slotCenterX(index, width),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            _delay?.cancel();
            _armed = true;
            _tracking = false;
            _downPos = d.localPosition;
            _downIndex = _indexFromDx(d.localPosition.dx, width);
            _delay = Timer(JwHealthAppTheme.chartTouchDelay, () {
              if (!mounted || !_armed) return;
              setState(() {
                _tracking = true;
                _touchIndex = _downIndex;
              });
              _emit(_touchIndex, width);
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
            final index = _indexFromDx(d.localPosition.dx, width);
            if (index != _touchIndex) {
              setState(() => _touchIndex = index);
              _emit(index, width);
            }
          },
          onPanEnd: (_) => _clear(),
          onPanCancel: _clear,
          child: CustomPaint(
            size: Size(width, height),
            painter: _TempPainter(
              slots: widget.slots,
              axisMax: widget.axisMax,
              axisMin: widget.axisMin,
              averageRate: widget.averageRate,
              touchIndex: _touchIndex,
            ),
          ),
        );
      },
    );
  }
}

class _TempPainter extends CustomPainter {
  _TempPainter({
    required this.slots,
    required this.axisMax,
    required this.axisMin,
    required this.averageRate,
    required this.touchIndex,
  });

  final List<JwAppTempSlot> slots;
  final double axisMax;
  final double axisMin;
  final double averageRate;
  final int touchIndex;

  static const _top = 19.0;
  static const _bottomText = 20.0;
  static const _leftPadding = 2.0;
  static const _itemWidth = 8.0;
  static const _radius = 3.5;
  static const _labelRightPad = 5.0;
  static const _lineLabelGap = 5.0;

  double _slotCenterX(int index, double width) {
    final itemPadding =
        ((width - 2 * _leftPadding) / 48 - _itemWidth) / 2.0;
    return _leftPadding +
        _itemWidth / 2 +
        itemPadding +
        index * (_itemWidth + 2 * itemPadding);
  }

  Offset _point(double value, int index, double width, double chartBottom) {
    final range = math.max(0.0001, axisMax - axisMin);
    final h = chartBottom - _top;
    final y = _top + (axisMax - value.clamp(axisMin, axisMax)) * (h / range);
    return Offset(_slotCenterX(index, width), y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartBottom = size.height - _bottomText;
    final range = math.max(0.0001, axisMax - axisMin);
    final itemHeight = (chartBottom - _top) / range;
    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: JwHealthAppTheme.tempText,
      fontSize: 10.6,
    );

    final topStr = axisMax.round().toString();
    final bottomStr = axisMin.round().toString();
    final labelRight = size.width - _labelRightPad;
    text.text = TextSpan(text: topStr, style: labelStyle);
    text.layout();
    final topLineEndX = labelRight - text.width - _lineLabelGap;
    text.text = TextSpan(text: bottomStr, style: labelStyle);
    text.layout();
    final bottomLineEndX = labelRight - text.width - _lineLabelGap;

    final axisPaint = Paint()
      ..color = JwHealthAppTheme.tempLine
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, _top), Offset(topLineEndX, _top), axisPaint);
    canvas.drawLine(
      Offset(0, chartBottom),
      Offset(bottomLineEndX, chartBottom),
      axisPaint,
    );

    for (var i = 0; i < 24; i++) {
      final slotIndex = i * 2;
      final x = _slotCenterX(slotIndex, size.width);
      if (i == 0 || i == 23) {
        canvas.drawCircle(
          Offset(x, size.height - _bottomText / 2 + 4),
          1.5,
          Paint()..color = JwHealthAppTheme.tempText,
        );
      } else if (i % 4 == 0) {
        final str = '${i.toString().padLeft(2, '0')}:00';
        text.text = TextSpan(text: str, style: labelStyle);
        text.layout();
        text.paint(
          canvas,
          Offset(x - text.width / 2, size.height - _bottomText / 2 + 8),
        );
      }
    }

    final hasData = slots.any((s) => s.temps.any((t) => t > 0));
    if (!hasData) {
      text.text = const TextSpan(
        text: '暂无体温',
        style: TextStyle(color: JwHealthAppTheme.tempEmpty, fontSize: 23),
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

    for (final slot in slots) {
      if (slot.temps.isEmpty) continue;
      for (final t in slot.temps) {
        if (t <= 0) continue;
        final dotPaint = Paint()
          ..color =
              t > 37.2 ? JwHealthAppTheme.tempValueHigh : JwHealthAppTheme.tempValue
          ..style = PaintingStyle.fill;
        final p = _point(t, slot.index, size.width, chartBottom);
        canvas.drawCircle(p, _radius, dotPaint);
      }
    }

    if (averageRate > axisMin && averageRate < axisMax) {
      final avgY = _top + (axisMax - averageRate) * itemHeight;
      final dash = Paint()
        ..color = JwHealthAppTheme.tempAvgBg
        ..strokeWidth = 1;
      for (var k = 0; k < (size.width / 3).floor(); k++) {
        if (k.isEven) {
          canvas.drawLine(
            Offset(_leftPadding + k * 3, avgY),
            Offset(_leftPadding + (k + 1) * 3.0, avgY),
            dash,
          );
        }
      }
      final tag = averageRate.toStringAsFixed(1);
      text.text = TextSpan(
        text: tag,
        style: const TextStyle(
          color: JwHealthAppTheme.hrAvgText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      text.layout();
      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width - _labelRightPad - text.width - 16,
          avgY - 10,
          text.width + 14,
          20,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(tagRect, Paint()..color = JwHealthAppTheme.tempAvgBg);
      text.paint(
        canvas,
        Offset(size.width - _labelRightPad - text.width - 9, avgY - 7),
      );
    }

    if (touchIndex >= 0 && touchIndex < 48) {
      JwAppTempSlot? sel;
      for (final s in slots) {
        if (s.index == touchIndex) {
          sel = s;
          break;
        }
      }
      if (sel != null && sel.max > 0 && sel.min > 0) {
        final x = _slotCenterX(touchIndex, size.width);
        final thumb = Paint()..color = JwHealthAppTheme.tempThumbBg;
        final topEnd =
            _top + (axisMax - sel.max) * itemHeight - _radius - 1;
        final bottomStart =
            _top + (axisMax - sel.min) * itemHeight + _radius + 1;
        canvas.drawLine(Offset(x, 0), Offset(x, topEnd), thumb);
        canvas.drawLine(Offset(x, bottomStart), Offset(x, chartBottom), thumb);
      }
    }

    text.text = TextSpan(text: topStr, style: labelStyle);
    text.layout();
    text.paint(canvas, Offset(labelRight - text.width, _top - 12));
    text.text = TextSpan(text: bottomStr, style: labelStyle);
    text.layout();
    text.paint(canvas, Offset(labelRight - text.width, chartBottom - 12));
  }

  @override
  bool shouldRepaint(covariant _TempPainter oldDelegate) =>
      oldDelegate.slots != slots ||
      oldDelegate.axisMax != axisMax ||
      oldDelegate.axisMin != axisMin ||
      oldDelegate.averageRate != averageRate ||
      oldDelegate.touchIndex != touchIndex;
}
