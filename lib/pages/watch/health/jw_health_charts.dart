import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/jw/health/jw_health_models.dart';

String healthNumber(num? value, [int decimals = 1]) => value == null
    ? '—'
    : value.toStringAsFixed(value == value.roundToDouble() ? 0 : decimals);
String healthClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
String healthDuration(num? minutes) {
  if (minutes == null) return '—';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return hours == 0
      ? '${healthNumber(remainder)}分'
      : '$hours小时${remainder == 0 ? '' : '${healthNumber(remainder)}分'}';
}

String _stamp(DateTime time) => '${jwHealthDayKey(time)} ${healthClock(time)}'
    '${time.second == 0 ? '' : ':${time.second.toString().padLeft(2, '0')}'}';

class _Scale {
  final double minimum, maximum;
  const _Scale(this.minimum, this.maximum);
  factory _Scale.samples(Iterable<double> values) {
    final finite = values.where((v) => v.isFinite).toList();
    if (finite.isEmpty) return const _Scale(0, 1);
    final min = finite.reduce(math.min), max = finite.reduce(math.max);
    final padding = min == max ? math.max(1.0, min.abs() * .05) : 0.0;
    return _Scale(min - padding, max + padding);
  }
  factory _Scale.bars(Iterable<double?> values) => _Scale(
      0,
      math.max(
          1,
          values
              .whereType<double>()
              .where((v) => v.isFinite)
              .fold<double>(0, math.max)));
  List<String> get ticks => [
        healthNumber(maximum),
        healthNumber((maximum + minimum) / 2),
        healthNumber(minimum)
      ];
  double y(double value, double height) =>
      height - 8 - (height - 16) * (value - minimum) / (maximum - minimum);
}

/// Labels are real widgets, so large text and assistive readers can read axes.
class _PlotFrame extends StatelessWidget {
  const _PlotFrame(
      {required this.plotKey,
      required this.painter,
      required this.color,
      required this.yLabels,
      required this.xLabels,
      required this.onTap,
      this.height = 128});
  final String plotKey;
  final CustomPainter painter;
  final Color color;
  final List<String> yLabels, xLabels;
  final void Function(Offset position, Size size)? onTap;
  final double height;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final style = DefaultTextStyle.of(context)
            .style
            .merge(TextStyle(color: color, fontSize: 11));
        final scaler = MediaQuery.textScalerOf(context);
        var labelWidth = 0.0;
        for (final label in yLabels) {
          final text = TextPainter(
              text: TextSpan(text: label, style: style),
              textDirection: TextDirection.ltr,
              textScaler: scaler)
            ..layout();
          labelWidth = math.max(labelWidth, text.width + 10);
        }
        labelWidth = math.min(labelWidth, box.maxWidth * .38);
        final plotWidth = math.max(1.0, box.maxWidth - labelWidth);
        final selectedLabels =
            xLabels.length > 3 && plotWidth < scaler.scale(55) * 5
                ? [xLabels.first, xLabels[xLabels.length ~/ 2], xLabels.last]
                : xLabels;
        var labelHeight = 0.0;
        for (final label in yLabels) {
          final text = TextPainter(
              text: TextSpan(text: label, style: style),
              textDirection: TextDirection.ltr,
              textScaler: scaler)
            ..layout(maxWidth: math.max(1, labelWidth));
          labelHeight += text.height;
        }
        final plotHeight = math.max(height, labelHeight + 16);
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (yLabels.isNotEmpty)
              SizedBox(
                  width: labelWidth,
                  height: plotHeight,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final label in yLabels)
                              Text(label,
                                  style: style, textAlign: TextAlign.right)
                          ]))),
            Expanded(
                child: SizedBox(
                    height: plotHeight,
                    child: GestureDetector(
                        key: Key(plotKey),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: onTap == null
                            ? null
                            : (details) => onTap!(details.localPosition,
                                Size(plotWidth, plotHeight)),
                        child: CustomPaint(painter: painter)))),
          ]),
          Padding(
              padding: EdgeInsets.only(left: labelWidth, top: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < selectedLabels.length; i++)
                  Expanded(
                      child: Text(selectedLabels[i],
                          style: style,
                          textAlign: i == 0
                              ? TextAlign.left
                              : i == selectedLabels.length - 1
                                  ? TextAlign.right
                                  : TextAlign.center))
              ])),
        ]);
      });
}

