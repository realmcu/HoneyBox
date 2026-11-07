import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'jw_app_chart_models.dart';
import 'jw_health_app_theme.dart';

final class JwAppStepTouchSelection {
  const JwAppStepTouchSelection({
    required this.index,
    required this.begin,
    required this.end,
    required this.steps,
    required this.kcal,
    required this.anchorX,
  });

  final int index;
  final DateTime begin;
  final DateTime end;
  final int steps;
  final int kcal;
  final double anchorX;
}

/// 对齐 Android `StepTouchView`（半小时 48 柱 + 长按选中）。
class JwAppStepTouchChart extends StatefulWidget {
  const JwAppStepTouchChart({
    super.key,
    required this.slots,
    required this.maxSteps,
    required this.onSelection,
  });

  final List<JwAppStepSlot> slots;
  final int maxSteps;
  final ValueChanged<JwAppStepTouchSelection?> onSelection;

  @override
  State<JwAppStepTouchChart> createState() => _JwAppStepTouchChartState();
}

class _JwAppStepTouchChartState extends State<JwAppStepTouchChart>
    with SingleTickerProviderStateMixin {
  static const _count = 48;
  int _curIndex = -1;
  int _downIndex = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  late final AnimationController _grow;
  Offset? _downPos;

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant JwAppStepTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSlots(oldWidget.slots, widget.slots)) {
      // 禁止在 build/update 同步回调父级 setState。
      _delay?.cancel();
      _curIndex = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection(null);
      });
      _grow.forward(from: 0);
    }
  }

  bool _sameSlots(List<JwAppStepSlot> a, List<JwAppStepSlot> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].index != b[i].index ||
          a[i].steps != b[i].steps ||
          a[i].kcal != b[i].kcal) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _delay?.cancel();
    _grow.dispose();
    super.dispose();
  }

  void _clearSelection() {
    _delay?.cancel();
    final had = _curIndex != -1;
    _curIndex = -1;
    _armed = false;
    _tracking = false;
    if (had && mounted) setState(() {});
    widget.onSelection(null);
  }

  void _emit(int index, double width) {
    final slot = widget.slots.firstWhere(
      (e) => e.index == index,
      orElse: () => JwAppStepSlot(
        index: index,
        time: DateTime.now(),
        steps: 0,
        kcal: 0,
      ),
    );
    final eachWidth = 4.0;
    final eachPadding = (width - eachWidth * _count) / (_count - 1);
    final anchorX = (index + 0.5) * eachWidth + index * eachPadding;
    widget.onSelection(
      JwAppStepTouchSelection(
        index: index,
        begin: slot.time,
        end: slot.time.add(const Duration(minutes: 30)),
        steps: slot.steps,
        kcal: slot.kcal,
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
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            _delay?.cancel();
            _armed = true;
            _tracking = false;
            _downPos = d.localPosition;
            final eachWidth = 4.0;
            final eachPadding = (width - eachWidth * _count) / (_count - 1);
            final slot = eachWidth + eachPadding;
            _downIndex =
                (d.localPosition.dx / slot).floor().clamp(0, _count - 1);
            _delay = Timer(JwHealthAppTheme.chartTouchDelay, () {
              if (!mounted || !_armed) return;
              setState(() {
                _tracking = true;
                _curIndex = _downIndex;
              });
              _emit(_curIndex, width);
            });
          },
          onPanUpdate: (d) {
            final down = _downPos;
            if (down == null) return;
            final dx = (d.localPosition.dx - down.dx).abs();
            final dy = (d.localPosition.dy - down.dy).abs();
            if (!_tracking && dx > 12 && dx > dy) {
              _clearSelection();
              return;
            }
            if (!_tracking) return;
            final eachWidth = 4.0;
            final eachPadding = (width - eachWidth * _count) / (_count - 1);
            final slot = eachWidth + eachPadding;
            final index =
                (d.localPosition.dx / slot).floor().clamp(0, _count - 1);
            if (index != _curIndex) {
              setState(() => _curIndex = index);
              _emit(index, width);
            }
          },
          onPanEnd: (_) => _clearSelection(),
          onPanCancel: _clearSelection,
          child: AnimatedBuilder(
            animation: _grow,
            builder: (context, _) {
              final visibleMax =
                  math.max(1, (widget.maxSteps * _grow.value).round());
              return CustomPaint(
                size: Size(width, height),
                painter: _StepPainter(
                  slots: widget.slots,
                  maxSteps: widget.maxSteps,
                  visibleMax: visibleMax,
                  curIndex: _curIndex,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StepPainter extends CustomPainter {
  _StepPainter({
    required this.slots,
    required this.maxSteps,
    required this.visibleMax,
    required this.curIndex,
  });

  final List<JwAppStepSlot> slots;
  final int maxSteps;
  final int visibleMax;
  final int curIndex;

  static const _count = 48;
  static const _eachWidth = 4.0;
  static const _topHeight = 19.0;
  static const _textHeight = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final eachPadding = (size.width - _eachWidth * _count) / (_count - 1);
    final chartBottom = size.height - _textHeight;
    final eachHeight = (chartBottom - _topHeight) / maxSteps;

    final track = Paint()
      ..color = JwHealthAppTheme.stepTrack
      ..strokeWidth = _eachWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: JwHealthAppTheme.stepLabel,
      fontSize: 10.6,
    );

    if (curIndex < 0) {
      final maxLabel = '$maxSteps';
      text.text = TextSpan(
        text: maxLabel,
        style: const TextStyle(
          color: JwHealthAppTheme.stepThumb,
          fontSize: 11.5,
        ),
      );
      text.layout();
      text.paint(canvas, Offset(size.width - text.width, 2));
    }

    for (var i = 0; i < _count; i++) {
      final x = (i + 0.5) * _eachWidth + i * eachPadding;
      canvas.drawLine(
        Offset(x, _topHeight + _eachWidth / 2),
        Offset(x, chartBottom - _eachWidth / 2),
        track,
      );
      if (i == 0 || i == _count - 1) {
        canvas.drawCircle(
          Offset(x, chartBottom + 20),
          1.5,
          Paint()..color = JwHealthAppTheme.stepLabel,
        );
      } else if (i % 8 == 0) {
        final hour = i ~/ 2;
        final str = '${hour.toString().padLeft(2, '0')}:00';
        text.text = TextSpan(text: str, style: labelStyle);
        text.layout();
        text.paint(canvas, Offset(x - text.width / 2, chartBottom + 10));
      }
    }

    var total = 0;
    for (final slot in slots) {
      total += slot.steps;
      if (slot.steps <= 0) continue;
      final pos = slot.index;
      var step = math.min(slot.steps, visibleMax);
      var top = _topHeight + (maxSteps - step) * eachHeight + _eachWidth / 2;
      final bottom = chartBottom - _eachWidth / 2;
      if (top < _topHeight + _eachWidth / 2) top = _topHeight + _eachWidth / 2;
      if (top > bottom) top = bottom - 1;
      final x = (pos + 0.5) * _eachWidth + pos * eachPadding;
      final paint = Paint()
        ..strokeWidth = _eachWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      if (pos == curIndex) {
        paint.color = JwHealthAppTheme.stepBegin;
      } else {
        paint.shader = ui.Gradient.linear(
          Offset(x, _topHeight),
          Offset(x, bottom),
          const [JwHealthAppTheme.stepBegin, JwHealthAppTheme.stepEnd],
        );
      }
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    if (total <= 0) {
      text.text = const TextSpan(
        text: '暂无步数',
        style: TextStyle(color: JwHealthAppTheme.stepEmpty, fontSize: 23),
      );
      text.layout();
      text.paint(
        canvas,
        Offset(
          (size.width - text.width) / 2,
          _topHeight + (chartBottom - _topHeight) / 2 - 8,
        ),
      );
      return;
    }

    if (curIndex >= 0) {
      final x = (curIndex + 0.5) * _eachWidth + curIndex * eachPadding;
      JwAppStepSlot? slot;
      for (final s in slots) {
        if (s.index == curIndex) {
          slot = s;
          break;
        }
      }
      var topLineEnd = chartBottom;
      if (slot != null && slot.steps > 0) {
        topLineEnd =
            _topHeight + (maxSteps - slot.steps) * eachHeight + _eachWidth / 2;
      }
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, math.max(0, topLineEnd - _eachWidth / 2 - 1)),
        Paint()
          ..color = JwHealthAppTheme.stepThumbBg
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StepPainter oldDelegate) =>
      oldDelegate.slots != slots ||
      oldDelegate.maxSteps != maxSteps ||
      oldDelegate.visibleMax != visibleMax ||
      oldDelegate.curIndex != curIndex;
}
