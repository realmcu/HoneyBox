import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/health/jw_health_charts.dart';
import 'package:honeybox/services/jw/health/jw_health_models.dart';

final day = DateTime.utc(2026, 10, 5);
JwHealthMetricSeries sampleSeries(
        JwHealthMetric metric, List<JwHealthSample> samples) =>
    JwHealthMetricSeries(metric: metric, samples: samples);
JwHealthSample sample(int hour, double value, {double? secondary}) =>
    JwHealthSample(
        time: day.add(Duration(hours: hour)),
        value: value,
        secondaryValue: secondary,
        recordId: 'raw-$hour');
JwHealthSleepSegment segment(int start, int end, JwSleepStage stage) =>
    JwHealthSleepSegment(
        start: day.add(Duration(minutes: start)),
        end: day.add(Duration(minutes: end)),
        stage: stage,
        recordId: 'sleep-$start');
JwHealthSnapshot snapshot(
    {JwHealthPeriod period = JwHealthPeriod.day,
    DateTime? date,
    List<JwHealthActivityBin> bins = const [],
    List<JwHealthSleepSegment> segments = const [],
    List<JwHealthDay>? days,
    JwHealthTotals totals = const JwHealthTotals()}) {
  final chosen = date ?? day;
  final start = period == JwHealthPeriod.day
      ? chosen
      : chosen.subtract(const Duration(days: 6));
  return JwHealthSnapshot(
      deviceKey: 'jw:test',
      date: chosen,
      start: start,
      endExclusive: chosen.add(const Duration(days: 1)),
      period: period,
      totals: totals,
      days: days ?? [JwHealthDay(date: chosen, totals: totals)],
      activityBins: bins,
      metrics: const {},
      sleepSegments: segments,
      sportRecords: const [],
      coverage: JwHealthCoverage(recordCount: 1),
      availableDates: [chosen]);
}

List<JwHealthActivityBin> activity() => [
      for (var i = 0; i < 24; i++)
        JwHealthActivityBin(
            start: day.add(Duration(hours: i)),
            end: day.add(Duration(hours: i + 1)),
            steps: i == 6
                ? 0
                : i == 18
                    ? 120
                    : null,
            energyKcal: i == 6
                ? 0
                : i == 18
                    ? 2.5
                    : null)
    ];
Future<void> host(WidgetTester tester, Widget chart, {double scale = 1}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: MediaQuery(
                      data:
                          MediaQueryData(textScaler: TextScaler.linear(scale)),
                      child: chart))))));
}

Future<void> tapPlot(WidgetTester tester, String key, double fraction) async {
  final rect = tester.getRect(find.byKey(Key(key)));
  await tester.tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
  await tester.pump();
}

