import 'dart:async';

import '../connection/ws_link.dart';
import '../debug/ws_debug_log.dart';
import '../wire/ws_health_monitor_codec.dart';
import '../wire/ws_measure_command.dart';
import '../wire/ws_l2_message.dart';
import '../wire/ws_settings_command.dart';
import 'ws_measure_coordinator.dart';
import 'ws_measure_data_listener.dart';
import 'ws_measure_models.dart';
import 'ws_measure_events.dart';
import 'ws_measure_spot_codec.dart';

final class WSMeasure {
  WSMeasure({
    required WSLink link,
    required bool Function() isConnected,
    required bool Function() isHealthSyncActive,
    WSMeasureCoordinator? coordinator,
    Duration replyTimeout = const Duration(seconds: 8),
  })  : _link = link,
        _isConnected = isConnected,
        _isHealthSyncActive = isHealthSyncActive,
        _coordinator = coordinator,
        _replyTimeout = replyTimeout {
    _incoming = _link.incoming.listen(_onIncoming);
  }

  final WSLink _link;
  final bool Function() _isConnected;
  final bool Function() _isHealthSyncActive;
  final WSMeasureCoordinator? _coordinator;
  final Duration _replyTimeout;
  final _events = StreamController<WSMeasureEvent>.broadcast(sync: true);
  late final StreamSubscription<WSL2Message> _incoming;

  Stream<WSMeasureEvent> get events => _events.stream;

  /// Sim 固定可选间隔；协议未单独定义「间隔列表」Key。
  static const List<int> defaultHeartRateIntervalOptions = [5, 10, 15, 30, 60];

  void addMeasureDataListener(WSMeasureDataListener listener) {
    _coordinator?.addListener(listener);
  }

  void removeMeasureDataListener(WSMeasureDataListener listener) {
    _coordinator?.removeListener(listener);
  }

  // --- 自动监测（0x02）---

  Future<WSAutoMeasureConfig> readHeartRateAutoMeasure() async =>
      WSAutoMeasureConfig.fromSchedule(
        await _readAutoSchedule(WSHealthMonitorCodec.keyHeartRateAuto),
      );

  Future<void> setHeartRateAutoMeasure(WSAutoMeasureConfig config) async =>
      _writeAutoSchedule(
        WSHealthMonitorCodec.keyHeartRateAuto,
        config.toSchedule(),
      );

  /// Full time-window form of heart-rate automatic monitoring.
  Future<WSAutoMeasureSchedule> readHeartRateAutoMeasureSchedule() =>
      _readAutoSchedule(WSHealthMonitorCodec.keyHeartRateAuto);

  Future<void> setHeartRateAutoMeasureSchedule(
          WSAutoMeasureSchedule schedule) =>
      _writeAutoSchedule(WSHealthMonitorCodec.keyHeartRateAuto, schedule);

  Future<List<int>> readHeartRateIntervalOptions() async {
    _requireConnected();
    return List<int>.unmodifiable(defaultHeartRateIntervalOptions);
  }

  Future<WSAutoMeasureSchedule> readHrvAutoMeasure() =>
      _readAutoSchedule(WSHealthMonitorCodec.keyHrvAuto);
  Future<void> setHrvAutoMeasure(WSAutoMeasureSchedule schedule) =>
      _writeAutoSchedule(WSHealthMonitorCodec.keyHrvAuto, schedule);

  Future<WSAutoMeasureConfig> readSpO2AutoMeasure() async =>
      WSAutoMeasureConfig.fromSchedule(
        await _readAutoSchedule(WSHealthMonitorCodec.keySpO2Auto),
      );

  Future<void> setSpO2AutoMeasure(WSAutoMeasureConfig config) async =>
      _writeAutoSchedule(
        WSHealthMonitorCodec.keySpO2Auto,
        config.toSchedule(),
      );

  Future<WSAutoMeasureSchedule> readSpO2AutoMeasureSchedule() =>
      _readAutoSchedule(WSHealthMonitorCodec.keySpO2Auto);

  Future<void> setSpO2AutoMeasureSchedule(WSAutoMeasureSchedule schedule) =>
      _writeAutoSchedule(WSHealthMonitorCodec.keySpO2Auto, schedule);

  Future<WSAutoMeasureConfig> readBloodPressureAutoMeasure() async =>
      WSAutoMeasureConfig.fromSchedule(
        await _readAutoSchedule(WSHealthMonitorCodec.keyBloodPressureAuto),
      );

