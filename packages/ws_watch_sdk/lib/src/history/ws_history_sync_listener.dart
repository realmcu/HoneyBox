import '../model/ws_error.dart';

const kWSHistorySyncIdleTimeout = Duration(seconds: 30);

enum WSHistorySyncCategory {
  activity,
  sleep,
  heartRate,
  bloodPressure,
  bloodOxygen,
  hrv,
  pressure,
  temperature,
  bloodGlucose,
  sport,
}

final class WSHistorySyncPlan {
  const WSHistorySyncPlan({
    required this.totalWireRecords,
    required this.wireCountsByCategory,
  });

  final int totalWireRecords;
  final Map<WSHistorySyncCategory, int> wireCountsByCategory;
}

final class WSHistorySyncFailure {
  const WSHistorySyncFailure({required this.code, required this.message});

  final WSErrorCode code;
  final String message;
}

/// Honey `0x05` health sync callbacks (aligned with JW listener shape).
abstract interface class WSHistorySyncListener {
  void onSyncStart(WSHistorySyncPlan plan);

  void onSyncProgress(int receivedWireRecords, int totalWireRecords);

  void onSyncFinished();

  void onSyncFailed(WSHistorySyncFailure failure);
}

/// No-op listener for tests and simple callers.
final class WSHistorySyncNoOpListener implements WSHistorySyncListener {
  const WSHistorySyncNoOpListener();

  @override
  void onSyncFailed(WSHistorySyncFailure failure) {}

  @override
  void onSyncFinished() {}

  @override
  void onSyncProgress(int receivedWireRecords, int totalWireRecords) {}

  @override
  void onSyncStart(WSHistorySyncPlan plan) {}
}
