import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'jw_app_chart_layout.dart';
import 'jw_app_chart_models.dart';
import 'jw_health_app_theme.dart';

final class JwAppSportDayTouchSelection {
  const JwAppSportDayTouchSelection({
    required this.hour,
    required this.begin,
    required this.end,
    required this.minutes,
    required this.sessions,
    required this.anchorX,
  });

  final int hour;
  final DateTime begin;
  final DateTime end;
  final int minutes;
  final int sessions;
  final double anchorX;
}

/// 单日 24 小时运动时长柱（对齐 `WatchSportDayBarView`：浅轨 + 橙色柱）。
class JwAppSportDayChart extends StatefulWidget {
  const JwAppSportDayChart({
    super.key,
    required this.bars,
    this.onSelection,
    this.mode = JwAppChartMode.detail,
  });

  final List<JwAppSportHourBar> bars;
  final ValueChanged<JwAppSportDayTouchSelection?>? onSelection;
  final JwAppChartMode mode;

  @override
  State<JwAppSportDayChart> createState() => _JwAppSportDayChartState();
}

class _JwAppSportDayChartState extends State<JwAppSportDayChart> {
  static const _hourCount = 24;
  static const _touchPad = 5.0;

  int _touchHour = -1;
  int _downHour = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  @override
  void didUpdateWidget(covariant JwAppSportDayChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameBars(oldWidget.bars, widget.bars)) {
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

  bool _sameBars(List<JwAppSportHourBar> a, List<JwAppSportHourBar> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hour != b[i].hour ||
          a[i].minutes != b[i].minutes ||
          a[i].sessions.length != b[i].sessions.length) {
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

  double _slotWidth(double width) {
    return (width - 2 * _touchPad) / _hourCount;
  }

  double _centerX(int hour, double width) {
    return _touchPad + (hour + 0.5) * _slotWidth(width);
  }

  int _hourFromDx(double dx, double width) {
    final sw = _slotWidth(width);
    final x = dx - _touchPad;
    final h = (x / sw).floor();
    return h.clamp(0, _hourCount - 1);
  }

  int _maxMinutes() => jwAppSportMaxMinutesAxis(widget.bars);

  JwAppSportHourBar? _barForHour(int hour) {
    for (final b in widget.bars) {
      if (b.hour == hour) return b;
    }
    return null;
  }

  void _emit(int hour, double width) {
    final bar = _barForHour(hour);
    if (bar == null) {
      widget.onSelection?.call(null);
      return;
    }
    widget.onSelection?.call(
      JwAppSportDayTouchSelection(
        hour: hour,
        begin: bar.startTime,
        end: bar.startTime.add(const Duration(hours: 1)),
        minutes: bar.minutes,
        sessions: bar.sessions.length,
        anchorX: _centerX(hour, width),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = JwAppChartLayout.interactive(widget.mode);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final paint = CustomPaint(
          size: Size(width, height),
          painter: _SportDayPainter(
            bars: widget.bars,
            maxMinutes: _maxMinutes(),
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
            _delay = Timer(JwHealthAppTheme.chartTouchDelay, () {
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

class _SportDayPainter extends CustomPainter {
  _SportDayPainter({
    required this.bars,
    required this.maxMinutes,
    required this.touchHour,
    required this.mode,
  });

  final List<JwAppSportHourBar> bars;
  final int maxMinutes;
  final int touchHour;
  final JwAppChartMode mode;

  double get _top => JwAppChartLayout.top(mode);

  double get _bottomText => JwAppChartLayout.bottomText(mode, detail: 20);

  bool get _showYAxis => JwAppChartLayout.showYAxis(mode);

  bool get _showXAxis => JwAppChartLayout.showXAxis(mode);
  static const _touchPad = 5.0;
  static const _hourCount = 24;
  static const _barStroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartBottom = size.height - _bottomText;
    final slotW = (size.width - 2 * _touchPad) / _hourCount;
    final axisMax = math.max(1, maxMinutes);
    final eachHeight = (chartBottom - _top) / axisMax;

    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: JwHealthAppTheme.sportText,
      fontSize: 10.6,
    );

    if (_showYAxis && touchHour < 0) {
      final maxLabel = '$axisMax';
      text.text = TextSpan(
        text: maxLabel,
        style: const TextStyle(
          color: JwHealthAppTheme.sportBuoy,
          fontSize: 11.5,
        ),
      );
      text.layout();
      text.paint(canvas, Offset(size.width - text.width, 2));
    }

    final trackPaint = Paint()
      ..color = JwHealthAppTheme.sportBarTrack
      ..strokeWidth = _barStroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (var hour = 0; hour < _hourCount; hour++) {
      final x = _touchPad + (hour + 0.5) * slotW;
      canvas.drawLine(
        Offset(x, _top + _barStroke / 2),
        Offset(x, chartBottom - _barStroke / 2),
        trackPaint,
      );
      if (_showXAxis) {
        final dotY = mode == JwAppChartMode.home
            ? JwAppChartLayout.xAxisDotY(size.height, _bottomText)
            : chartBottom + 10;
        final labelY = mode == JwAppChartMode.home
            ? JwAppChartLayout.xAxisLabelY(size.height, _bottomText)
            : chartBottom + 4;
        if (hour == 0 || hour == _hourCount - 1) {
          canvas.drawCircle(
            Offset(x, dotY),
            1.5,
            Paint()..color = JwHealthAppTheme.sportText,
          );
        } else if (hour % 4 == 0) {
          final str = '${hour.toString().padLeft(2, '0')}:00';
          text.text = TextSpan(text: str, style: labelStyle);
          text.layout();
          text.paint(canvas, Offset(x - text.width / 2, labelY));
        }
      }
    }

    var totalMinutes = 0;
    for (final b in bars) {
      totalMinutes += b.minutes;
      if (b.minutes <= 0) continue;
      final hour = b.hour.clamp(0, _hourCount - 1);
      final x = _touchPad + (hour + 0.5) * slotW;
      var topY =
          _top + (axisMax - b.minutes) * eachHeight + _barStroke / 2;
      final bottomY = chartBottom - _barStroke / 2;
      topY = math.min(topY, bottomY - 1);
      topY = math.max(topY, _top + _barStroke / 2);

      final barPaint = Paint()
        ..strokeWidth = _barStroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = hour == touchHour
            ? JwHealthAppTheme.sportBuoy
            : JwHealthAppTheme.sportBar;
      canvas.drawLine(Offset(x, topY), Offset(x, bottomY), barPaint);
    }

    if (totalMinutes <= 0 && JwAppChartLayout.showEmptyHint(mode)) {
      text.text = TextSpan(
        text: '暂无运动',
        style: TextStyle(
          color: JwHealthAppTheme.sportEmpty,
          fontSize: JwAppChartLayout.emptyHintFontSize(mode),
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

    if (touchHour >= 0) {
      final x = _touchPad + (touchHour + 0.5) * slotW;
      JwAppSportHourBar? bar;
      for (final b in bars) {
        if (b.hour == touchHour) {
          bar = b;
          break;
        }
      }
      var topLineEnd = chartBottom;
      if (bar != null && bar.minutes > 0) {
        topLineEnd = _top +
            (axisMax - bar.minutes) * eachHeight +
            _barStroke / 2;
      }
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, math.max(0.0, topLineEnd - _barStroke / 2 - 1)),
        Paint()
          ..color = JwHealthAppTheme.sportBuoy
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SportDayPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.maxMinutes != maxMinutes ||
      oldDelegate.touchHour != touchHour ||
      oldDelegate.mode != mode;
}