  Future<void> setBloodPressureAutoMeasure(WSAutoMeasureConfig config) async =>
      _writeAutoSchedule(
        WSHealthMonitorCodec.keyBloodPressureAuto,
        config.toSchedule(),
      );

  Future<WSAutoMeasureSchedule> readBloodPressureAutoMeasureSchedule() =>
      _readAutoSchedule(WSHealthMonitorCodec.keyBloodPressureAuto);

  Future<void> setBloodPressureAutoMeasureSchedule(
          WSAutoMeasureSchedule schedule) =>
      _writeAutoSchedule(WSHealthMonitorCodec.keyBloodPressureAuto, schedule);

  Future<WSBloodSugarAutoMeasureConfig> readBloodSugarAutoMeasure() async {
    final schedule =
        await _readAutoSchedule(WSHealthMonitorCodec.keyBloodSugarAuto);
    return WSBloodSugarAutoMeasureConfig.fromSchedule(schedule);
  }

  Future<void> setBloodSugarAutoMeasure(
    WSBloodSugarAutoMeasureConfig config,
  ) async =>
      _writeAutoSchedule(
        WSHealthMonitorCodec.keyBloodSugarAuto,
        config.toSchedule(),
      );

  Future<WSAutoMeasureSchedule> readBloodSugarAutoMeasureSchedule() =>
      _readAutoSchedule(WSHealthMonitorCodec.keyBloodSugarAuto);

  Future<void> setBloodSugarAutoMeasureSchedule(
          WSAutoMeasureSchedule schedule) =>
      _writeAutoSchedule(WSHealthMonitorCodec.keyBloodSugarAuto, schedule);

  Future<void> setPressureAutoMeasure(bool enabled) async {
    final previous =
        await _readAutoSchedule(WSHealthMonitorCodec.keyPressureAuto);
    await _writeAutoSchedule(
      WSHealthMonitorCodec.keyPressureAuto,
      previous.copyWith(
        enabled: enabled,
        intervalMinutes:
            previous.intervalMinutes == 0 ? 30 : previous.intervalMinutes,
      ),
    );
  }

  Future<WSAutoMeasureSchedule> readPressureAutoMeasure() =>
      _readAutoSchedule(WSHealthMonitorCodec.keyPressureAuto);
  Future<void> setPressureAutoMeasureSchedule(WSAutoMeasureSchedule schedule) =>
      _writeAutoSchedule(WSHealthMonitorCodec.keyPressureAuto, schedule);

  Future<WSTemperatureControlSetting> readTemperatureControl() async {
    _requireConnected();
    final auto =
        await _readAutoSchedule(WSHealthMonitorCodec.keyTemperatureAuto);
    final unitReply = await _link.request(
      WSSettingsCommand.readKey(WSHealthMonitorCodec.keyTemperatureUnit),
      replyKey: WSHealthMonitorCodec.keyTemperatureUnit,
      timeout: _replyTimeout,
    );
    if (!WSSettingsCommand.isReadReplyForKey(
      unitReply,
      WSHealthMonitorCodec.keyTemperatureUnit,
    )) {
      throw const FormatException('unexpected temperature unit reply');
    }
    final celsius = WSHealthMonitorCodec.decodeTemperatureUnitCelsius(
      WSHealthMonitorCodec.extractSettingBody(unitReply),
    );
    return WSTemperatureControlSetting(
      enabled: auto.enabled,
      adjust: false,
      celsius: celsius,
    );
  }

  Future<WSAutoMeasureSchedule> readTemperatureAutoMeasureSchedule() =>
      _readAutoSchedule(WSHealthMonitorCodec.keyTemperatureAuto);

  Future<void> setTemperatureAutoMeasureSchedule(
          WSAutoMeasureSchedule schedule) =>
      _writeAutoSchedule(WSHealthMonitorCodec.keyTemperatureAuto, schedule);

  Future<void> setTemperatureControl(
      WSTemperatureControlSetting setting) async {
    _requireConnected();
    final previous =
        await _readAutoSchedule(WSHealthMonitorCodec.keyTemperatureAuto);
    await _writeAutoSchedule(
      WSHealthMonitorCodec.keyTemperatureAuto,
      previous.copyWith(
        enabled: setting.enabled,
        intervalMinutes:
            previous.intervalMinutes == 0 ? 30 : previous.intervalMinutes,
      ),
    );
    await _link.send(
      WSSettingsCommand.setKey(
        WSHealthMonitorCodec.keyTemperatureUnit,
        WSHealthMonitorCodec.encodeTemperatureUnit(setting.celsius),
      ),
    );
  }

