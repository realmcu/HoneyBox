import 'dart:async';

import '../connection/jw_link.dart';
import '../connection/jw_protocol.dart';
import 'jw_measure_codec.dart';
import 'jw_measure_data_listener.dart';

/// Routes unsolicited `cmd 0x05` spot-measure payloads to [JWMeasureDataListener]s.
///
/// History sync owns batch keys (`0x13`, `0x2c`, `0x40`, …). Key `0x0f` is ignored
/// during sync and handled here. Key `0x40` is delivered to listeners only while
/// blood-sugar spot measure is active and health sync is not.
final class JWMeasureCoordinator {
  JWMeasureCoordinator({
    required JWLink link,
    required bool Function() isHealthSyncActive,
    required bool Function() temperatureCapable,
  })  : _link = link,
        _isHealthSyncActive = isHealthSyncActive,
        _temperatureCapable = temperatureCapable;

  final JWLink _link;
  final bool Function() _isHealthSyncActive;
  final bool Function() _temperatureCapable;
  final _listeners = <JWMeasureDataListener>{};
  StreamSubscription<JWProtocolMessage>? _events;
  bool _bloodSugarSpotActive = false;

  bool get hasListeners => _listeners.isNotEmpty;

  set bloodSugarSpotActive(bool value) {
    _bloodSugarSpotActive = value;
    _syncSubscription();
  }

  void addListener(JWMeasureDataListener listener) {
    _listeners.add(listener);
    _syncSubscription();
  }

  void removeListener(JWMeasureDataListener listener) {
    _listeners.remove(listener);
    _syncSubscription();
  }

  void dispose() {
    _events?.cancel();
    _events = null;
    _listeners.clear();
    _bloodSugarSpotActive = false;
  }

  void _syncSubscription() {
    if (_listeners.isEmpty && !_bloodSugarSpotActive) {
      unawaited(_events?.cancel());
      _events = null;
      return;
    }
    if (_events != null) return;
    _events = _link.events.listen(_onMessage);
  }

  void _onMessage(JWProtocolMessage message) {
    if (message.command != 5 || _listeners.isEmpty) return;
    final syncing = _isHealthSyncActive();
    if (message.key == 0x0f) {
      final payload = decodeSpotHeartRatePayload(
        message.value,
        temperatureCapable: _temperatureCapable(),
      );
      if (payload == null || payload.isEmpty) return;
      if (payload.heartRates.isNotEmpty) {
        _dispatch((l) => l.onHeartRateReceived(payload.heartRates));
      }
      if (payload.temperatures.isNotEmpty) {
        _dispatch((l) => l.onTemperatureReceived(payload.temperatures));
      }
      return;
    }
    if (message.key == 0x13) {
      if (syncing) return;
      final bp = decodeSpotBloodPressure(message.value);
      if (bp != null && bp.isNotEmpty) {
        _dispatch((l) => l.onBloodPressureReceived(bp));
      }
      return;
    }
    if (message.key == 0x2c) {
      if (syncing) return;
      final spo2 = decodeSpotBloodOxygen(message.value);
      if (spo2 != null && spo2.isNotEmpty) {
        _dispatch((l) => l.onBloodOxygenReceived(spo2));
      }
      return;
    }
    if (message.key == 0x40) {
      if (syncing || !_bloodSugarSpotActive) return;
      final glu = decodeSpotBloodGlucose(message.value);
      if (glu != null && glu.isNotEmpty) {
        _dispatch((l) => l.onBloodGlucoseReceived(glu));
      }
    }
  }

  void _dispatch(void Function(JWMeasureDataListener listener) notify) {
    for (final listener in _listeners) {
      notify(listener);
    }
  }
}