String readout(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;
void main() {
  testWidgets(
      'empty activity does not claim a daily total; summary-only zero has no timed plot',
      (tester) async {
    await host(tester, JwHealthActivityChart(snapshot: snapshot()));
    expect(find.text('仅每日总量'), findsNothing);
    expect(find.text('没有活动数据'), findsOneWidget);
    await host(
        tester,
        JwHealthActivityChart(
            snapshot: snapshot(totals: const JwHealthTotals(steps: 0))));
    expect(find.text('仅每日总量'), findsOneWidget);
    expect(find.byKey(const Key('jw-health-activity-plot')), findsNothing);
  });
  testWidgets('weekly sleep Y scale uses Chinese hours and minutes',
      (tester) async {
    await host(
        tester,
        JwHealthSleepChart(
            snapshot: snapshot(period: JwHealthPeriod.week, days: [
          JwHealthDay(
              date: day, totals: const JwHealthTotals(sleepMinutes: 180))
        ])));
    expect(find.text('3小时'), findsOneWidget);
    expect(find.text('1小时30分'), findsOneWidget);
  });
  testWidgets('numeric Y and intermediate X labels explain sparse scale',
      (tester) async {
    await host(
        tester,
        JwHealthSampleChart(
            series: sampleSeries(
                JwHealthMetric.heartRate, [sample(6, 60), sample(18, 90)]),
            start: day,
            end: day.add(const Duration(days: 1)),
            unit: 'bpm'));
    // Removing real axis labels would break this assertion, independently of paint.
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
  });
  testWidgets('pointer exposes actual timestamp and paired blood pressure',
      (tester) async {
    await host(
        tester,
        JwHealthSampleChart(
            series: sampleSeries(JwHealthMetric.bloodPressure, [
              sample(6, 120, secondary: 80),
              sample(18, 130, secondary: 85)
            ]),
            start: day,
            end: day.add(const Duration(days: 1)),
            unit: 'mmHg'));
    await tapPlot(tester, 'jw-health-sample-plot-bloodPressure', .25);
    expect(readout(tester, 'jw-health-sample-readout-bloodPressure'),
        '2026-10-05 06:00 · 120/80 mmHg');
    await tapPlot(tester, 'jw-health-sample-plot-bloodPressure', .75);
    expect(readout(tester, 'jw-health-sample-readout-bloodPressure'),
        '2026-10-05 18:00 · 130/85 mmHg');
  });
  testWidgets(
      'single and equal sample values have finite axes and selectable points',
      (tester) async {
    for (final points in [
      [sample(6, 0)],
      [sample(6, 72), sample(18, 72)]
    ]) {
      await host(
          tester,
          JwHealthSampleChart(
              series: sampleSeries(JwHealthMetric.heartRate, points),
              start: day,
              end: day.add(const Duration(days: 1)),
              unit: 'bpm'));
      await tapPlot(tester, 'jw-health-sample-plot-heartRate', .25);
      expect(readout(tester, 'jw-health-sample-readout-heartRate'),
          contains('${healthNumber(points.first.value)} bpm'));
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('selected sample clears after day or source changes',
      (tester) async {
    final series = sampleSeries(JwHealthMetric.heartRate, [sample(6, 72)]);
    await host(
        tester,
        JwHealthSampleChart(
            series: series,
            start: day,
            end: day.add(const Duration(days: 1)),
            unit: 'bpm'));
    await tapPlot(tester, 'jw-health-sample-plot-heartRate', .25);
    expect(readout(tester, 'jw-health-sample-readout-heartRate'),
        contains('72 bpm'));
    await host(
        tester,
        JwHealthSampleChart(
            series: series,
            start: day.subtract(const Duration(days: 1)),
            end: day,
            unit: 'bpm'));
    expect(readout(tester, 'jw-health-sample-readout-heartRate'), '点击图表查看真实采样');
    await host(
        tester,
        JwHealthSampleChart(
            series: sampleSeries(JwHealthMetric.heartRate, []),
            start: day,
            end: day.add(const Duration(days: 1)),
            unit: 'bpm'));
    expect(find.textContaining('72 bpm'), findsNothing);
  });
  test(
      'duration retains missing and measured zero in Chinese hours and minutes',
      () {
    expect(healthDuration(null), '—');
    expect(healthDuration(0), '0分');
    expect(healthDuration(90), '1小时30分');
    expect(healthDuration(60), '1小时');
    expect(healthDuration(1.5), '1.5分');
  });
  testWidgets('hour selection retains measured zero, kcal and missing bins',
      (tester) async {
    await host(
        tester, JwHealthActivityChart(snapshot: snapshot(bins: activity())));
    await tapPlot(tester, 'jw-health-activity-plot', 6.5 / 24);
    expect(
        readout(tester, 'jw-health-activity-readout'), contains('06:00–07:00'));
    expect(readout(tester, 'jw-health-activity-readout'), contains('步数 0 步'));
    expect(
        readout(tester, 'jw-health-activity-readout'), contains('热量 0 kcal'));
    await tapPlot(tester, 'jw-health-activity-plot', 18.5 / 24);
    expect(readout(tester, 'jw-health-activity-readout'), contains('步数 120 步'));
    expect(
        readout(tester, 'jw-health-activity-readout'), contains('热量 2.5 kcal'));
    await tapPlot(tester, 'jw-health-activity-plot', 12.5 / 24);
    final missing = readout(tester, 'jw-health-activity-readout');
    expect(missing, contains('未提供该小时数据'));
    expect(missing, isNot(contains('步数 0')));
    await host(
        tester,
        JwHealthActivityChart(
            snapshot: snapshot(date: day.subtract(const Duration(days: 1)))));
    expect(find.textContaining('120 步'), findsNothing);
    expect(find.textContaining('未提供小时数据'), findsOneWidget);
  });
  testWidgets(
      'week activity uses daily totals and has no fabricated hourly bins',
      (tester) async {
    await host(
        tester,
        JwHealthActivityChart(
            snapshot: snapshot(period: JwHealthPeriod.week, days: [
          JwHealthDay(
              date: day, totals: const JwHealthTotals(steps: 0, energyKcal: 0))
        ])));
    await tapPlot(tester, 'jw-health-activity-plot', 6.5 / 7);
    final selected = readout(tester, 'jw-health-activity-readout');
    expect(selected, contains('2026-10-05'));
    expect(selected, contains('步数 0 步'));
    expect(selected, contains('热量 0 kcal'));
    expect(selected, isNot(contains('00:00')));
  });
  testWidgets(
      'day sleep uses closed observed bounds, palette legend and actual stage readout',
      (tester) async {
    await host(
        tester,
        JwHealthSleepChart(
            snapshot: snapshot(segments: [
          segment(60, 120, JwSleepStage.light),
          segment(120, 180, JwSleepStage.deep),
          segment(210, 240, JwSleepStage.awake),
          segment(240, 270, JwSleepStage.rem)
        ], totals: const JwHealthTotals(sleepMinutes: 150))));
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('04:30'), findsOneWidget);
    expect(find.text('24:00'), findsNothing);
    for (final name in ['未佩戴', '浅睡', '深睡', '清醒', 'REM']) {
      expect(find.textContaining(name), findsWidgets);
    }
    await tapPlot(tester, 'jw-health-sleep-plot', 30 / 210);
    expect(readout(tester, 'jw-health-sleep-readout'),
        '2026-10-05 01:00–02:00 · 浅睡 · 1小时');
    await tapPlot(tester, 'jw-health-sleep-plot', 135 / 210);
    expect(readout(tester, 'jw-health-sleep-readout'), '此时段未提供阶段');
  });
  testWidgets(
      'sleep readout resets when date changes without inventing summary stages',
      (tester) async {
    await host(
        tester,
        JwHealthSleepChart(
            snapshot:
                snapshot(segments: [segment(60, 120, JwSleepStage.deep)])));
    await tapPlot(tester, 'jw-health-sleep-plot', .5);
    expect(readout(tester, 'jw-health-sleep-readout'), contains('深睡'));
    await host(
        tester,
        JwHealthSleepChart(
            snapshot: snapshot(
                date: day.subtract(const Duration(days: 1)),
                totals: const JwHealthTotals(sleepMinutes: 180))));
    expect(readout(tester, 'jw-health-sleep-readout'), '只有每日总量；未提供阶段时间');
    expect(find.textContaining('01:00–02:00'), findsNothing);
  });
  testWidgets(
      'week sleep compares seven dates and keeps awake separate from sleep total',
      (tester) async {
    await host(
        tester,
        JwHealthSleepChart(
            snapshot: snapshot(period: JwHealthPeriod.week, days: [
          JwHealthDay(
              date: day.subtract(const Duration(days: 1)),
              totals: const JwHealthTotals(sleepMinutes: 180)),
          JwHealthDay(
              date: day, totals: const JwHealthTotals(sleepMinutes: 150))
        ], segments: [
          segment(60, 120, JwSleepStage.light),
          segment(120, 180, JwSleepStage.deep),
          segment(180, 210, JwSleepStage.rem),
          segment(210, 240, JwSleepStage.awake)
        ])));
    for (final date in [
      '09-29',
      '09-30',
      '10-01',
      '10-02',
      '10-03',
      '10-04',
      '10-05'
    ]) {
      expect(find.textContaining(date), findsWidgets);
    }
    expect(find.textContaining('10-04 · 3小时 · 仅每日总量'), findsOneWidget);
    await tapPlot(tester, 'jw-health-sleep-plot', 6.5 / 7);
    final selected = readout(tester, 'jw-health-sleep-readout');
    expect(selected, contains('2026-10-05 · 睡眠 2小时30分'));
    expect(selected, contains('清醒 30分'));
    expect(selected, isNot(contains('睡眠 3小时')));
    await tapPlot(tester, 'jw-health-sleep-plot', 5.5 / 7);
    expect(
        readout(tester, 'jw-health-sleep-readout'), contains('仅每日总量；未提供阶段时间'));
  });
  testWidgets(
      '320px text scale 2 supports axes and selected readouts without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final charts = <Widget>[
      JwHealthSampleChart(
          series: sampleSeries(
              JwHealthMetric.bloodPressure, [sample(6, 120, secondary: 80)]),
          start: day,
          end: day.add(const Duration(days: 1)),
          unit: 'mmHg'),
      JwHealthActivityChart(snapshot: snapshot(bins: activity())),
      JwHealthSleepChart(
          snapshot: snapshot(segments: [segment(60, 120, JwSleepStage.light)])),
      JwHealthSleepChart(
          snapshot: snapshot(period: JwHealthPeriod.week, days: [
        JwHealthDay(date: day, totals: const JwHealthTotals(sleepMinutes: 90))
      ]))
    ];
    final keys = [
      'jw-health-sample-plot-bloodPressure',
      'jw-health-activity-plot',
      'jw-health-sleep-plot',
      'jw-health-sleep-plot'
    ];
    for (var i = 0; i < charts.length; i++) {
      await host(tester, charts[i], scale: 2);
      await tapPlot(tester, keys[i], .5);
      expect(tester.takeException(), isNull, reason: 'chart index $i');
    }
  });
  testWidgets(
      'vertical page drag over chart remains scrollable and does not select a sample',
      (tester) async {
    await host(
        tester,
        Column(children: [
          JwHealthSampleChart(
              series: sampleSeries(JwHealthMetric.heartRate, [sample(6, 72)]),
              start: day,
              end: day.add(const Duration(days: 1)),
              unit: 'bpm'),
          const SizedBox(height: 1600)
        ]));
    await tester.drag(find.byKey(const Key('jw-health-sample-plot-heartRate')),
        const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(0));
    expect(readout(tester, 'jw-health-sample-readout-heartRate'), '点击图表查看真实采样');
  });
}
