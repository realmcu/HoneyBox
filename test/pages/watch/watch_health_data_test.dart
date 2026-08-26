import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/health/watch_health_data.dart';
import 'package:honeybox/services/watch_health_protocol.dart';

void main() {
  final snapshot = WatchHealthSnapshot.fromRecords(
    syncedAt: DateTime(2026, 7, 30, 12),
    sportRecords: [
      // Yesterday -- excluded from "today" metrics, included in week trends.
      WatchSportRecord(
        timestamp: DateTime(2026, 7, 29, 20),
        mode: WatchSportMode.run,
        steps: 900,
        caloriesDeciKcal: 200,
        distanceMeters: 700,
        heartRate: 75,
        hasHeartRate: true,
      ),
      WatchSportRecord(
        timestamp: DateTime(2026, 7, 30, 8),
        mode: WatchSportMode.run,
        steps: 600,
        caloriesDeciKcal: 125,
        distanceMeters: 420,
        heartRate: 72,
        hasHeartRate: true,
      ),
      WatchSportRecord(
        timestamp: DateTime(2026, 7, 30, 8, 15),
        mode: WatchSportMode.invalid,
        steps: 400,
        caloriesDeciKcal: 75,
        distanceMeters: 280,
        heartRate: 78,
        hasHeartRate: true,
      ),
    ],
    sleepRecords: [
      WatchSleepRecord(
        timestamp: DateTime(2026, 7, 29, 23),
        state: WatchSleepState.deep,
      ),
      WatchSleepRecord(
        timestamp: DateTime(2026, 7, 30, 1),
        state: WatchSleepState.light,
      ),
      WatchSleepRecord(
        timestamp: DateTime(2026, 7, 30, 3),
        state: WatchSleepState.wake,
      ),
    ],
  );

  test('computes today metrics from actual records', () {
    expect(snapshot.steps, 1000);
    expect(snapshot.distanceMeters, 700);
    expect(snapshot.caloriesKcal, 20);
    expect(snapshot.latestHeartRate, 78);
    expect(snapshot.minimumHeartRate, 72);
    expect(snapshot.maximumHeartRate, 78);
  });

  test('ignores bucket heart rate when the HAS_HR flag is clear', () {
    final noHr = WatchHealthSnapshot.fromRecords(
      syncedAt: DateTime(2026, 7, 30, 12),
      sportRecords: [
        WatchSportRecord(
          timestamp: DateTime(2026, 7, 30, 8),
          mode: WatchSportMode.walk,
          steps: 100,
          caloriesDeciKcal: 10,
          distanceMeters: 80,
        ),
      ],
      sleepRecords: const [],
    );

    expect(noHr.steps, 100);
    expect(noHr.latestHeartRate, isNull);
    expect(noHr.heartRateBuckets, isEmpty);
  });

  test('computes sleep stages from state transitions', () {
    expect(snapshot.sleepMinutes, 240);
    expect(snapshot.sleepRange, '23:00 - 03:00');
    expect(
      snapshot.sleepStages
          .map((stage) => (stage.state, stage.minutes))
          .toList(),
      [(WatchSleepState.deep, 120), (WatchSleepState.light, 120)],
    );
  });

  test('buckets the day trend by wall-clock hour', () {
    final trend = snapshot.trend(WatchHealthPeriod.day);

    // Both of today's buckets land at 08:00-08:15, i.e. the 08:00-12:00 slot.
    final slot = trend.points[2];
    expect(slot.label, '8时');
    expect(slot.steps, 1000);
    expect(slot.heartRate, 75); // average of 72 and 78
    expect(trend.points.where((point) => point.steps > 0), hasLength(1));
  });

  test('aggregates real records for week trends', () {
    final trend = snapshot.trend(WatchHealthPeriod.week);

    expect(
        trend.points.map((point) => point.steps).reduce((a, b) => a + b), 1900);
    expect(trend.points.last.heartRate, 75);
    expect(trend.points.where((point) => point.steps > 0), hasLength(2));
  });

  test('attributes the bucket closed at midnight to the preceding day', () {
    final midnightSnapshot = WatchHealthSnapshot.fromRecords(
      syncedAt: DateTime(2026, 8, 27, 12),
      sportRecords: [
        WatchSportRecord(
          timestamp: DateTime(2026, 8, 26, 23, 45),
          mode: WatchSportMode.walk,
          steps: 321,
          caloriesDeciKcal: 20,
          distanceMeters: 210,
        ),
      ],
      sleepRecords: const [],
    );

    expect(midnightSnapshot.steps, 0);
    final trend = midnightSnapshot.trend(WatchHealthPeriod.week);
    expect(trend.points[trend.points.length - 2].label, '8/26');
    expect(trend.points[trend.points.length - 2].steps, 321);
    expect(trend.points.last.label, '8/27');
    expect(trend.points.last.steps, 0);
  });

  test('exposes null values instead of inventing unavailable data', () {
    final empty = WatchHealthSnapshot.fromRecords(
      syncedAt: DateTime(2026, 7, 30),
      sportRecords: const [],
      sleepRecords: const [],
    );

    expect(empty.latestHeartRate, isNull);
    expect(empty.minimumHeartRate, isNull);
    expect(empty.sleepRange, isNull);
    expect(empty.trend(WatchHealthPeriod.day).points, isNotEmpty);
  });
}
