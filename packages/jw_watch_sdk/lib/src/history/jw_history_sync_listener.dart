import '../model/jw_error.dart';
import 'jw_history_models.dart';

/// Idle budget while waiting for the next incoming `cmd 0x05` history frame.
/// Decoding and background persistence do not extend this timer.
const kJWHistorySyncIdleTimeout = Duration(seconds: 30);

/// HL §5.7 START payload type (`HISTORY_DATA_*`), not the message key `0x07`.
enum JWHistorySyncCategory {
  activity,
  sleep,
  heartRate,
  /// Parsed from heart-rate wire payloads; not a separate START wire bucket.
  temperature,
  bloodPressure,
  sport,
  bloodOxygen,
  hrv,
  pressure,
  legacyInternal,
  metabDaily,
  readinessHistory,
}

/// Device-announced record plan for one health sync round.
final class JWHistorySyncPlan {
  const JWHistorySyncPlan({
    required this.totalWireRecords,
    required this.wireCountsByCategory,
  });

  final int totalWireRecords;
  final Map<JWHistorySyncCategory, int> wireCountsByCategory;
}

/// Failure delivered through [JWHistorySyncListener.onSyncFailed].
final class JWHistorySyncFailure {
  const JWHistorySyncFailure({required this.code, required this.message});

  final JWErrorCode code;
  final String message;
}

/// Health sync callbacks aligned with Android `JWSyncDataListener`.
abstract interface class JWHistorySyncListener {
  void onSyncStart(JWHistorySyncPlan plan);

  void onSyncProgress(int receivedWireRecords, int totalWireRecords);

  void onSyncFinished();

  void onSyncFailed(JWHistorySyncFailure failure);

  void onActivityReceived(List<JWActivity> batch);

  void onSleepReceived(List<JWSleep> batch);

  void onHeartRateReceived(List<JWHeartRate> batch);

  void onTemperatureReceived(List<JWTemperature> batch);

  void onBloodPressureReceived(List<JWBloodPressure> batch);

  void onBloodOxygenReceived(List<JWBloodOxygen> batch);

  void onHrvReceived(List<JWHrv> batch);

  void onPressureReceived(List<JWPressure> batch);

  void onSportReceived(List<JWSport> batch);
}
