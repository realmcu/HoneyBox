import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'jw_app_chart_models.dart';
import 'jw_health_app_theme.dart';

final class JwAppSpo2TouchSelection {
  const JwAppSpo2TouchSelection({
    required this.max,
    required this.min,
    required this.begin,
    required this.end,
    required this.anchorX,
  });

  final int max;
  final int min;
  final DateTime begin;
  final DateTime end;
  final double anchorX;
}

/// 对齐 Android `Spo2TouchView2`（24 槽 min-max 竖向范围 + 圆点）。
class JwAppSpo2TouchChart extends StatefulWidget {
  const JwAppSpo2TouchChart({
    super.key,
    required this.hours,
    required this.onSelection,
  });

  final List<JwAppSpo2HourBucket> hours;
  final ValueChanged<JwAppSpo2TouchSelection?> onSelection;

  @override
  State<JwAppSpo2TouchChart> createState() => _JwAppSpo2TouchChartState();
}

class _JwAppSpo2TouchChartState extends State<JwAppSpo2TouchChart> {
  static const int _axisMax = 100;
  static const int _axisMin = 85;

  static const double _leftPad = 0;
  static const double _itemW = 7;

  int _touchSlot = -1;
  int _downSlot = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  double _itemPadding(double width) {
    return ((width - 2 * _leftPad) / 24 - _itemW) / 2;
  }

  double _slotCenterX(int slot, double width) {
    final pad = _itemPadding(width);
    return _leftPad + _itemW / 2 + pad + (_itemW + 2 * pad) * slot;
  }

  int _findDataPositionByX(double x, double width) {
    final pad = _itemPadding(width);
    final step = _itemW + 2 * pad;
    var slot = (x / step).floor();
    if (slot < 0) slot = 0;
    if (slot > 23) slot = 23;
    if (slot >= widget.hours.length) return -1;
    final h = widget.hours[slot];
    if (!_hasDrawableData(h)) return -1;
    return slot;
  }

  bool _hasDrawableData(JwAppSpo2HourBucket h) {
    return h.maxValue > 0 && h.minValue > 0;
  }

  @override
  void didUpdateWidget(covariant JwAppSpo2TouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameHours(oldWidget.hours, widget.hours)) {
      _delay?.cancel();
      _touchSlot = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection(null);
      });
    }
  }

  bool _sameHours(List<JwAppSpo2HourBucket> a, List<JwAppSpo2HourBucket> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hour != b[i].hour ||
          a[i].maxValue != b[i].maxValue ||
          a[i].minValue != b[i].minValue ||
          a[i].values.length != b[i].values.length) {
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
    final had = _touchSlot != -1;
    _touchSlot = -1;
    _armed = false;
    _tracking = false;
    if (had && mounted) setState(() {});
    widget.onSelection(null);
  }

  JwAppSpo2HourBucket _bucket(int slot) {
    return widget.hours.firstWhere(
      (e) => e.hour == slot,
      orElse: () => JwAppSpo2HourBucket(
        hour: slot,
        startTime: DateTime.now(),
        values: const [],
        maxValue: 0,
        minValue: 0,
      ),
    );
  }

  void _emit(int slot, double width) {
    final h = _bucket(slot);
    widget.onSelection(
      JwAppSpo2TouchSelection(
        max: h.maxValue,
        min: h.minValue,
        begin: h.startTime,
        end: h.startTime.add(const Duration(hours: 1)),
        anchorX: _slotCenterX(slot, width),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final pad = _itemPadding(width);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            _delay?.cancel();
            _downSlot = _findDataPositionByX(d.localPosition.dx, width);
            if (_downSlot < 0) return;
            _armed = true;
            _tracking = false;
            _downPos = d.localPosition;
            _delay = Timer(JwHealthAppTheme.chartTouchDelay, () {
              if (!mounted || !_armed) return;
              if (_downSlot < 0 || !_hasDrawableData(_bucket(_downSlot))) {
                return;
              }
              setState(() {
                _tracking = true;
                _touchSlot = _downSlot;
              });
              _emit(_touchSlot, width);
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
            final cur = _findDataPositionByX(d.localPosition.dx, width);
            if (cur >= 0 && cur != _touchSlot) {
              setState(() => _touchSlot = cur);
              _emit(cur, width);
            }
          },
          onPanEnd: (_) => _clear(),
          onPanCancel: _clear,
          child: CustomPaint(
            size: Size(width, height),
            painter: _Spo2Painter(
              hours: widget.hours,
              axisMax: _axisMax,
              axisMin: _axisMin,
              touchSlot: _touchSlot,
              itemPadding: pad,
              slotCenterX: _slotCenterX,
            ),
          ),
        );
      },
    );
  }
}

class _Spo2Painter extends CustomPainter {
  _Spo2Painter({
    required this.hours,
    required this.axisMax,
    required this.axisMin,
    required this.touchSlot,
    required this.itemPadding,
    required this.slotCenterX,
  });

  final List<JwAppSpo2HourBucket> hours;
  final int axisMax;
  final int axisMin;
  final int touchSlot;
  final double itemPadding;
  final double Function(int slot, double width) slotCenterX;

