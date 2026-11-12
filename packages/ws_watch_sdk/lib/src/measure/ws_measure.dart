import '../connection/ws_link.dart';
import '../debug/ws_debug_log.dart';
import '../wire/ws_health_monitor_codec.dart';
import '../wire/ws_measure_command.dart';
import '../wire/ws_settings_command.dart';
import 'ws_measure_coordinator.dart';
import 'ws_measure_data_listener.dart';
import 'ws_measure_models.dart';

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
        _replyTimeout = replyTimeout;

  final WSLink _link;
  final bool Function() _isConnected;
  final bool Function() _isHealthSyncActive;
  final WSMeasureCoordinator? _coordinator;
  final Duration _replyTimeout;

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

  Future<List<int>> readHeartRateIntervalOptions() async {
    _requireConnected();
    return List<int>.unmodifiable(defaultHeartRateIntervalOptions);
  }

  Future<WSAutoMeasureConfig> readSpO2AutoMeasure() async =>
      WSAutoMeasureConfig.fromSchedule(
        await _readAutoSchedule(WSHealthMonitorCodec.keySpO2Auto),
      );

  Future<void> setSpO2AutoMeasure(WSAutoMeasureConfig config) async =>
      _writeAutoSchedule(
        WSHealthMonitorCodec.keySpO2Auto,
        config.toSchedule(),
      );

  Future<WSAutoMeasureConfig> readBloodPressureAutoMeasure() async =>
      WSAutoMeasureConfig.fromSchedule(
        await _readAutoSchedule(WSHealthMonitorCodec.keyBloodPressureAuto),
      );

  Future<void> setBloodPressureAutoMeasure(WSAutoMeasureConfig config) async =>
      _writeAutoSchedule(
        WSHealthMonitorCodec.keyBloodPressureAuto,
        config.toSchedule(),
      );

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

  Future<void> setPressureAutoMeasure(bool enabled) async {
    final previous =
        await _readAutoSchedule(WSHealthMonitorCodec.keyPressureAuto);
    await _writeAutoSchedule(
      WSHealthMonitorCodec.keyPressureAuto,
      previous.copyWith(
        enabled: enabled,
        intervalMinutes: previous.intervalMinutes == 0
            ? 30
            : previous.intervalMinutes,
      ),
    );
  }

  Future<WSTemperatureControlSetting> readTemperatureControl() async {
    _requireConnected();
    final auto = await _readAutoSchedule(WSHealthMonitorCodec.keyTemperatureAuto);
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

  Future<void> setTemperatureControl(WSTemperatureControlSetting setting) async {
    _requireConnected();
    final previous =
        await _readAutoSchedule(WSHealthMonitorCodec.keyTemperatureAuto);
    await _writeAutoSchedule(
      WSHealthMonitorCodec.keyTemperatureAuto,
      previous.copyWith(
        enabled: setting.enabled,
        intervalMinutes: previous.intervalMinutes == 0
            ? 30
            : previous.intervalMinutes,
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

  Future<void> startSpO2SpotMeasure() => _startSpot(WSSpotMeasureLanes.bloodOxygen);

  Future<void> stopSpO2SpotMeasure() => _stopSpot(WSSpotMeasureLanes.bloodOxygen);

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

  Future<WSAutoMeasureSchedule> _readAutoSchedule(int key) async {
    _requireConnected();
    WSWatchDebugLog.apiIn('WSMeasure.readAuto key=0x${key.toRadixString(16)}');
    final reply = await _link.request(
      WSSettingsCommand.readKey(key),
      replyKey: key,
      timeout: _replyTimeout,
    );
    if (!WSSettingsCommand.isReadReplyForKey(reply, key)) {
      throw FormatException('unexpected auto monitor reply key=0x${key.toRadixString(16)}');
    }
    return WSHealthMonitorCodec.decodeAutoMonitorBody(
      WSHealthMonitorCodec.extractSettingBody(reply),
    );
  }

  Future<void> _writeAutoSchedule(int key, WSAutoMeasureSchedule schedule) async {
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
    WSWatchDebugLog.apiIn('WSMeasure.startSpot lane=0x${lane.start.toRadixString(16)}');
    final reply = await _link.request(
      lane.startMessage(),
      replyKey: lane.startReply,
      timeout: _replyTimeout,
    );
    if (!lane.isStartSuccess(reply)) {
      throw StateError('spot measure busy or rejected (key 0x${lane.startReply.toRadixString(16)})');
    }
  }

  Future<void> _stopSpot(WSSpotMeasureLane lane) async {
    _requireConnected();
    WSWatchDebugLog.apiIn('WSMeasure.stopSpot lane=0x${lane.stop.toRadixString(16)}');
    await _link.send(lane.stopMessage());
  }

  Future<void> _querySpotStatus() async {
    _requireSpotReady();
    WSWatchDebugLog.apiIn('WSMeasure.querySpotStatus');
    await _link.request(
      WSMeasureCommand.querySpotStatus(),
      replyKey: WSMeasureCommand.keyStatusReply,
      timeout: _replyTimeout,
    );
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