  Future<WSAutoMeasureSchedule> readHeatStressAutoMeasure() async =>
      _readAutoSchedule(WSHealthMonitorCodec.keyHeatStressAuto);

  Future<void> setHeatStressAutoMeasure(WSAutoMeasureSchedule schedule) async =>
      _writeAutoSchedule(WSHealthMonitorCodec.keyHeatStressAuto, schedule);

  // --- 点测（0x11）---

  Future<void> startHeartRateSpot() => _startSpot(WSSpotMeasureLanes.heartRate);

  Future<void> stopHeartRateSpot() => _stopSpot(WSSpotMeasureLanes.heartRate);

  Future<void> startBloodPressureSpotMeasure() =>
      _startSpot(WSSpotMeasureLanes.bloodPressure);

  Future<void> stopBloodPressureSpotMeasure() =>
      _stopSpot(WSSpotMeasureLanes.bloodPressure);

  Future<void> startSpO2SpotMeasure() =>
      _startSpot(WSSpotMeasureLanes.bloodOxygen);

  Future<void> stopSpO2SpotMeasure() =>
      _stopSpot(WSSpotMeasureLanes.bloodOxygen);

  Future<void> checkSpO2SpotMeasure() => _querySpotStatus();

  Future<void> startTemperatureSpotMeasure() =>
      _startSpot(WSSpotMeasureLanes.temperature);

  Future<void> stopTemperatureSpotMeasure() =>
      _stopSpot(WSSpotMeasureLanes.temperature);

  Future<void> checkTemperatureSpotMeasure() => _querySpotStatus();

  Future<void> startBloodGlucoseSpotMeasure() =>
      _startSpot(WSSpotMeasureLanes.bloodGlucose);

  Future<void> stopBloodGlucoseSpotMeasure() =>
      _stopSpot(WSSpotMeasureLanes.bloodGlucose);

  Future<void> startHrvSpotMeasure() => _startSpot(WSSpotMeasureLanes.hrv);
  Future<void> stopHrvSpotMeasure() => _stopSpot(WSSpotMeasureLanes.hrv);
  Future<void> startPressureSpotMeasure() =>
      _startSpot(WSSpotMeasureLanes.pressure);
  Future<void> stopPressureSpotMeasure() =>
      _stopSpot(WSSpotMeasureLanes.pressure);
  Future<void> startContinuousHeartRate() =>
      _startSpot(WSSpotMeasureLanes.continuousHeartRate);
  Future<void> stopContinuousHeartRate() =>
      _stopSpot(WSSpotMeasureLanes.continuousHeartRate);

  Future<WSSpotMeasureStatus> querySpotStatus() async {
    _requireConnected();
    final reply = await _link.request(
      WSMeasureCommand.querySpotStatus(),
      replyKey: WSMeasureCommand.keyStatusReply,
      timeout: _replyTimeout,
    );
    return WSMeasureSpotCodec.decodeStatus(reply.value);
  }

  Future<int> startSport(int mode) async {
    _requireSpotReady();
    final reply = await _link.request(
      WSMeasureCommand.sportStart(mode),
      replyKey: WSMeasureCommand.keySportStartReply,
      timeout: _replyTimeout,
    );
    if (reply.value.length < 2 || reply.value[0] != mode) {
      throw const FormatException('invalid sport start reply');
    }
    return reply.value[1];
  }

  Future<void> controlSport(int action) {
    _requireConnected();
    if (action < 0 || action > 2) throw ArgumentError.value(action, 'action');
    return _link.send(WSMeasureCommand.sportControl(action));
  }

  Future<List<int>> querySportModes() async {
    _requireConnected();
    final reply = await _link.request(
      WSMeasureCommand.sportModesQuery(),
      replyKey: WSMeasureCommand.keySportModesReply,
      timeout: _replyTimeout,
    );
    if (reply.value.isEmpty || reply.value.length < 1 + reply.value[0]) {
      throw const FormatException('invalid sport modes reply');
    }
    return List.unmodifiable(reply.value.sublist(1, 1 + reply.value[0]));
  }