  static const double _top = 19;
  static const double _bottomText = 20;
  static const double _leftPad = 0;
  static const double _radius = 3.5;
  static const double _labelPadRight = 5;
  static const double _plotTop = _top + _radius;

  int get _chartRange => axisMax - axisMin;

  double _mapY(int value, double height) {
    final safe = value.clamp(axisMin, axisMax).toInt();
    final axisBottom = height - _bottomText;
    final plotBottom = axisBottom - _radius;
    final plotH = plotBottom - _plotTop;
    if (plotH <= 0) return _top;
    return _plotTop + (axisMax - safe) * (plotH / _chartRange);
  }

  bool _hasData(JwAppSpo2HourBucket h) =>
      h.maxValue > 0 && h.minValue > 0;

  @override
  void paint(Canvas canvas, Size size) {
    const labelStyle = TextStyle(
      color: JwHealthAppTheme.spo2Text,
      fontSize: 10.6,
    );
    final text = TextPainter(textDirection: ui.TextDirection.ltr);

    const topStr = '100';
    const botStr = '85';
    text.text = const TextSpan(text: topStr, style: labelStyle);
    text.layout();
    final topW = text.width;
    text.text = const TextSpan(text: botStr, style: labelStyle);
    text.layout();
    final botW = text.width;
    final labelRight = size.width - _labelPadRight;
    final topLineEndX = labelRight - topW - 5;
    final bottomLineEndX = labelRight - botW - 5;

    final linePaint = Paint()
      ..color = JwHealthAppTheme.spo2HeadLine
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, _top), Offset(topLineEndX, _top), linePaint);
    canvas.drawLine(
      Offset(0, size.height - _bottomText),
      Offset(bottomLineEndX, size.height - _bottomText),
      linePaint,
    );

    for (var hour = 0; hour < 24; hour++) {
      final cx = slotCenterX(hour, size.width);
      if (hour == 0) {
        canvas.drawCircle(
          Offset(
            _leftPad + itemPadding,
            size.height - _Spo2Painter._bottomText / 2 + 4,
          ),
          1.5,
          Paint()..color = JwHealthAppTheme.spo2Text,
        );
      } else if (hour == 23) {
        canvas.drawCircle(
          Offset(
            size.width - _leftPad - itemPadding,
            size.height - _bottomText / 2 + 4,
          ),
          1.5,
          Paint()..color = JwHealthAppTheme.spo2Text,
        );
      } else if (hour % 4 == 0) {
        final str = '${hour.toString().padLeft(2, '0')}:00';
        text.text = TextSpan(text: str, style: labelStyle);
        text.layout();
        text.paint(
          canvas,
          Offset(
            cx - text.width / 2,
            size.height - _bottomText / 2 + 8,
          ),
        );
      }
    }

    var hasData = false;
    final fill = Paint()
      ..color = JwHealthAppTheme.spo2Value
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var i = 0; i < hours.length && i < 24; i++) {
      final h = hours[i];
      if (!_hasData(h)) continue;
      hasData = true;
      final cx = slotCenterX(h.hour, size.width);
      final yHi = _mapY(h.maxValue, size.height);
      final yLo = _mapY(h.minValue, size.height);
      if (h.maxValue == h.minValue) {
        canvas.drawCircle(Offset(cx, yHi), _radius, fill);
      } else {
        var barTop = yHi + _radius;
        var barBottom = yLo - _radius;
        if (barBottom - barTop <= _radius * 2) {
          canvas.drawCircle(
            Offset(cx, (yHi + yLo) / 2),
            _radius,
            fill,
          );
        } else {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - _radius, barTop, cx + _radius, barBottom),
            const Radius.circular(_radius),
          );
          canvas.drawRRect(rect, fill);
        }
      }

      if (i == touchSlot && _hasData(h)) {
        final thumb = Paint()
          ..color = JwHealthAppTheme.spo2ThumbBg
          ..strokeWidth = 1;
        canvas.drawLine(
          Offset(cx, 0),
          Offset(cx, yHi - _radius - 1),
          thumb,
        );
        canvas.drawLine(
          Offset(cx, yLo + _radius + 1),
          Offset(cx, size.height - _bottomText),
          thumb,
        );
      }
    }

    if (!hasData) {
      text.text = const TextSpan(
        text: '暂无血氧',
        style: TextStyle(color: JwHealthAppTheme.spo2Empty, fontSize: 23),
      );
      text.layout();
      text.paint(
        canvas,
        Offset(
          (size.width - text.width) / 2,
          _top + (size.height - _top - _bottomText) / 2 - 8,
        ),
      );
    }

    const labelDy = 12.0;
    text.text = const TextSpan(text: topStr, style: labelStyle);
    text.layout();
    text.paint(canvas, Offset(labelRight - topW, _top - labelDy));

    text.text = const TextSpan(text: botStr, style: labelStyle);
    text.layout();
    text.paint(
      canvas,
      Offset(labelRight - botW, size.height - _bottomText - labelDy),
    );
  }

  @override
  bool shouldRepaint(covariant _Spo2Painter oldDelegate) =>
      oldDelegate.hours != hours ||
      oldDelegate.touchSlot != touchSlot ||
      oldDelegate.itemPadding != itemPadding;
}