List<String> _timeTicks(DateTime start, DateTime end) {
  final day = end.difference(start) == const Duration(days: 1);
  return [
    for (var i = 0; i < 5; i++)
      day
          ? '${(i * 6).toString().padLeft(2, '0')}:00'
          : jwHealthDayKey(i == 4
                  ? end.subtract(const Duration(days: 1))
                  : start.add(Duration(
                      microseconds:
                          end.difference(start).inMicroseconds * i ~/ 4)))
              .substring(5)
  ];
}

double _timeFraction(DateTime time, DateTime start, DateTime end) =>
    end.isAfter(start)
        ? (time.difference(start).inMicroseconds /
                end.difference(start).inMicroseconds)
            .clamp(0.0, 1.0)
        : .5;
void _grid(Canvas canvas, Size size, Color color) {
  final paint = Paint()
    ..color = color.withValues(alpha: .22)
    ..strokeWidth = 1;
  for (var i = 0; i < 3; i++) {
    final y = 8 + (size.height - 16) * i / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

/// A point plot never connects observations across unknown intervals.
class JwHealthSampleChart extends StatefulWidget {
  const JwHealthSampleChart(
      {super.key,
      required this.series,
      required this.start,
      required this.end,
      required this.unit,
      this.foreground = Colors.white});
  final JwHealthMetricSeries series;
  final DateTime start, end;
  final String unit;
  final Color foreground;
  @override
  State<JwHealthSampleChart> createState() => _SampleChartState();
}

class _SampleChartState extends State<JwHealthSampleChart> {
  JwHealthSample? selected;
  @override
  void didUpdateWidget(covariant JwHealthSampleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series ||
        oldWidget.start != widget.start ||
        oldWidget.end != widget.end) {
      selected = null;
    }
  }

  List<JwHealthSample> get samples => widget.series.samples
      .where((s) =>
          s.value.isFinite &&
          (s.secondaryValue == null || s.secondaryValue!.isFinite) &&
          !s.time.isBefore(widget.start) &&
          s.time.isBefore(widget.end))
      .toList();
  @override
  Widget build(BuildContext context) {
    final points = samples;
    final scale = _Scale.samples([
      for (final sample in points) ...[
        sample.value,
        if (sample.secondaryValue != null) sample.secondaryValue!
      ]
    ]);
    final id = widget.series.metric.name;
    final readout = selected == null
        ? '点击图表查看真实采样'
        : '${_stamp(selected!.time)} · ${healthNumber(selected!.value)}'
            '${selected!.secondaryValue == null ? '' : '/${healthNumber(selected!.secondaryValue)}'} ${widget.unit}';
    return DefaultTextStyle.merge(
        style: TextStyle(color: widget.foreground),
        child: Semantics(
            label: '原始采样点；点之间空白表示未提供采样',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlotFrame(
                      plotKey: 'jw-health-sample-plot-$id',
                      painter: _SamplePainter(points, widget.start, widget.end,
                          scale, widget.foreground, selected),
                      color: widget.foreground,
                      yLabels: points.isEmpty ? const ['—'] : scale.ticks,
                      xLabels: _timeTicks(widget.start, widget.end),
                      onTap: points.isEmpty
                          ? null
                          : (position, size) {
                              final fraction = ((position.dx - 6) /
                                      math.max(1, size.width - 12))
                                  .clamp(0, 1);
                              final nearest = points.reduce((a, b) =>
                                  (_timeFraction(a.time, widget.start,
                                                      widget.end) -
                                                  fraction)
                                              .abs() <=
                                          (_timeFraction(b.time, widget.start,
                                                      widget.end) -
                                                  fraction)
                                              .abs()
                                      ? a
                                      : b);
                              setState(() => selected = nearest);
                            }),
                  const SizedBox(height: 8),
                  Text(readout, key: Key('jw-health-sample-readout-$id')),
                  const SizedBox(height: 4),
                  Wrap(spacing: 16, runSpacing: 4, children: [
                    Text(
                        '最小 ${healthNumber(widget.series.minimum)} ${widget.unit}'),
                    Text(
                        '最大 ${healthNumber(widget.series.maximum)} ${widget.unit}')
                  ]),
                ])));
  }
}

