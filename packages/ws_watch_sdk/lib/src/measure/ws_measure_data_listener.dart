import '../history/ws_history_models.dart';

/// Real-time `0x11` spot-measure values (WS Honey protocol).
abstract interface class WSMeasureDataListener {
  void onHeartRateReceived(List<WSHeartRate> batch);

  void onBloodPressureReceived(List<WSBloodPressure> batch);

  void onBloodOxygenReceived(List<WSBloodOxygen> batch);

  void onTemperatureReceived(List<WSTemperature> batch);

  void onBloodGlucoseReceived(List<WSBloodGlucose> batch);

  /// Device ended spot measure without a success record (e.g. watch-side cancel).
  void onHeartRateSpotMeasureEndedByDevice();
}
