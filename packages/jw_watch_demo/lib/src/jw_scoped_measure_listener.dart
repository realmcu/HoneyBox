import 'package:flutter/foundation.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_log.dart';
import 'jw_measure_module.dart';
import 'jw_measure_presenter.dart';

/// Per-detail-page listener; only surfaces data for one [JWMeasureModuleKind].
final class JwScopedMeasureListener extends ChangeNotifier
    implements JWMeasureDataListener {
  JwScopedMeasureListener(this.kind);

  final JWMeasureModuleKind kind;
  JWMeasure? _measure;

  /// Demo UI hook when the watch ends HR spot measure (`0x10`).
  void Function()? onHeartRateSpotEndedByDevice;

  String? spotValue;
  String? lastEventLine;
  final _log = <String>[];

  List<String> get log => List.unmodifiable(_log);

  void attach(JWWatchSession session) {
    if (_measure != null) return;
    _measure = session.measure;
    _measure!.addMeasureDataListener(this);
    JwDemoLog.info('measure listener attach kind=$kind');
  }

  void detach() {
    if (_measure != null) {
      JwDemoLog.info('measure listener detach kind=$kind');
    }
    _measure?.removeMeasureDataListener(this);
    _measure = null;
  }

  void _notifyUi() {
    if (hasListeners) notifyListeners();
  }

  void _append(String line) {
    lastEventLine = line;
    _log.add(line);
    while (_log.length > 40) {
      _log.removeAt(0);
    }
  }

  @override
  void onHeartRateReceived(List<JWHeartRate> batch) {
    if (kind != JWMeasureModuleKind.heartRate || batch.isEmpty) return;
    JwDemoLog.info(
      'onHeartRateReceived n=${batch.length} bpm=${batch.last.heartRate}',
    );
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onBloodPressureReceived(List<JWBloodPressure> batch) {
    if (kind != JWMeasureModuleKind.bloodPressure || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onBloodOxygenReceived(List<JWBloodOxygen> batch) {
    if (kind != JWMeasureModuleKind.bloodOxygen || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onTemperatureReceived(List<JWTemperature> batch) {
    if (kind != JWMeasureModuleKind.temperature || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onBloodGlucoseReceived(List<JWBloodGlucose> batch) {
    if (kind != JWMeasureModuleKind.bloodGlucose || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onHeartRateSpotMeasureEndedByDevice() {
    if (kind != JWMeasureModuleKind.heartRate) return;
    JwDemoLog.info('onHeartRateSpotMeasureEndedByDevice');
    _append('设备结束点测');
    onHeartRateSpotEndedByDevice?.call();
    _notifyUi();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