class _SamplePainter extends CustomPainter {
  _SamplePainter(this.samples, this.start, this.end, this.scale, this.color,
      this.selected);
  final List<JwHealthSample> samples;
  final DateTime start, end;
  final _Scale scale;
  final Color color;
  final JwHealthSample? selected;
  @override
  void paint(Canvas canvas, Size size) {
    _grid(canvas, size, color);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (final sample in samples) {
      final x = 6 + (size.width - 12) * _timeFraction(sample.time, start, end);
      final y = scale.y(sample.value, size.height);
      if (selected == sample) {
        canvas.drawLine(
            Offset(x, 0),
            Offset(x, size.height),
            Paint()
              ..color = color.withValues(alpha: .4)
              ..strokeWidth = 1);
      }
      if (sample.secondaryValue != null) {
        final lower = scale.y(sample.secondaryValue!, size.height);
        canvas.drawLine(Offset(x, y), Offset(x, lower), paint);
        canvas.drawCircle(Offset(x, lower), selected == sample ? 4 : 3, paint);
      }
      canvas.drawCircle(Offset(x, y), selected == sample ? 4 : 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SamplePainter old) => true;
}

List<JwHealthDay> _periodDays(JwHealthSnapshot snapshot) {
  final count = snapshot.period == JwHealthPeriod.week ? 7 : 1;
  return [
    for (var i = 0; i < count; i++)
      JwHealthDay(
          date: snapshot.start.add(Duration(days: i)),
          totals: snapshot.days
                  .where((d) =>
                      jwHealthDayKey(d.date) ==
                      jwHealthDayKey(snapshot.start.add(Duration(days: i))))
                  .map((d) => d.totals)
                  .firstOrNull ??
              const JwHealthTotals())
  ];
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.values, this.scale, this.color, this.selected);
  final List<double?> values;
  final _Scale scale;
  final Color color;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    _grid(canvas, size, color);
    if (values.isEmpty) return;
    final slot = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      // Missing remains a gap. A measured zero has a visible baseline marker.
      if (value == null || !value.isFinite) continue;
      final height = math.max(2.0, (size.height - 16) * value / scale.maximum);
      final rect = Rect.fromLTWH(
          i * slot + slot * .22, size.height - 8 - height, slot * .56, height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()
            ..color = color.withValues(
                alpha: selected == null || selected == i ? 1 : .5));
    }
    if (selected != null) {
      final x = (selected! + .5) * slot;
      canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = color.withValues(alpha: .45)
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}

int _slot(Offset position, Size size, int count) =>
    (position.dx / size.width * count).floor().clamp(0, count - 1);

class JwHealthActivityChart extends StatefulWidget {
  const JwHealthActivityChart(
      {super.key,
      required this.snapshot,
      this.foreground = const Color(0xff38251c)});
  final JwHealthSnapshot snapshot;
  final Color foreground;
  @override
  State<JwHealthActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<JwHealthActivityChart> {
  int? selected;
  @override
  void didUpdateWidget(covariant JwHealthActivityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final week = widget.snapshot.period == JwHealthPeriod.week;
    final days = _periodDays(widget.snapshot);
    final bins = widget.snapshot.activityBins
        .where((b) =>
            !b.start.isBefore(widget.snapshot.start) &&
            b.start.isBefore(widget.snapshot.endExclusive))
        .toList();
    final values = week
        ? days.map((d) => d.totals.steps?.toDouble()).toList()
        : bins.map((b) => b.steps?.toDouble()).toList();
    final scale = _Scale.bars(values);
    var readout = '点击图表查看${week ? '每日' : '小时'}步数与热量';
    if (selected != null) {
      final totals = week
          ? days[selected!].totals
          : JwHealthTotals(
              steps: bins[selected!].steps,
              energyKcal: bins[selected!].energyKcal,
              distanceMeters: bins[selected!].distanceMeters);
      final label = week
          ? jwHealthDayKey(days[selected!].date)
          : '${_stamp(bins[selected!].start)}–${healthClock(bins[selected!].end)}';
      readout =
          '$label\n${!week && totals.steps == null && totals.energyKcal == null && totals.distanceMeters == null ? '未提供该小时数据' : '步数 ${healthNumber(totals.steps)} 步 · 热量 ${healthNumber(totals.energyKcal)} kcal'}';
    }
    return DefaultTextStyle.merge(
        style: TextStyle(color: widget.foreground),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (values.isEmpty)
            Text(widget.snapshot.totals.steps != null ||
                    widget.snapshot.totals.energyKcal != null ||
                    widget.snapshot.totals.distanceMeters != null
                ? '仅每日总量'
                : '没有活动数据')
          else
            _PlotFrame(
                plotKey: 'jw-health-activity-plot',
                painter:
                    _BarPainter(values, scale, widget.foreground, selected),
                color: widget.foreground,
                yLabels: scale.ticks,
                xLabels: week
                    ? days
                        .map((d) => jwHealthDayKey(d.date).substring(5))
                        .toList()
                    : _timeTicks(
                        widget.snapshot.start, widget.snapshot.endExclusive),
                onTap: (position, size) => setState(
                    () => selected = _slot(position, size, values.length))),
          const SizedBox(height: 8),
          Text(values.isEmpty ? '未提供小时数据' : readout,
              key: const Key('jw-health-activity-readout')),
        ]));
  }
}

