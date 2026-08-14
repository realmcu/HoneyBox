import 'package:honeybox/pages/watch/health/watch_health_data.dart';
import 'package:honeybox/services/watch_health_protocol.dart';

/// Two activity buckets on 2026-07-30 (08:00 and 08:15 local) plus a sleep
/// run spanning the previous midnight.
///
/// Timestamps are built from local `DateTime`s so the fixture stays stable
/// regardless of the machine's timezone -- version 1 decodes UTC epoch seconds
/// and converts to local before anything downstream sees them.
WatchHealthSnapshot watchHealthFixture() => WatchHealthSnapshot.fromRecords(
      syncedAt: DateTime(2026, 7, 30, 12),
      sportRecords: [
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
