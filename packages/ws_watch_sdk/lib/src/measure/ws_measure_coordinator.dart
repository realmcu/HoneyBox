import 'dart:async';
import 'dart:typed_data';

import '../connection/ws_link.dart';
import '../debug/ws_debug_log.dart';
import '../wire/ws_l2_message.dart';
import '../wire/ws_measure_command.dart';
import 'ws_measure_data_listener.dart';
import 'ws_measure_spot_codec.dart';

/// Routes unsolicited `0x11` spot realtime/result to [WSMeasureDataListener]s.
final class WSMeasureCoordinator {
  WSMeasureCoordinator({
    required WSLink link,
    required bool Function() isHealthSyncActive,
  })  : _link = link,
        _isHealthSyncActive = isHealthSyncActive;

  final WSLink _link;
  final bool Function() _isHealthSyncActive;
  final _listeners = <WSMeasureDataListener>{};
  StreamSubscription<WSL2Message>? _incoming;

  bool get hasListeners => _listeners.isNotEmpty;

  void addListener(WSMeasureDataListener listener) {
    _listeners.add(listener);
    _syncSubscription();
  }

  void removeListener(WSMeasureDataListener listener) {
    _listeners.remove(listener);
    _syncSubscription();
  }

  void start() {
    _syncSubscription();
  }

  void dispose() {
    unawaited(_incoming?.cancel());
    _incoming = null;
    _listeners.clear();
  }

  void _syncSubscription() {
    if (_listeners.isEmpty) {
      unawaited(_incoming?.cancel());
      _incoming = null;
      return;
    }
    if (_incoming != null) return;
    _incoming = _link.incoming.listen(_onIncoming);
  }

  void _onIncoming(WSL2Message message) {
    if (message.command != WSMeasureCommand.command) return;
    if (_listeners.isEmpty) return;
    if (_isHealthSyncActive()) return;
    final lane = WSSpotMeasureLanes.laneForKey(message.key);
    if (lane == null) return;
    if (message.key == lane.realtime) {
      _dispatchRealtime(lane, message.value);
      return;
    }
    if (message.key == lane.result) {
      _dispatchResult(lane, message.value);
    }
  }

  void _dispatchRealtime(WSSpotMeasureLane lane, Uint8List value) {
    WSWatchDebugLog.apiOut(
      'WSMeasureCoordinator.spotRealtime',
      'lane=0x${lane.start.toRadixString(16)} len=${value.length}',
    );
    switch (lane) {
      case WSSpotMeasureLanes.heartRate:
        final sample = WSMeasureSpotCodec.heartRateRealtime(value);
        if (sample == null) return;
        _notify((l) => l.onHeartRateReceived([sample]));
      case WSSpotMeasureLanes.bloodOxygen:
        final sample = WSMeasureSpotCodec.bloodOxygenRealtime(value);
        if (sample == null) return;
        _notify((l) => l.onBloodOxygenReceived([sample]));
      case WSSpotMeasureLanes.temperature:
        final sample = WSMeasureSpotCodec.temperatureRealtime(value);
        if (sample == null) return;
        _notify((l) => l.onTemperatureReceived([sample]));
      case WSSpotMeasureLanes.bloodGlucose:
        final sample = WSMeasureSpotCodec.bloodGlucoseRealtime(value);
        if (sample == null) return;
        _notify((l) => l.onBloodGlucoseReceived([sample]));
      default:
        break;
    }
  }

  void _dispatchResult(WSSpotMeasureLane lane, Uint8List value) {
    WSWatchDebugLog.apiOut(
      'WSMeasureCoordinator.spotResult',
      'lane=0x${lane.start.toRadixString(16)} len=${value.length}',
    );
    if (value.isNotEmpty && value[0] != WSMeasureSpotCodec.resultSuccess) {
      if (lane == WSSpotMeasureLanes.heartRate) {
        _notify((l) => l.onHeartRateSpotMeasureEndedByDevice());
      }
      return;
    }
    switch (lane) {
      case WSSpotMeasureLanes.heartRate:
        final sample = WSMeasureSpotCodec.heartRateResult(value);
        if (sample == null) return;
        _notify((l) => l.onHeartRateReceived([sample]));
      case WSSpotMeasureLanes.bloodPressure:
        final sample = WSMeasureSpotCodec.bloodPressureResult(value);
        if (sample == null) return;
        _notify((l) => l.onBloodPressureReceived([sample]));
      case WSSpotMeasureLanes.bloodOxygen:
        final sample = WSMeasureSpotCodec.bloodOxygenResult(value);
        if (sample == null) return;
        _notify((l) => l.onBloodOxygenReceived([sample]));
      case WSSpotMeasureLanes.temperature:
        final sample = WSMeasureSpotCodec.temperatureResult(value);
        if (sample == null) return;
        _notify((l) => l.onTemperatureReceived([sample]));
      case WSSpotMeasureLanes.bloodGlucose:
        final sample = WSMeasureSpotCodec.bloodGlucoseResult(value);
        if (sample == null) return;
        _notify((l) => l.onBloodGlucoseReceived([sample]));
      default:
        break;
    }
  }

  void _notify(void Function(WSMeasureDataListener listener) dispatch) {
    for (final listener in _listeners) {
      dispatch(listener);
    }
  }
}