class JwHealthDayBars extends StatefulWidget {
  const JwHealthDayBars(
      {super.key,
      required this.days,
      required this.value,
      required this.unit,
      this.foreground = Colors.white});
  final List<JwHealthDay> days;
  final double? Function(JwHealthTotals) value;
  final String unit;
  final Color foreground;
  @override
  State<JwHealthDayBars> createState() => _DayBarsState();
}

class _DayBarsState extends State<JwHealthDayBars> {
  int? selected;
  @override
  void didUpdateWidget(covariant JwHealthDayBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days || oldWidget.value != widget.value) {
      selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.days.map((d) => widget.value(d.totals)).toList();
    final scale = _Scale.bars(values);
    return DefaultTextStyle.merge(
        style: TextStyle(color: widget.foreground),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PlotFrame(
              plotKey: 'jw-health-day-bars-plot-${widget.unit}',
              painter: _BarPainter(values, scale, widget.foreground, selected),
              color: widget.foreground,
              yLabels: scale.ticks,
              xLabels: widget.days
                  .map((d) => jwHealthDayKey(d.date).substring(5))
                  .toList(),
              onTap: values.isEmpty
                  ? null
                  : (position, size) => setState(
                      () => selected = _slot(position, size, values.length))),
          if (selected != null)
            Text('${jwHealthDayKey(widget.days[selected!].date)} · '
                '${healthNumber(values[selected!])} ${widget.unit}'),
          Wrap(spacing: 12, runSpacing: 6, children: [
            for (var i = 0; i < widget.days.length; i++)
              Text(
                  '${jwHealthDayKey(widget.days[i].date).substring(5)}: ${healthNumber(values[i])} ${widget.unit}')
          ]),
        ]));
  }
}

const healthSleepLabels = ['未佩戴', '浅睡', '深睡', '清醒', 'REM'];
const healthSleepColors = [
  Color(0xffc7c7c7),
  Color(0xffd6aaff),
  Color(0xffb45bff),
  Color(0xffff6cb9),
  Color(0xff8e9bfd)
];

