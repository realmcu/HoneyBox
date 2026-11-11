import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ws_app_chart_layout.dart';
import 'ws_app_chart_models.dart';
import 'ws_health_app_theme.dart';

final class WsAppSleepTouchSelection {
  const WsAppSleepTouchSelection({
    required this.begin,
    required this.end,
    required this.appType,
    required this.minutes,
    required this.anchorX,
  });

  final DateTime begin;
  final DateTime end;
  final int appType;
  final int minutes;
  final double anchorX;
}

/// 对齐 Android `SleepTouchView`（精细 10 带：清醒 / 眼动 / 浅睡 / 深睡；长按竖线浮标）。
class WsAppSleepTouchChart extends StatefulWidget {
  const WsAppSleepTouchChart({
    super.key,
    required this.segments,
    this.onSelection,
    this.mode = WsAppChartMode.detail,
  });

  final List<WsAppSleepSegment> segments;
  final ValueChanged<WsAppSleepTouchSelection?>? onSelection;
  final WsAppChartMode mode;

  @override
  State<WsAppSleepTouchChart> createState() => _JwAppSleepTouchChartState();
}

class _JwAppSleepTouchChartState extends State<WsAppSleepTouchChart> {
  static const double _thumbHeight = 10;

  int _segIndex = -1;
  int _downSegIndex = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  @override
  void didUpdateWidget(covariant WsAppSleepTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSegments(oldWidget.segments, widget.segments)) {
      _delay?.cancel();
      _segIndex = -1;
      _armed = false;
      _tracking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelection?.call(null);
      });
    }
  }

  bool _sameSegments(List<WsAppSleepSegment> a, List<WsAppSleepSegment> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].begin != b[i].begin ||
          a[i].end != b[i].end ||
          a[i].appType != b[i].appType ||
          a[i].minutes != b[i].minutes) {
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

  void _clearSelection() {
    _delay?.cancel();
    final had = _segIndex != -1;
    _segIndex = -1;
    _armed = false;
    _tracking = false;
    if (had && mounted) setState(() {});
    widget.onSelection?.call(null);
  }

  List<_SleepLayoutSeg> _layout(double width) {
    final segs = List<WsAppSleepSegment>.from(widget.segments)
      ..sort((a, b) => a.begin.compareTo(b.begin));
    var total = 0;
    for (final s in segs) {
      total += math.max(0, s.minutes);
    }
    if (total <= 0) {
      return const <_SleepLayoutSeg>[];
    }
    final out = <_SleepLayoutSeg>[];
    var x = 0.0;
    for (final s in segs) {
      final m = math.max(0, s.minutes);
      if (m <= 0) continue;
      final w = m / total * width;
      final cx = x + w / 2;
      out.add(_SleepLayoutSeg(segment: s, left: x, width: w, centerX: cx));
      x += w;
    }
    return out;
  }

  int _indexAtDx(double dx, List<_SleepLayoutSeg> layout) {
    if (layout.isEmpty) return -1;
    for (var i = 0; i < layout.length; i++) {
      final L = layout[i];
      if (dx >= L.left && dx < L.left + L.width) return i;
    }
    if (dx < layout.first.left) return 0;
    if (dx >= layout.last.left + layout.last.width) {
      return layout.length - 1;
    }
    return -1;
  }

  void _emit(int index, List<_SleepLayoutSeg> layout) {
    if (index < 0 || index >= layout.length) return;
    final L = layout[index];
    final s = L.segment;
    widget.onSelection?.call(
      WsAppSleepTouchSelection(
        begin: s.begin,
        end: s.end,
        appType: s.appType,
        minutes: s.minutes,
        anchorX: L.centerX,
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
        final layout = _layout(width);
        final paint = CustomPaint(
          size: Size(width, height),
          painter: _SleepPainter(
            segments: widget.segments,
            thumbHeight: _thumbHeight,
            selectedIndex: interactive ? _segIndex : -1,
            layout: layout,
            mode: widget.mode,
          ),
        );
        if (!interactive) return paint;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            if (layout.isEmpty) return;
            _delay?.cancel();
            _armed = true;
            _tracking = false;
            _downPos = d.localPosition;
            _downSegIndex = _indexAtDx(d.localPosition.dx, layout);
            if (_downSegIndex < 0) return;
            _delay = Timer(WsHealthAppTheme.chartTouchDelay, () {
              if (!mounted || !_armed) return;
              setState(() {
                _tracking = true;
                _segIndex = _downSegIndex;
              });
              _emit(_segIndex, layout);
            });
          },
          onPanUpdate: (d) {
            if (layout.isEmpty) return;
            final down = _downPos;
            if (down == null) return;
            final dx = (d.localPosition.dx - down.dx).abs();
            final dy = (d.localPosition.dy - down.dy).abs();
            if (!_tracking && dx > 12 && dx > dy) {
              _clearSelection();
              return;
            }
            if (!_tracking) return;
            final idx = _indexAtDx(d.localPosition.dx, layout);
            if (idx >= 0 && idx != _segIndex) {
              setState(() => _segIndex = idx);
              _emit(idx, layout);
            }
          },
          onPanEnd: (_) => _clearSelection(),
          onPanCancel: _clearSelection,
          child: paint,
        );
      },
    );
  }
}

