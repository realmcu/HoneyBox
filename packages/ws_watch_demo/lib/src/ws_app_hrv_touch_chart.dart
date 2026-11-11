import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ws_app_chart_layout.dart';
import 'ws_app_chart_models.dart';
import 'ws_health_app_theme.dart';

final class WsAppHrvTouchSelection {
  const WsAppHrvTouchSelection({
    required this.hour,
    required this.begin,
    required this.end,
    required this.maxHrv,
    required this.minHrv,
    required this.anchorX,
  });

  final int hour;
  final DateTime begin;
  final DateTime end;
  final int maxHrv;
  final int minHrv;
  final double anchorX;
}

/// 对齐 Android `HrvTouchView`：24 小时、聚类竖条/点、`chartMax` 动态上限。
class WsAppHrvTouchChart extends StatefulWidget {
  const WsAppHrvTouchChart({
    super.key,
    required this.hours,
    this.onSelection,
    this.mode = WsAppChartMode.detail,
  });

  final List<WsAppHrvHourBucket> hours;
  final ValueChanged<WsAppHrvTouchSelection?>? onSelection;
  final WsAppChartMode mode;

  @override
  State<WsAppHrvTouchChart> createState() => _JwAppHrvTouchChartState();
}

class _JwAppHrvTouchChartState extends State<WsAppHrvTouchChart> {
  static const _slotCount = 24;
  static const _touchPad = 5.0;
  static const _itemWidth = 7.0;

  int _touchPos = -1;
  int _downDataIndex = -1;
  var _armed = false;
  var _tracking = false;
  Timer? _delay;
  Offset? _downPos;