class JwHealthSleepChart extends StatefulWidget {
  const JwHealthSleepChart(
      {super.key, required this.snapshot, this.foreground = Colors.white});
  final JwHealthSnapshot snapshot;
  final Color foreground;
  @override
  State<JwHealthSleepChart> createState() => _SleepChartState();
}

class _SleepChartState extends State<JwHealthSleepChart> {
  String? selectedReadout;
  int? selectedDay;
  @override
  void didUpdateWidget(covariant JwHealthSleepChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      selectedReadout = null;
      selectedDay = null;
    }
  }

  List<JwHealthSleepSegment> get segments => [
        for (final s in widget.snapshot.sleepSegments)
          if (s.end.isAfter(s.start) &&
              s.end.isAfter(widget.snapshot.start) &&
              s.start.isBefore(widget.snapshot.endExclusive))
            JwHealthSleepSegment(
                start: s.start.isBefore(widget.snapshot.start)
                    ? widget.snapshot.start
                    : s.start,
                end: s.end.isAfter(widget.snapshot.endExclusive)
                    ? widget.snapshot.endExclusive
                    : s.end,
                stage: s.stage,
                recordId: s.recordId)
      ];
  List<JwHealthSleepSegment> _onDay(
      DateTime date, List<JwHealthSleepSegment> observed) {
    final end = date.add(const Duration(days: 1));
    return [
      for (final s in observed)
        if (s.end.isAfter(date) && s.start.isBefore(end))
          JwHealthSleepSegment(
              start: s.start.isBefore(date) ? date : s.start,
              end: s.end.isAfter(end) ? end : s.end,
              stage: s.stage,
              recordId: s.recordId)
    ];
  }

  String _stageText(List<JwHealthSleepSegment> observed) => [
        for (final stage in JwSleepStage.values)
          if (observed.any((s) => s.stage == stage))
            '${healthSleepLabels[stage.index]} ${healthDuration(observed.where((s) => s.stage == stage).fold<double>(0, (sum, s) => sum + s.minutes))}'
      ].join(' · ');
  @override
  Widget build(BuildContext context) {
    final observed = segments;
    final week = widget.snapshot.period == JwHealthPeriod.week;
    final days = _periodDays(widget.snapshot);
    final values = days.map((d) => d.totals.sleepMinutes).toList();
    final scale = _Scale.bars(values);
    final first = observed.isEmpty
        ? widget.snapshot.start
        : observed.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final last = observed.isEmpty
        ? widget.snapshot.endExclusive
        : observed.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);
    final mid = first.add(
        Duration(microseconds: last.difference(first).inMicroseconds ~/ 2));
    final readout = selectedReadout ??
        (week
            ? '点击图表查看每日总量与已知阶段'
            : observed.isNotEmpty
                ? '点击图表查看已闭合阶段'
                : widget.snapshot.totals.sleepMinutes != null
                    ? '只有每日总量；未提供阶段时间'
                    : '没有已闭合阶段');
    return DefaultTextStyle.merge(
        style: TextStyle(color: widget.foreground),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (week)
            _PlotFrame(
                plotKey: 'jw-health-sleep-plot',
                painter:
                    _BarPainter(values, scale, widget.foreground, selectedDay),
                color: widget.foreground,
                yLabels: scale.ticks
                    .map((t) => healthDuration(num.parse(t)))
                    .toList(),
                xLabels: days
                    .map((d) => jwHealthDayKey(d.date).substring(5))
                    .toList(),
                onTap: (position, size) {
                  final i = _slot(position, size, days.length);
                  final dailySegments = _onDay(days[i].date, observed);
                  setState(() {
                    selectedDay = i;
                    selectedReadout =
                        '${jwHealthDayKey(days[i].date)} · 睡眠 ${healthDuration(values[i])}\n'
                        '${dailySegments.isEmpty ? values[i] == null ? '未提供每日总量或阶段' : '仅每日总量；未提供阶段时间' : '已知阶段：${_stageText(dailySegments)}'}';
                  });
                })
          else if (observed.isNotEmpty)
            _PlotFrame(
                plotKey: 'jw-health-sleep-plot',
                painter: _SleepPainter(observed, first, last),
                color: widget.foreground,
                yLabels: healthSleepLabels,
                xLabels: [
                  healthClock(first),
                  healthClock(mid),
                  healthClock(last)
                ],
                height: 140,
                onTap: (position, size) {
                  final selectedTime = first.add(Duration(
                      microseconds: (last.difference(first).inMicroseconds *
                              (position.dx / size.width).clamp(0, 1))
                          .round()));
                  final stage = observed
                      .where((s) =>
                          !selectedTime.isBefore(s.start) &&
                          selectedTime.isBefore(s.end))
                      .firstOrNull;
                  setState(() => selectedReadout = stage == null
                      ? '此时段未提供阶段'
                      : '${_stamp(stage.start)}–${healthClock(stage.end)} · ${healthSleepLabels[stage.stage.index]} · ${healthDuration(stage.minutes)}');
                }),
          const SizedBox(height: 8),
          Text(readout, key: const Key('jw-health-sleep-readout')),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            for (final stage in JwSleepStage.values)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    color: healthSleepColors[stage.index]),
                const SizedBox(width: 5),
                Text(healthSleepLabels[stage.index]),
              ])
          ]),
          if (week) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, children: [
              for (var i = 0; i < days.length; i++)
                Text(
                    '${jwHealthDayKey(days[i].date).substring(5)} · ${healthDuration(values[i])}'
                    '${values[i] != null && _onDay(days[i].date, observed).isEmpty ? ' · 仅每日总量' : ''}')
            ]),
            const Text('睡眠总量与已知阶段分别显示；清醒和未佩戴不计入睡眠'),
          ] else if (observed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('已知阶段：${_stageText(observed)}'),
            const Text('仅已闭合阶段；空白或末段未知，不代表完整一夜'),
          ],
        ]));
  }
}

