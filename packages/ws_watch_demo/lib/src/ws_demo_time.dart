import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'compat/ws_demo_compat.dart';

DateTime wsDemoWallTimeToLocal(int wallSeconds) =>
    DateTime.fromMillisecondsSinceEpoch(wallSeconds * 1000, isUtc: false);

WSTodayActivitySummary wsDemoTodaySummaryFromSnapshot(WSTodaySnapshot snap) =>
    WSTodayActivitySummary(
      steps: snap.steps,
      caloriesCal: snap.caloriesTenthKcal,
      distanceMeters: snap.distanceMeters,
      recentSteps: 0,
      recentCaloriesCal: 0,
      recentDistanceMeters: 0,
    );
