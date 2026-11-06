import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_measure_presenter.dart';

/// Demo-side spot-measure event log; does not persist to [JWHistoryStore].
final class JwMeasureEventController extends ChangeNotifier
    implements JWMeasureDataListener {
  static const maxLogEntries = 80;

  JWMeasure? _measure;
  final _log = <String>[];

  List<String> get log => List.unmodifiable(_log);

  bool get isAttached => _measure != null;

  void attach(JWWatchSession session) {
    if (_measure != null) return;
    _measure = session.measure;
    _measure!.addMeasureDataListener(this);
    _append('已注册 JWMeasureDataListener');
    scheduleMicrotask(notifyListeners);
  }

  void detach() {
    if (_measure == null) return;
    _measure!.removeMeasureDataListener(this);
    _measure = null;
    _append('已移除 listener');
    notifyListeners();
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
  }

  void note(String message) {
    _append(message);
    notifyListeners();
  }

  void _append(String message) {
    _log.add(message);
    while (_log.length > maxLogEntries) {
      _log.removeAt(0);
    }
  }

  @override
  void onHeartRateReceived(List<JWHeartRate> batch) {
    _append(jwMeasureBatchSummary('点测心率', batch));
    notifyListeners();
  }

  @override
  void onBloodPressureReceived(List<JWBloodPressure> batch) {
    _append(jwMeasureBatchSummary('点测血压', batch));
    notifyListeners();
  }

  @override
  void onBloodOxygenReceived(List<JWBloodOxygen> batch) {
    _append(jwMeasureBatchSummary('点测血氧', batch));
    notifyListeners();
  }

  @override
  void onTemperatureReceived(List<JWTemperature> batch) {
    _append(jwMeasureBatchSummary('点测体温', batch));
    notifyListeners();
  }

  @override
  void onBloodGlucoseReceived(List<JWBloodGlucose> batch) {
    _append(jwMeasureBatchSummary('点测血糖', batch));
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