class _SleepPainter extends CustomPainter {
  _SleepPainter(this.segments, this.start, this.end);
  final List<JwHealthSleepSegment> segments;
  final DateTime start, end;
  @override
  void paint(Canvas canvas, Size size) {
    final row = size.height / JwSleepStage.values.length;
    for (final s in segments) {
      final left = size.width * _timeFraction(s.start, start, end);
      final right = size.width * _timeFraction(s.end, start, end);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(left, row * s.stage.index + 4, right,
                  row * (s.stage.index + 1) - 4),
              const Radius.circular(2)),
          Paint()..color = healthSleepColors[s.stage.index]);
    }
  }

  @override
  bool shouldRepaint(covariant _SleepPainter old) => true;
}

class JwHealthGoalRings extends StatelessWidget {
  const JwHealthGoalRings(
      {super.key, required this.ratios, this.dimension = 132});
  final List<double?> ratios;
  final double dimension;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '步数、能量、睡眠目标环。未设置目标或没有数据时不显示进度。',
      child: SizedBox.square(
          dimension: dimension,
          child: CustomPaint(painter: _RingPainter(ratios))));
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ratios);
  final List<double?> ratios;
  @override
  void paint(Canvas c, Size size) {
    const colors = [Color(0xffff4f38), Color(0xfffac980), Color(0xff971af1)];
    for (var i = 0; i < 3; i++) {
      final scale = size.width / 132;
      final rect = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width - (12 + i * 32) * scale,
          height: size.height - (12 + i * 32) * scale);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11 * scale
        ..strokeCap = StrokeCap.round
        ..color = colors[i].withValues(alpha: .15);
      c.drawArc(rect, -math.pi / 2, math.pi * 2, false, p);
      if (ratios[i] != null) {
        c.drawArc(rect, -math.pi / 2, math.pi * 2 * ratios[i]!.clamp(0, 1),
            false, p..color = colors[i]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => true;
}