  @override
  void didUpdateWidget(covariant WsAppHrvTouchChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameHours(oldWidget.hours, widget.hours)) {
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

  bool _sameHours(List<WsAppHrvHourBucket> a, List<WsAppHrvHourBucket> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hour != b[i].hour ||
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
    final had = _touchPos != -1;
    _touchPos = -1;
    _armed = false;
    _tracking = false;
    if (had && mounted) setState(() {});
    widget.onSelection?.call(null);
  }

  double _itemPadding(double width) {
    return ((width - 2 * _touchPad) / _slotCount - _itemWidth) / 2.0;
  }

  double _slotCenterX(int slotIndex, double width) {
    final pad = _itemPadding(width);
    return _touchPad +
        _itemWidth / 2 +
        pad +
        slotIndex * (_itemWidth + 2 * pad);
  }

  int _slotFromDx(double dx, double width) {
    final pad = _itemPadding(width);
    final pitch = _itemWidth + 2 * pad;
    final x = dx - _touchPad;
    final s = (x / pitch).floor();
    return s.clamp(0, _slotCount - 1);
  }

  int? _findDataIndexForSlot(int slot) {
    for (var i = 0; i < widget.hours.length; i++) {
      final h = widget.hours[i];
      if (h.hour == slot && h.max > 0 && h.min > 0) {
        return i;
      }
    }
    return null;
  }

  int? _hourForDataIndex(int dataIndex) {
    if (dataIndex < 0 || dataIndex >= widget.hours.length) return null;
    return widget.hours[dataIndex].hour;
  }

  void _emitFromDataIndex(int dataIndex, double width) {
    if (dataIndex < 0 || dataIndex >= widget.hours.length) {
      widget.onSelection?.call(null);
      return;
    }
    final b = widget.hours[dataIndex];
    widget.onSelection?.call(
      WsAppHrvTouchSelection(
        hour: b.hour,
        begin: b.startTime,
        end: b.startTime.add(const Duration(hours: 1)),
        maxHrv: b.max,
        minHrv: b.min,
        anchorX: _slotCenterX(b.hour.clamp(0, 23), width),
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
          painter: _HrvPainter(
            hours: widget.hours,
            touchDataIndex: interactive ? _touchPos : -1,
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
            final slot = _slotFromDx(d.localPosition.dx, width);
            final dataIdx = _findDataIndexForSlot(slot);
            if (dataIdx != null && dataIdx != _touchPos) {
              _downDataIndex = dataIdx;
              _delay = Timer(WsHealthAppTheme.chartTouchDelay, () {
                if (!mounted || !_armed) return;
                setState(() {
                  _tracking = true;
                  _touchPos = _downDataIndex;
                });
                _emitFromDataIndex(_touchPos, width);
              });
            } else {
              _downDataIndex = -1;
            }
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
            final curSlot = _slotFromDx(d.localPosition.dx, width);
            final downSlot = _hourForDataIndex(_downDataIndex);
            final touchSlot = _hourForDataIndex(_touchPos);
            if (curSlot == downSlot || curSlot == touchSlot) {
              return;
            }
            final dataIdx = _findDataIndexForSlot(curSlot);
            if (dataIdx != null) {
              setState(() {
                _touchPos = dataIdx;
              });
              _emitFromDataIndex(dataIdx, width);
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

class _ValueCluster {
  _ValueCluster(int value)
      : high = value,
        low = value,
        count = 1;

  int high;
  int low;
  int count;

  void merge(_ValueCluster other) {
    high = math.max(high, other.high);
    low = math.min(low, other.low);
    count += other.count;
  }
}

class _HrvPainter extends CustomPainter {
  _HrvPainter({
    required this.hours,
    required this.touchDataIndex,
    required this.mode,
  });

  final List<WsAppHrvHourBucket> hours;
  final int touchDataIndex;
  final WsAppChartMode mode;

  double get _top => WsAppChartLayout.top(mode);

  double get _bottomInner => 25.0;

  double get _bottomOuter => WsAppChartLayout.bottomText(mode, detail: 20);

  bool get _showYAxis => WsAppChartLayout.showYAxis(mode);

  bool get _showXAxis => WsAppChartLayout.showXAxis(mode);
  static const _touchPad = 5.0;
  static const _itemWidth = 7.0;
  static const _radius = 3.5;
  static const _baselineValue = 100;
  static const _clusterMinHeightDp = 160.0;
  static const _labelRightPad = 5.0;
  static const _lineLabelGap = 5.0;

  int _chartMax(List<WsAppHrvHourBucket> data) => jwAppHrvChartMax(data);

  double _itemPadding(double width) {
    return ((width - 2 * _touchPad) / 24 - _itemWidth) / 2.0;
  }

  double _slotCenterX(int slotIndex, double width) {
    final pad = _itemPadding(width);
    return _touchPad +
        _itemWidth / 2 +
        pad +
        slotIndex * (_itemWidth + 2 * pad);
  }

  int _clampValue(int value, int chartMax) {
    if (value < 0) return 0;
    return math.min(value, chartMax);
  }

  Offset _point(
    int index,
    int value,
    double width,
    double chartBottom,
    int chartMax,
    double itemHeight,
  ) {
    final x = _slotCenterX(index, width);
    final y = _top + (chartMax - _clampValue(value, chartMax)) * itemHeight;
    return Offset(x, y);
  }

  double _clusterValueY(
    int value,
    double height,
    double chartBottom,
    int chartMax,
  ) {
    final drawableHeight = math.max(
      chartBottom - _top,
      _clusterMinHeightDp,
    );
    final safe = _clampValue(value, chartMax);
    return _top + (chartMax - safe) * (drawableHeight / chartMax);
  }

  double _clusterTop(
    _ValueCluster c,
    double height,
    double chartBottom,
    int chartMax,
  ) {
    return _clusterValueY(c.high, height, chartBottom, chartMax) - _radius;
  }

  double _clusterBottom(
    _ValueCluster c,
    double height,
    double chartBottom,
    int chartMax,
  ) {
    return _clusterValueY(c.low, height, chartBottom, chartMax) + _radius;
  }

  List<_ValueCluster> _buildClusters(
    List<int> values,
    double height,
    double chartBottom,
    int chartMax,
  ) {
    final sorted = values.where((v) => v > 0).toList()
      ..sort((a, b) => b.compareTo(a));
    final out = <_ValueCluster>[];
    _ValueCluster? current;
    for (final value in sorted) {
      final next = _ValueCluster(value);
      if (current == null ||
          _clusterTop(next, height, chartBottom, chartMax) >
              _clusterBottom(current, height, chartBottom, chartMax)) {
        current = next;
        out.add(current);
      } else {
        current.merge(next);
      }
    }
    return out;
  }

  void _drawRangeIfNeeded(
    Canvas canvas,
    int index,
    int high,
    int low,
    double width,
    double height,
    double chartBottom,
    int chartMax,
    double itemHeight,
  ) {
    if (high <= 0 || low <= 0) return;
    final paint = Paint()
      ..color = WsHealthAppTheme.hrvValue.withValues(alpha: 1.0)
      ..style = PaintingStyle.fill;
    if (high == low) {
      final p = _point(index, high, width, chartBottom, chartMax, itemHeight);
      canvas.drawCircle(p, _radius, paint);
      return;
    }
    final highPoint =
        _point(index, high, width, chartBottom, chartMax, itemHeight);
    final lowPoint =
        _point(index, low, width, chartBottom, chartMax, itemHeight);
    var barTop = highPoint.dy + _radius;
    var barBottom = lowPoint.dy - _radius;
    if (barBottom - barTop <= _radius * 2) {
      canvas.drawCircle(
        Offset(highPoint.dx, (highPoint.dy + lowPoint.dy) / 2),
        _radius,
        paint,
      );
      return;
    }
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        highPoint.dx - _radius,
        barTop,
        lowPoint.dx + _radius,
        barBottom,
      ),
      topLeft: const Radius.circular(_radius),
      topRight: const Radius.circular(_radius),
      bottomLeft: const Radius.circular(_radius),
      bottomRight: const Radius.circular(_radius),
    );
    canvas.drawRRect(rect, paint);
  }

  void _drawValueCluster(
    Canvas canvas,
    int index,
    _ValueCluster cluster,
    double width,
    double height,
    double chartBottom,
    int chartMax,
    double itemHeight,
  ) {
    final paint = Paint()
      ..color = WsHealthAppTheme.hrvValue.withValues(alpha: 1.0)
      ..style = PaintingStyle.fill;
    if (cluster.count <= 1 || cluster.high == cluster.low) {
      final p =
          _point(index, cluster.high, width, chartBottom, chartMax, itemHeight);
      canvas.drawCircle(p, _radius, paint);
      return;
    }
    _drawRangeIfNeeded(
      canvas,
      index,
      cluster.high,
      cluster.low,
      width,
      height,
      chartBottom,
      chartMax,
      itemHeight,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartMax = _chartMax(hours);
    final chartBottom = size.height - _bottomOuter;
    final itemHeight = (chartBottom - _top) / chartMax;

    final text = TextPainter(textDirection: ui.TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: WsHealthAppTheme.hrvText,
      fontSize: 10.6,
    );

    final labelRight = size.width - _labelRightPad;
    final topStr = '$chartMax';
    const bottomStr = '0';
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
      ..color = WsHealthAppTheme.hrvLine
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, _top), Offset(topLineEndX, _top), axisPaint);
    if (chartMax > _baselineValue) {
      final y = _top + (chartMax - _baselineValue) * itemHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint);
    }
    canvas.drawLine(
      Offset(0, chartBottom),
      Offset(bottomLineEndX, chartBottom),
      axisPaint,
    );

    if (_showXAxis) {
      final bottomDotY = WsAppChartLayout.xAxisDotY(size.height, _bottomOuter);
      final bottomTextY =
          WsAppChartLayout.xAxisLabelY(size.height, _bottomOuter);
      for (var hour = 0; hour <= 24; hour += 3) {
      if (hour == 0) {
        canvas.drawCircle(
          Offset(_slotCenterX(0, size.width), bottomDotY),
          1.5,
          Paint()..color = WsHealthAppTheme.hrvText,
        );
      } else if (hour == 24) {
        canvas.drawCircle(
          Offset(
            size.width - _touchPad - _itemPadding(size.width),
            bottomDotY,
          ),
          1.5,
          Paint()..color = WsHealthAppTheme.hrvText,
        );
      } else {
        final str = '${hour.toString().padLeft(2, '0')}:00';
        text.text = TextSpan(text: str, style: labelStyle);
        text.layout();
        final cx = _slotCenterX(hour, size.width);
        text.paint(canvas, Offset(cx - text.width / 2, bottomTextY));
      }
    }
    }

    final hasData = hours.any((h) => h.max > 0 && h.min > 0);

    if (!hasData && WsAppChartLayout.showEmptyHint(mode)) {
      text.text = TextSpan(
        text: '暂无HRV',
        style: TextStyle(
          color: WsHealthAppTheme.hrvEmpty,
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

    for (var bi = 0; bi < hours.length; bi++) {
      final h = hours[bi];
      if (h.max <= 0 || h.min <= 0) continue;
      final slotHour = h.hour.clamp(0, 23);
      final vals = h.values.where((v) => v > 0).toList();
      if (vals.isEmpty) {
        _drawRangeIfNeeded(
          canvas,
          slotHour,
          h.max,
          h.min,
          size.width,
          size.height,
          chartBottom,
          chartMax,
          itemHeight,
        );
      } else {
        final clusters =
            _buildClusters(vals, size.height, chartBottom, chartMax);
        for (final c in clusters) {
          _drawValueCluster(
            canvas,
            slotHour,
            c,
            size.width,
            size.height,
            chartBottom,
            chartMax,
            itemHeight,
          );
        }
      }

      if (touchDataIndex >= 0 &&
          touchDataIndex < hours.length &&
          bi == touchDataIndex) {
        final x = _slotCenterX(slotHour, size.width);
        final thumb = Paint()..color = WsHealthAppTheme.hrvThumbBg;
        final topEnd = _top +
            (chartMax - _clampValue(h.max, chartMax)) * itemHeight -
            _radius -
            1;
        final bottomStart = _top +
            (chartMax - _clampValue(h.min, chartMax)) * itemHeight +
            _radius +
            1;
        canvas.drawLine(Offset(x, 0), Offset(x, topEnd), thumb);
        canvas.drawLine(
          Offset(x, bottomStart),
          Offset(x, size.height - _bottomInner),
          thumb,
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
  bool shouldRepaint(covariant _HrvPainter oldDelegate) =>
      oldDelegate.hours != hours ||
      oldDelegate.touchDataIndex != touchDataIndex ||
      oldDelegate.mode != mode;
}