final class _SleepLayoutSeg {
  const _SleepLayoutSeg({
    required this.segment,
    required this.left,
    required this.width,
    required this.centerX,
  });

  final WsAppSleepSegment segment;
  final double left;
  final double width;
  final double centerX;
}

class _SleepPainter extends CustomPainter {
  _SleepPainter({
    required this.segments,
    required this.thumbHeight,
    required this.selectedIndex,
    required this.layout,
    required this.mode,
  });

  final List<WsAppSleepSegment> segments;
  final double thumbHeight;
  final int selectedIndex;
  final List<_SleepLayoutSeg> layout;
  final WsAppChartMode mode;

  bool get _showYAxis => WsAppChartLayout.showYAxis(mode);

  bool get _showXAxis => WsAppChartLayout.showXAxis(mode);

  @override
  void paint(Canvas canvas, Size size) {
    // 与 Android SleepTouchView 一致：直角条（Paint 默认 Cap.BUTT），并裁切避免越界。
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final totalM = segments.fold<int>(0, (a, s) => a + math.max(0, s.minutes));
    if (segments.isEmpty || totalM <= 0) {
      if (WsAppChartLayout.showEmptyHint(mode)) {
        text.text = TextSpan(
          text: '暂无睡眠',
          style: TextStyle(
            color: WsHealthAppTheme.sleepEmpty,
            fontSize: WsAppChartLayout.emptyHintFontSize(mode),
          ),
        );
        text.layout();
        text.paint(
          canvas,
          Offset(
            (size.width - text.width) / 2,
            thumbHeight + (size.height - thumbHeight) / 2 - 8,
          ),
        );
      }
      canvas.restore();
      return;
    }

    final eh = (size.height - thumbHeight) / 10.0;
    final b = thumbHeight;
    // 与 SleepTouchView type==2（精细）一致
    final awakeTop = b;
    final awakeBottom = b + 2.5 * eh;
    final remTop = awakeBottom;
    final remBottom = b + 5.0 * eh;
    final lightTop = remBottom;
    final lightBottom = b + 7.5 * eh;
    final deepTop = lightBottom;
    final deepBottom = size.height;

    double bandTop(int appType) {
      return switch (appType) {
        0 => deepTop,
        1 => lightTop,
        2 || 3 => remTop,
        4 => awakeTop,
        _ => lightTop,
      };
    }

    double bandBottom(int appType) {
      return switch (appType) {
        0 => deepBottom,
        1 => lightBottom,
        2 || 3 => remBottom,
        4 => awakeBottom,
        _ => lightBottom,
      };
    }

    Color colorFor(int appType) {
      return switch (appType) {
        0 => WsHealthAppTheme.sleepDeep,
        1 => WsHealthAppTheme.sleepLight,
        2 || 3 => WsHealthAppTheme.sleepRem,
        4 => WsHealthAppTheme.sleepAwake,
        _ => WsHealthAppTheme.sleepLight,
      };
    }

    for (var i = 0; i < layout.length; i++) {
      final L = layout[i];
      final s = L.segment;
      // 用矩形画直角条，避免 strokeCap.round 圆头溢出 view。
      final top = bandTop(s.appType);
      final bot = bandBottom(s.appType);
      final rect = Rect.fromLTRB(L.left, top, L.left + L.width, bot);
      canvas.drawRect(rect, Paint()..color = colorFor(s.appType));
    }

    if (selectedIndex >= 0 && selectedIndex < layout.length) {
      final x = layout[selectedIndex].centerX;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = WsHealthAppTheme.sleepThumbBg
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SleepPainter oldDelegate) {
    if (oldDelegate.segments != segments ||
        oldDelegate.thumbHeight != thumbHeight ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.mode != mode ||
        oldDelegate.layout.length != layout.length) {
      return true;
    }
    for (var i = 0; i < layout.length; i++) {
      final a = oldDelegate.layout[i];
      final b = layout[i];
      if (a.left != b.left ||
          a.width != b.width ||
          a.segment.begin != b.segment.begin) {
        return true;
      }
    }
    return false;
  }
}
