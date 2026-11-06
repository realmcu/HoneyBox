import '../history/jw_history_models.dart';

/// Real-time spot-measure values (Android `JWMeasureDataListener`).
///
/// Does not write to [JWHistoryStore]; hosts may persist if product requires.
abstract interface class JWMeasureDataListener {
  void onHeartRateReceived(List<JWHeartRate> batch);

  void onBloodPressureReceived(List<JWBloodPressure> batch);

  void onBloodOxygenReceived(List<JWBloodOxygen> batch);

  void onTemperatureReceived(List<JWTemperature> batch);

  void onBloodGlucoseReceived(List<JWBloodGlucose> batch);
}