  Future<WSSportState> querySportState() async {
    _requireConnected();
    final reply = await _link.request(
      WSMeasureCommand.sportStateQuery(),
      replyKey: WSMeasureCommand.keySportStateReply,
      timeout: _replyTimeout,
    );
    return WSMeasureSpotCodec.decodeSportState(reply.value);
  }

  Future<void> subscribeSportRealtime() {
    _requireConnected();
    return _link.send(WSMeasureCommand.sportSubscribe());
  }

  Future<void> unsubscribeSportRealtime() {
    _requireConnected();
    return _link.send(WSMeasureCommand.sportUnsubscribe());
  }

  Future<WSAutoMeasureSchedule> _readAutoSchedule(int key) async {
    _requireConnected();
    WSWatchDebugLog.apiIn('WSMeasure.readAuto key=0x${key.toRadixString(16)}');
    final reply = await _link.request(
      WSSettingsCommand.readKey(key),
      replyKey: key,
      timeout: _replyTimeout,
    );
    if (!WSSettingsCommand.isReadReplyForKey(reply, key)) {
      throw FormatException(
          'unexpected auto monitor reply key=0x${key.toRadixString(16)}');
    }
    return WSHealthMonitorCodec.decodeAutoMonitorBody(
      WSHealthMonitorCodec.extractSettingBody(reply),
    );
  }

  Future<void> _writeAutoSchedule(
      int key, WSAutoMeasureSchedule schedule) async {
    _requireConnected();
    WSWatchDebugLog.apiIn(
      'WSMeasure.setAuto key=0x${key.toRadixString(16)} '
      'enabled=${schedule.enabled} interval=${schedule.intervalMinutes}',
    );
    await _link.send(
      WSSettingsCommand.setKey(
        key,
        WSHealthMonitorCodec.encodeAutoMonitorBody(schedule),
      ),
    );
  }

  Future<void> _startSpot(WSSpotMeasureLane lane) async {
    _requireSpotReady();
    WSWatchDebugLog.apiIn(
        'WSMeasure.startSpot lane=0x${lane.start.toRadixString(16)}');
    final reply = await _link.request(
      lane.startMessage(),
      replyKey: lane.startReply,
      timeout: _replyTimeout,
    );
    if (!lane.isStartSuccess(reply)) {
      throw StateError(
          'spot measure busy or rejected (key 0x${lane.startReply.toRadixString(16)})');
    }
  }

  Future<void> _stopSpot(WSSpotMeasureLane lane) async {
    _requireConnected();
    WSWatchDebugLog.apiIn(
        'WSMeasure.stopSpot lane=0x${lane.stop.toRadixString(16)}');
    await _link.send(lane.stopMessage());
  }

  Future<void> _querySpotStatus() async {
    await querySpotStatus();
  }

  void _onIncoming(WSL2Message message) {
    if (message.command != WSMeasureCommand.command ||
        message.version != WSMeasureCommand.version) return;
    final lane = WSSpotMeasureLanes.laneForKey(message.key);
    if (lane != null && message.key == lane.realtime) {
      _events.add(WSSpotRealtimeEvent(
        lane: lane,
        value: WSMeasureSpotCodec.decodeRealtime(lane, message.value),
      ));
      return;
    }
    if (lane != null && message.key == lane.result) {
      _events.add(WSSpotResultEvent(
        lane: lane,
        result: message.value.isEmpty ? 0xff : message.value[0],
        record: WSMeasureSpotCodec.decodeResult(lane, message.value),
      ));
      return;
    }
    if (message.key == WSMeasureCommand.keySportRealtime) {
      _events.add(WSSportRealtimeEvent(
        WSMeasureSpotCodec.decodeSportRealtime(message.value),
      ));
    } else if (message.key == WSMeasureCommand.keySportEnd) {
      _events.add(WSMeasureSpotCodec.decodeSportEnd(message.value));
    }
  }

  Future<void> dispose() async {
    await _incoming.cancel();
    await _events.close();
  }

  void _requireConnected() {
    if (!_isConnected()) {
      throw StateError('WSMeasure requires an open connected session');
    }
  }

  void _requireSpotReady() {
    _requireConnected();
    if (_isHealthSyncActive()) {
      throw StateError('WS spot measure is not allowed during health sync');
    }
  }
}
