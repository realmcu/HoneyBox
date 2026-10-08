import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/services/jw/health/jw_health_aggregator.dart';
import 'package:honeybox/services/jw/health/jw_health_models.dart';
import 'package:honeybox/services/jw/jw_models.dart';

JwHistoryRecord healthRow(JwHistoryType type, Map<String, Object?> values,
        {String day = '2026-10-05',
        String device = 'jw:test',
        String? identity,
        String batch = '20261005-001',
        int ordinal = 0,
        int raw = 1,
        Map<String, bool> validity = const {},
        int minute = 0}) =>
    JwHistoryRecord(
        deviceKey: device,
        type: type,
        key: 0,
        wireVersion: 1,
        sourceIdentity: identity ?? '$day/$minute',
        sourceTimeBasis: 'deviceLocalCalendar',
        day: day,
        rawHex: raw.toRadixString(16).padLeft(2, '0'),
        firstSeenBatch: batch,
        firstSeenOrdinal: ordinal,
        values: values,
        sourceTime: {'date': day, 'minute': minute, 'second': 0},
        validity: validity);

JwHealthSnapshot summarize(Iterable<JwHistoryRecord> rows,
        {DateTime? date,
        JwHealthPeriod period = JwHealthPeriod.day,
        JwCapabilities? capabilities}) =>
    JwHealthAggregator.aggregate(
        deviceKey: 'jw:test',
        records: rows,
        date: date ?? DateTime(2026, 10, 5),
        period: period,
        capabilities: capabilities);

