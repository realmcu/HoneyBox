import 'package:flutter/foundation.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_demo_log.dart';
import 'ws_measure_module.dart';
import 'ws_measure_presenter.dart';

/// Per-detail-page listener; only surfaces data for one [WSMeasureModuleKind].
final class WsScopedMeasureListener extends ChangeNotifier
    implements WSMeasureDataListener {
  WsScopedMeasureListener(this.kind);

  final WSMeasureModuleKind kind;
  WSMeasure? _measure;

  void Function()? onHeartRateSpotEndedByDevice;

  String? spotValue;
  String? lastEventLine;
  final _log = <String>[];

  List<String> get log => List.unmodifiable(_log);

  void attach(WSWatchSession session) {
    if (_measure != null) return;
    _measure = session.measure;
    _measure!.addMeasureDataListener(this);
    WsDemoLog.info('measure listener attach kind=$kind');
  }

  void detach() {
    if (_measure != null) {
      WsDemoLog.info('measure listener detach kind=$kind');
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
  void onHeartRateReceived(List<WSHeartRate> batch) {
    if (kind != WSMeasureModuleKind.heartRate || batch.isEmpty) return;
    WsDemoLog.info(
      'onHeartRateReceived n=${batch.length} bpm=${batch.last.bpm}',
    );
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onBloodPressureReceived(List<WSBloodPressure> batch) {
    if (kind != WSMeasureModuleKind.bloodPressure || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onBloodOxygenReceived(List<WSBloodOxygen> batch) {
    if (kind != WSMeasureModuleKind.bloodOxygen || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onTemperatureReceived(List<WSTemperature> batch) {
    if (kind != WSMeasureModuleKind.temperature || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onBloodGlucoseReceived(List<WSBloodGlucose> batch) {
    if (kind != WSMeasureModuleKind.bloodGlucose || batch.isEmpty) return;
    spotValue = jwMeasureSpotValueLabel(batch.last);
    _append(jwMeasureBatchSummary('点测', batch));
    _notifyUi();
  }

  @override
  void onHeartRateSpotMeasureEndedByDevice() {
    if (kind != WSMeasureModuleKind.heartRate) return;
    WsDemoLog.info('onHeartRateSpotMeasureEndedByDevice');
    _append('点测已结束');
    onHeartRateSpotEndedByDevice?.call();
    _notifyUi();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
