import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/health/jw_health_models.dart';
import 'package:honeybox/services/jw/history/jw_history_decoder.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'jw_health_aggregator_test.dart' show healthRow, summarize;

void main() {
  // Break caught: missing dates dilute averages, or measured zero is omitted.
  test('week averages count measured zero and exclude missing dates', () {
    final s = summarize([
      healthRow(JwHistoryType.metabolism, {'steps': 10, 'sleepMinutes': 60},
          day: '2026-10-04', validity: {'sleepAvailable': true}),
      healthRow(JwHistoryType.metabolism, {'steps': 0, 'sleepMinutes': 120},
          validity: {'sleepAvailable': true}),
    ], period: JwHealthPeriod.week);
    expect(s.stepsValidDayCount, 2);
    expect(s.stepsDayAverage, 5);
    expect(s.totals.steps, 10);
    expect(s.sleepValidDayCount, 2);
    expect(s.sleepDayAverage, 90);
    expect(s.totals.sleepMinutes, 180);
    expect(summarize([]).stepsValidDayCount, 0);
    expect(summarize([]).stepsDayAverage, isNull);
    expect(summarize([]).sleepDayAverage, isNull);
  });

  // Break caught: hour buckets invent zeros or lose calorie/meter units.
  test(
      'four quarter records form one measured hour and missing hours stay null',
      () {
    final s = summarize([
      for (var i = 0; i < 4; i++)
        healthRow(
            JwHistoryType.steps,
            {
              'steps': [1, 0, 2, 3][i],
              'distanceMeters': 10,
              'energyCalories': 250
            },
            minute: i * 15),
      healthRow(JwHistoryType.steps,
          {'steps': 0, 'distanceMeters': 0, 'energyCalories': 0},
          minute: 120),
    ]);
    expect(s.activityBins, hasLength(24));
    expect(s.activityBins.first.start, DateTime.utc(2026, 10, 5));
    expect(s.activityBins.first.end, DateTime.utc(2026, 10, 5, 1));
    expect(s.activityBins.first.steps, 6);
    expect(s.activityBins.first.distanceMeters, 40);
    expect(s.activityBins.first.energyKcal, 1);
    expect(s.activityBins[1].steps, isNull);
    expect(s.activityBins[1].distanceMeters, isNull);
    expect(s.activityBins[1].energyKcal, isNull);
    expect(s.activityBins[2].steps, 0);
    expect(s.activityBins[2].energyKcal, 0);
    expect(s.totals.steps, 6);
  });

  // Break caught: a daily summary is distributed across fabricated hours.
  test('summary-only activity stays a daily total without hourly bins', () {
    final s = summarize([
      healthRow(JwHistoryType.metabolism, {'steps': 1234})
    ]);
    expect(s.totals.steps, 1234);
    expect(s.activityBins, isEmpty);
  });

  // Break caught: protocol time/units are reinterpreted when projecting bins.
  test('decoded quarter 95 retains wall-clock hour and calorie conversion', () {
    final bytes = Uint8List(12);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, (26 << 9) | (10 << 5) | 5);
    data.setUint16(2, 1);
    final word = (BigInt.from(95) << 53) |
        (BigInt.from(7) << 39) |
        (BigInt.from(1500) << 16) |
        BigInt.from(20);
    for (var i = 0; i < 8; i++) {
      bytes[4 + i] = ((word >> (8 * (7 - i))) & BigInt.from(255)).toInt();
    }
    final s = summarize(decodeJwHistoryField('jw:test', 2, bytes,
        batchId: '20261005-001', firstSeenOrdinal: 0));
    expect(s.activityBins.last.start, DateTime.utc(2026, 10, 5, 23));
    expect(s.activityBins.last.end, DateTime.utc(2026, 10, 6));
    expect(s.activityBins.last.steps, 7);
    expect(s.activityBins.last.distanceMeters, 20);
    expect(s.activityBins.last.energyKcal, 1.5);
  });

  // Break caught: summaries become raw samples or rename median/range meaning.
  test('valid device summary retains fields and provenance without raw samples',
      () {
    final row = healthRow(JwHistoryType.metabolism, {
      'dayHeartRateAverageBpm': 70,
      'restHeartRateBpm': 60,
      'nightHeartRateP10': 55,
      'spo2MeanPercent': 96,
      'spo2MinPercent': 90,
      'spo2Lt90Count': 0,
      'sdnnMedianMs': 50,
      'sdnnP25Ms': 40,
      'sdnnP75Ms': 70,
      'sdnnCount': 12,
      'skinTemperatureMeanCelsius': 35,
      'skinTemperatureRangeCelsius': 2.5,
      'stressAverage': 30,
      'deepSleepMinutes': 60,
      'sleepOnsetMinute': 120,
    }, validity: {
      'restFound': true,
      'spo2Valid': true,
      'hrvValid': true,
      'temperatureValid': true,
      'sleepAvailable': true,
      'hrvPartial': true,
    });
    final s = summarize([row]);
    final summary = s.dailySummaries.single;
    expect(summary.date, DateTime.utc(2026, 10, 5));
    expect(summary.recordId, row.recordId);
    expect(summary.values, {
      'dayHeartRateAverageBpm': 70,
      'restHeartRateBpm': 60,
      'nightHeartRateP10': 55,
      'spo2MeanPercent': 96,
      'spo2MinPercent': 90,
      'spo2Lt90Count': 0,
      'sdnnMedianMs': 50,
      'sdnnP25Ms': 40,
      'sdnnP75Ms': 70,
      'sdnnCount': 12,
      'skinTemperatureMeanCelsius': 35,
      'skinTemperatureRangeCelsius': 2.5,
      'stressAverage': 30,
      'deepSleepMinutes': 60,
      'sleepOnsetMinute': 120,
    });
    expect(summary.issues, {'hrvPartial'});
    expect(s.metrics.values.every((series) => series.samples.isEmpty), true);
  });

  // Break caught: false validity or unavailable temperature leaks into display.
  test('summary field gates reject unavailable groups and absent pressure zero',
      () {
    final s = summarize([
      healthRow(JwHistoryType.metabolism, {
        'sdnnMedianMs': 50,
        'sdnnCount': 10,
        'restHeartRateBpm': 60,
        'spo2MeanPercent': 96,
        'spo2Lt90Count': 0,
        'deepSleepMinutes': 80,
        'skinTemperatureMeanCelsius': 35,
        'skinTemperatureRangeCelsius': 2,
        'dayHeartRateAverageBpm': 0,
        'stressAverage': 0,
      }, validity: {
        'hrvValid': false,
        'restFound': false,
        'spo2Valid': false,
        'sleepAvailable': false,
        'temperatureValid': true,
        'temperatureDisplayUnavailable': true,
      }),
      healthRow(JwHistoryType.pressure, {'value': 0}),
    ]);
    expect(s.dailySummaries.single.values, isEmpty);
    expect(s.dailySummaries.single.issues, {'temperatureDisplayUnavailable'});
    expect(s.metrics[JwHealthMetric.pressure]!.samples, isEmpty);
  });

  // Break caught: revisions duplicate or keep stale summary values/bins.
  test('latest summary and quarter revisions win independently of replay order',
      () {
    final old = healthRow(JwHistoryType.metabolism, {'sdnnMedianMs': 30},
        validity: {'hrvValid': true});
    final latest = healthRow(JwHistoryType.metabolism, {'sdnnMedianMs': 50},
        raw: 2, batch: '20261005-002', validity: {'hrvValid': true});
    final oldQuarter = healthRow(JwHistoryType.steps, {'steps': 2});
    final latestQuarter = healthRow(JwHistoryType.steps, {'steps': 4},
        raw: 3, batch: '20261005-002');
    for (final rows in [
      [old, latest, latest, oldQuarter, latestQuarter],
      [latestQuarter, latest, oldQuarter, old, old],
    ]) {
      final s = summarize(rows);
      expect(s.dailySummaries, hasLength(1));
      expect(s.dailySummaries.single.recordId, latest.recordId);
      expect(s.dailySummaries.single.values['sdnnMedianMs'], 50);
      expect(s.activityBins.first.steps, 4);
    }
  });

  // Break caught: attaching persistence drops new projections or mixes scopes.
  test(
      'persistence preserves projections and separates storage from local quality',
      () {
    final row = healthRow(JwHistoryType.metabolism, {'sdnnMedianMs': 50},
        validity: {'hrvValid': true, 'clockJump': true});
    final quarter = healthRow(JwHistoryType.steps, {'steps': 1});
    final original = summarize([row, quarter]);
    final s = original.withPersistence(
        partialRecordIds: [row.recordId],
        availableDates: [DateTime.utc(2026, 10, 5)],
        issues: ['savedBatchFailure']);
    expect(s.activityBins.first.steps, 1);
    expect(s.dailySummaries.single.values['sdnnMedianMs'], 50);
    expect(s.stepsDayAverage, 1);
    expect(s.coverage.selectedRecordIssues, {'clockJump'});
    expect(s.coverage.storageIssues, {'savedBatchFailure'});
    expect(s.coverage.issues, {'clockJump', 'savedBatchFailure'});
    expect(s.coverage.partialRecordIds, {row.recordId});
    expect(() => s.dailySummaries.single.values['sdnnMedianMs'] = 0,
        throwsUnsupportedError);
    expect(() => s.activityBins.clear(), throwsUnsupportedError);
  });

  // Break caught: persistence leaks adjacent-date partial IDs into an empty day.
  test('outside-date quality and partial records do not qualify empty day', () {
    final outside = healthRow(JwHistoryType.metabolism, {'steps': 1},
        day: '2026-10-04', validity: {'clockJump': true});
    final s = summarize([outside]).withPersistence(
        partialRecordIds: [outside.recordId],
        availableDates: [DateTime.utc(2026, 10, 4)],
        issues: ['recoveredJournalTail']);
    expect(s.coverage.recordCount, 0);
    expect(s.coverage.selectedRecordIssues, isEmpty);
    expect(s.coverage.storageIssues, {'recoveredJournalTail'});
    expect(s.coverage.issues, {'recoveredJournalTail'});
    expect(s.coverage.hasPartialData, false);
  });

  // Break caught: legacy union issues disappear while persistence is attached.
  test(
      'legacy snapshots keep default projections and their complete issue union',
      () {
    final empty = summarize([]);
    final legacy = JwHealthSnapshot(
        deviceKey: empty.deviceKey,
        date: empty.date,
        start: empty.start,
        endExclusive: empty.endExclusive,
        period: empty.period,
        totals: empty.totals,
        days: empty.days,
        metrics: empty.metrics,
        sleepSegments: empty.sleepSegments,
        sportRecords: empty.sportRecords,
        availableDates: empty.availableDates,
        coverage: JwHealthCoverage(
            recordCount: 0,
            issues: ['legacyQuality'],
            selectedRecordIssues: ['clockJump'],
            storageIssues: ['savedBatchFailure']));
    final s = legacy.withPersistence(
        partialRecordIds: ['legacy-id'],
        availableDates: [],
        issues: ['recoveredJournalTail']);
    expect(s.activityBins, isEmpty);
    expect(s.dailySummaries, isEmpty);
    expect(s.coverage.issues, {
      'legacyQuality',
      'clockJump',
      'savedBatchFailure',
      'recoveredJournalTail'
    });
    expect(s.coverage.selectedRecordIssues, {'clockJump'});
    expect(s.coverage.storageIssues,
        {'savedBatchFailure', 'recoveredJournalTail'});
    expect(s.coverage.partialRecordIds, {'legacy-id'});
  });

  // Break caught: filtering adjacent IDs removes genuine clipped sleep warnings.
  test('contributing sleep boundary retains its partial provenance', () {
    final previous = healthRow(JwHistoryType.sleep, {'mode': 1},
        day: '2026-10-04', minute: 1380);
    final next = healthRow(JwHistoryType.sleep, {'mode': 3}, minute: 60);
    final unrelated = healthRow(JwHistoryType.sleep, {'mode': 3},
        day: '2026-10-04', minute: 60);
    final s = summarize([previous, next, unrelated]).withPersistence(
        partialRecordIds: [previous.recordId, unrelated.recordId],
        availableDates: [DateTime.utc(2026, 10, 4), DateTime.utc(2026, 10, 5)]);
    expect(s.totals.sleepMinutes, 60);
    expect(s.coverage.partialRecordIds, {previous.recordId});
  });

  // Break caught: a display-unavailable temperature is plotted as a raw value.
  test('temperature unavailable flag suppresses raw temperature display', () {
    final s = summarize([
      healthRow(JwHistoryType.heartTemperature, {
        'skinTemperatureCelsius': 35
      }, validity: {
        'temperatureRecorded': true,
        'temperatureDisplayUnavailable': true
      })
    ]);
    expect(s.metrics[JwHealthMetric.skinTemperature]!.samples, isEmpty);
    expect(s.coverage.issues, contains('temperatureDisplayUnavailable'));
  });
}