void main() {
  // Break caught: summing exercise again or treating calories as kcal.
  test(
      'traditional activity uses meters and calories, without sport double count',
      () {
    final s = summarize([
      healthRow(JwHistoryType.steps,
          {'steps': 120, 'distanceMeters': 80, 'energyCalories': 2500}),
      healthRow(JwHistoryType.exercise,
          {'steps': 120, 'distanceMeters': 80, 'energyCalories': 2500},
          identity: 'sport'),
    ]);
    expect(s.totals.steps, 120);
    expect(s.totals.distanceMeters, 80);
    expect(s.totals.energyKcal, 2.5);
    expect(s.sportRecords, hasLength(1));
  });
  test('valid summary replaces raw totals and preserves actual distance', () {
    final s = summarize([
      healthRow(JwHistoryType.steps,
          {'steps': 120, 'distanceMeters': 80, 'energyCalories': 2500}),
      healthRow(JwHistoryType.metabolism,
          {'steps': 0, 'energyKilocalories': 0, 'sleepMinutes': null},
          validity: {'sleepAvailable': false}),
    ]);
    expect(s.totals.steps, 0);
    expect(s.totals.energyKcal, 0);
    expect(s.totals.distanceMeters, 80);
    expect(s.totals.sleepMinutes, isNull);
  });
  test('normalized v2 and v3 summaries use kcal unchanged for each day', () {
    final s = summarize([
      healthRow(
          JwHistoryType.metabolism, {'steps': 7, 'energyKilocalories': 2.5},
          day: '2026-10-04'),
      healthRow(
          JwHistoryType.metabolism, {'steps': 8, 'energyKilocalories': 100}),
    ], period: JwHealthPeriod.week);
    expect(s.totals.energyKcal, 102.5);
    expect(s.totals.steps, 15);
    expect(s.days, hasLength(7));
    expect(s.start, DateTime.utc(2026, 9, 29));
    expect(s.endExclusive, DateTime.utc(2026, 10, 6));
  });
  test('empty and invalid totals stay missing while actual zero stays zero',
      () {
    expect(summarize([]).totals.distanceMeters, isNull);
    final s = summarize([
      healthRow(JwHistoryType.steps,
          {'steps': 0, 'distanceMeters': 0, 'energyCalories': 0}),
      healthRow(JwHistoryType.metabolism,
          {'steps': -1, 'energyKilocalories': double.nan}),
    ]);
    expect(s.totals.steps, 0);
    expect(s.totals.distanceMeters, 0);
    expect(s.totals.energyKcal, 0);
  });
  test(
      'replays and revised identities choose latest independent of input order',
      () {
    final old = healthRow(JwHistoryType.steps, {'steps': 10}, raw: 1);
    final latest = healthRow(JwHistoryType.steps, {'steps': 40},
        raw: 2, batch: '20261005-002');
    expect(summarize([latest, old, old, latest]).totals.steps, 40);
    expect(summarize([old, latest]).totals.steps, 40);
  });
  test('ordinal and record id resolve revision ties deterministically', () {
    final a = healthRow(JwHistoryType.steps, {'steps': 10}, raw: 1, ordinal: 1);
    final b = healthRow(JwHistoryType.steps, {'steps': 20}, raw: 2, ordinal: 2);
    expect(summarize([b, a]).totals.steps, 20);
    final c = healthRow(JwHistoryType.steps, {'steps': 30}, raw: 3, ordinal: 2);
    expect(summarize([c, b]).totals.steps, summarize([b, c]).totals.steps);
  });
  test('device identity and requested date prevent data mixing', () {
    final s = summarize([
      healthRow(JwHistoryType.steps, {'steps': 12}),
      healthRow(JwHistoryType.steps, {'steps': 900}, device: 'other'),
      healthRow(JwHistoryType.steps, {'steps': 800}, day: '2026-10-04'),
    ], date: DateTime(2026, 10, 5, 22));
    expect(s.totals.steps, 12);
    expect(s.availableDates,
        [DateTime.utc(2026, 10, 4), DateTime.utc(2026, 10, 5)]);
  });
  test('closed sleep transitions clip midnight and preserve all stage meanings',
      () {
    final s = summarize([
      healthRow(JwHistoryType.sleep, {'mode': 1},
          day: '2026-10-04', minute: 1380),
      healthRow(JwHistoryType.sleep, {'mode': 2}, minute: 60),
      healthRow(JwHistoryType.sleep, {'mode': 4}, minute: 120),
      healthRow(JwHistoryType.sleep, {'mode': 3}, minute: 150),
      healthRow(JwHistoryType.sleep, {'mode': 0}, minute: 180),
      healthRow(JwHistoryType.sleep, {'mode': 1}, minute: 210),
    ]);
    expect(s.totals.sleepMinutes, 150);
    expect(s.sleepSegments.map((e) => e.stage), [
      JwSleepStage.light,
      JwSleepStage.deep,
      JwSleepStage.rem,
      JwSleepStage.awake,
      JwSleepStage.nonWorn
    ]);
    expect(s.sleepSegments.first.start, DateTime.utc(2026, 10, 5));
    expect(s.sleepSegments.first.end, DateTime.utc(2026, 10, 5, 1));
    expect(s.coverage.issues, contains('openSleepTransition'));
  });
  test(
      'following date closes sleep but final transition never invents duration',
      () {
    final a = healthRow(JwHistoryType.sleep, {'mode': 1}, minute: 1380);
    expect(summarize([a]).totals.sleepMinutes, isNull);
    final s = summarize([
      a,
      healthRow(JwHistoryType.sleep, {'mode': 3}, day: '2026-10-06', minute: 60)
    ]);
    expect(s.totals.sleepMinutes, 60);
    expect(s.sleepSegments.single.end, DateTime.utc(2026, 10, 6));
  });
  test('previous-date final transition remains open without fabricated sleep',
      () {
    final s = summarize([
      healthRow(JwHistoryType.sleep, {'mode': 1},
          day: '2026-10-04', minute: 1380),
    ]);
    expect(s.totals.sleepMinutes, isNull);
    expect(s.sleepSegments, isEmpty);
    expect(s.coverage.issues, contains('openSleepTransition'));
  });
  test('valid daily sleep replaces intervals and false flag cannot override',
      () {
    final rows = [
      healthRow(JwHistoryType.sleep, {'mode': 1}, minute: 60),
      healthRow(JwHistoryType.sleep, {'mode': 3}, minute: 120)
    ];
    expect(
        summarize([
          ...rows,
          healthRow(JwHistoryType.metabolism, {'sleepMinutes': 0},
              validity: {'sleepAvailable': true})
        ]).totals.sleepMinutes,
        0);
    expect(
        summarize([
          ...rows,
          healthRow(JwHistoryType.metabolism, {'sleepMinutes': 800},
              validity: {'sleepAvailable': false})
        ]).totals.sleepMinutes,
        60);
  });
  test(
      'metric samples reject invalid flags, unpaired BP, nonfinite and absent zero',
      () {
    final s = summarize([
      healthRow(JwHistoryType.heartTemperature,
          {'heartRateBpm': 70, 'skinTemperatureCelsius': 0},
          validity: {'heartRateRecorded': true, 'temperatureRecorded': true}),
      healthRow(JwHistoryType.heartTemperature,
          {'heartRateBpm': 90, 'skinTemperatureCelsius': 36},
          minute: 1,
          validity: {'heartRateRecorded': false, 'temperatureRecorded': false}),
      healthRow(JwHistoryType.bloodOxygen, {'percent': 0}),
      healthRow(JwHistoryType.bloodOxygen, {'percent': 101}, minute: 1),
      healthRow(JwHistoryType.hrv, {'sdnnMilliseconds': double.infinity}),
      healthRow(JwHistoryType.bloodPressure,
          {'systolicMmHg': 120, 'diastolicMmHg': null}),
      healthRow(JwHistoryType.bloodPressure,
          {'systolicMmHg': 122, 'diastolicMmHg': 78},
          minute: 1),
      healthRow(JwHistoryType.pressure, {'value': null}),
    ]);
    expect(s.metrics[JwHealthMetric.heartRate]!.average, 70);
    expect(s.metrics[JwHealthMetric.skinTemperature]!.samples.single.value, 0);
    expect(s.metrics[JwHealthMetric.bloodOxygen]!.samples, isEmpty);
    expect(s.metrics[JwHealthMetric.hrv]!.samples, isEmpty);
    expect(
        s.metrics[JwHealthMetric.bloodPressure]!.samples.single.secondaryValue,
        78);
    expect(s.metrics[JwHealthMetric.pressure]!.samples, isEmpty);
  });
  test('capabilities mark live support but never hide saved valid values', () {
    final c = JwCapabilities.fromWire(Uint8List(8), Uint8List(1));
    final s = summarize([
      healthRow(JwHistoryType.hrv, {'sdnnMilliseconds': 42})
    ], capabilities: c);
    expect(s.metrics[JwHealthMetric.hrv]!.supported, false);
    expect(s.metrics[JwHealthMetric.hrv]!.samples.single.value, 42);
    expect(summarize([]).metrics[JwHealthMetric.hrv]!.supported, isNull);
  });
  test(
      'summary flags preserve partial and clock coverage without synthetic sample',
      () {
    final s = summarize([
      healthRow(JwHistoryType.metabolism, {
        'sdnnMedianMs': 50,
        'skinTemperatureMeanCelsius': 35
      }, validity: {
        'hrvValid': true,
        'hrvPartial': true,
        'temperatureValid': true,
        'clockJump': true
      })
    ]);
    expect(s.metrics[JwHealthMetric.hrv]!.samples, isEmpty);
    expect(s.coverage.issues, containsAll(['hrvPartial', 'clockJump']));
    expect(s.coverage.deviceDatasetExhaustive, false);
  });
}
