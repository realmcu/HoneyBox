import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ws_app_chart_layout.dart';
import 'ws_app_chart_models.dart';
import 'ws_health_app_theme.dart';

final class WsAppStepTouchSelection {
  const WsAppStepTouchSelection({
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
class WsAppStepTouchChart extends StatefulWidget {
  const WsAppStepTouchChart({
    super.key,
    required this.slots,
    required this.maxSteps,
    this.onSelection,
    this.mode = WsAppChartMode.detail,
  });

  final List<WsAppStepSlot> slots;
  final int maxSteps;
  final ValueChanged<WsAppStepTouchSelection?>? onSelection;
  final WsAppChartMode mode;

  @override
  State<WsAppStepTouchChart> createState() => _JwAppStepTouchChartState();
}

class _JwAppStepTouchChartState extends State<WsAppStepTouchChart>
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
  void didUpdateWidget(covariant WsAppStepTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSlots(oldWidget.slots, widget.slots)) {
      // 禁止在 build/update 同步回调父级 setState。
      _delay?.cancel();
      _curIndex = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection?.call(null);
      });
      _grow.forward(from: 0);
    }
  }

  bool _sameSlots(List<WsAppStepSlot> a, List<WsAppStepSlot> b) {
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
    widget.onSelection?.call(null);
  }

  void _emit(int index, double width) {
    final slot = widget.slots.firstWhere(
      (e) => e.index == index,
      orElse: () => WsAppStepSlot(
        index: index,
        time: DateTime.now(),
        steps: 0,
        kcal: 0,
      ),
    );
    final eachWidth = 4.0;
    final eachPadding = (width - eachWidth * _count) / (_count - 1);
    final anchorX = (index + 0.5) * eachWidth + index * eachPadding;
    widget.onSelection?.call(
      WsAppStepTouchSelection(
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
    final interactive = WsAppChartLayout.interactive(widget.mode);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        Widget paintChild(Animation<double>? grow) {
          final visibleMax = grow == null
              ? widget.maxSteps
              : math.max(1, (widget.maxSteps * grow.value).round());
          return CustomPaint(
            size: Size(width, height),
            painter: _StepPainter(
              slots: widget.slots,
              maxSteps: widget.maxSteps,
              visibleMax: visibleMax,
              curIndex: interactive ? _curIndex : -1,
              mode: widget.mode,
            ),
          );
        }

        if (!interactive) {
          return paintChild(null);
        }

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
            _delay = Timer(WsHealthAppTheme.chartTouchDelay, () {
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
            builder: (context, _) => paintChild(_grow),
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
    required this.mode,
  });

  final List<WsAppStepSlot> slots;
  final int maxSteps;
  final int visibleMax;
  final int curIndex;
  final WsAppChartMode mode;

  static const _count = 48;
  static const _eachWidth = 4.0;

  double get _topHeight => WsAppChartLayout.top(mode);

  double get _textHeight => WsAppChartLayout.bottomText(mode, detail: 30);

  bool get _showYAxis => WsAppChartLayout.showYAxis(mode);

  bool get _showXAxis => WsAppChartLayout.showXAxis(mode);

  @override
  void paint(Canvas canvas, Size size) {
    final eachPadding = (size.width - _eachWidth * _count) / (_count - 1);
    final chartBottom = size.height - _textHeight;
    final eachHeight = (chartBottom - _topHeight) / maxSteps;

    final track = Paint()
      ..color = WsHealthAppTheme.stepTrack
      ..strokeWidth = _eachWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: WsHealthAppTheme.stepLabel,
      fontSize: 10.6,
    );

    if (_showYAxis && curIndex < 0) {
      final maxLabel = '$maxSteps';
      text.text = TextSpan(
        text: maxLabel,
        style: const TextStyle(
          color: WsHealthAppTheme.stepThumb,
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
      if (_showXAxis) {
        final dotY = mode == WsAppChartMode.home
            ? WsAppChartLayout.xAxisDotY(size.height, _textHeight)
            : chartBottom + 20;
        final labelY = mode == WsAppChartMode.home
            ? WsAppChartLayout.xAxisLabelY(size.height, _textHeight)
            : chartBottom + 10;
        if (i == 0 || i == _count - 1) {
          canvas.drawCircle(
            Offset(x, dotY),
            1.5,
            Paint()..color = WsHealthAppTheme.stepLabel,
          );
        } else if (i % 8 == 0) {
          final hour = i ~/ 2;
          final str = '${hour.toString().padLeft(2, '0')}:00';
          text.text = TextSpan(text: str, style: labelStyle);
          text.layout();
          text.paint(canvas, Offset(x - text.width / 2, labelY));
        }
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
        paint.color = WsHealthAppTheme.stepBegin;
      } else {
        paint.shader = ui.Gradient.linear(
          Offset(x, _topHeight),
          Offset(x, bottom),
          const [WsHealthAppTheme.stepBegin, WsHealthAppTheme.stepEnd],
        );
      }
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    if (total <= 0 && WsAppChartLayout.showEmptyHint(mode)) {
      text.text = TextSpan(
        text: '暂无步数',
        style: TextStyle(
          color: WsHealthAppTheme.stepEmpty,
          fontSize: WsAppChartLayout.emptyHintFontSize(mode),
        ),
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
      WsAppStepSlot? slot;
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
          ..color = WsHealthAppTheme.stepThumbBg
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StepPainter oldDelegate) =>
      oldDelegate.slots != slots ||
      oldDelegate.maxSteps != maxSteps ||
      oldDelegate.visibleMax != visibleMax ||
      oldDelegate.curIndex != curIndex ||
      oldDelegate.mode != mode;
}
