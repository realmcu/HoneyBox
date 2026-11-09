import '../debug/jw_debug_log.dart';
import '../connection/jw_link.dart';
import '../connection/jw_protocol.dart';
import '../model/jw_device_function_info.dart';
import '../model/jw_error.dart';
import 'jw_measure_coordinator.dart';
import 'jw_measure_codec.dart';
import 'jw_measure_data_listener.dart';
import 'jw_measure_models.dart';
import 'jw_measure_protocol.dart';

/// HL measure commands (`cmd 0x05` / `0x08` spot and auto measure).
final class JWMeasure {
  JWMeasure({
    required JWLink link,
    required JWMeasureCoordinator coordinator,
    required bool Function() isReady,
    required bool Function() isHealthSyncActive,
    required JWDeviceFunctionInfo? Function() functionInfo,
  })  : _link = link,
        _coordinator = coordinator,
        _isReady = isReady,
        _isHealthSyncActive = isHealthSyncActive,
        _functionInfo = functionInfo;

  final JWLink _link;
  final JWMeasureCoordinator _coordinator;
  final bool Function() _isReady;
  final bool Function() _isHealthSyncActive;
  final JWDeviceFunctionInfo? Function() _functionInfo;

  void addMeasureDataListener(JWMeasureDataListener listener) =>
      _coordinator.addListener(listener);

  void removeMeasureDataListener(JWMeasureDataListener listener) =>
      _coordinator.removeListener(listener);

  Future<JWAutoMeasureConfig> readHeartRateAutoMeasure() async {
    _requireReady();
    _requireFunction(JWDeviceFunction.rate);
    final reply = await _link.request(JWMeasureProtocol.readHeartRateAutoMeasure());
    _expectSportKey(reply, 0x12, 'heart rate auto measure');
    return decodeAutoMeasureConfig(reply.value);
  }

  Future<void> setHeartRateAutoMeasure(JWAutoMeasureConfig config) async {
    _requireReady();
    _requireFunction(JWDeviceFunction.rate);
    await _link.send(JWMeasureProtocol.setHeartRateAutoMeasure(
        JWMeasureProtocol.encodeAutoMeasure(config)));
  }

  Future<JWAutoMeasureConfig> readSpO2AutoMeasure() async {
    _requireReady();
    _requireFunction(JWDeviceFunction.spo2Continuous);
    final reply = await _link.request(JWMeasureProtocol.readSpO2AutoMeasure());
    _expectSportKey(reply, 0x35, 'SpO2 auto measure');
    return decodeAutoMeasureConfig(reply.value);
  }

  Future<void> setSpO2AutoMeasure(JWAutoMeasureConfig config) async {
    _requireReady();
    _requireFunction(JWDeviceFunction.spo2Continuous);
    await _link.send(JWMeasureProtocol.setSpO2AutoMeasure(
        JWMeasureProtocol.encodeAutoMeasure(config)));
  }

  Future<JWAutoMeasureConfig> readBloodPressureAutoMeasure() async {
    _requireReady();
    _requireFunction(JWDeviceFunction.rtkBp3);
    final reply =
        await _link.request(JWMeasureProtocol.readBloodPressureAutoMeasure());
    _expectSportKey(reply, 0x3f, 'blood pressure auto measure');
    return decodeAutoMeasureConfig(reply.value);
  }

  Future<void> setBloodPressureAutoMeasure(JWAutoMeasureConfig config) async {
    _requireReady();
    _requireFunction(JWDeviceFunction.rtkBp3);
    await _link.send(JWMeasureProtocol.setBloodPressureAutoMeasure(
        JWMeasureProtocol.encodeAutoMeasure(config)));
  }

  Future<JWBloodSugarAutoMeasureConfig> readBloodSugarAutoMeasure() async {
    _requireReady();
    _requireFunction(JWDeviceFunction.bloodSugar);
    final reply =
        await _link.request(JWMeasureProtocol.readBloodSugarAutoMeasure());
    _expectSportKey(reply, 0x45, 'blood sugar auto measure');
    return decodeBloodSugarAutoMeasure(reply.value);
  }

  Future<void> setBloodSugarAutoMeasure(
      JWBloodSugarAutoMeasureConfig config) async {
    _requireReady();
    _requireFunction(JWDeviceFunction.bloodSugar);
    await _link.send(JWMeasureProtocol.setBloodSugarAutoMeasure(
      JWMeasureProtocol.encodeAutoMeasure(
        JWAutoMeasureConfig(
          enabled: config.enabled,
          intervalMinutes: config.intervalMinutes,
        ),
      ),
    ));
  }

  Future<JWTemperatureControlSetting> readTemperatureControl() async {
    _requireReady();
    _requireFunction(JWDeviceFunction.temperature);
    final reply =
        await _link.request(JWMeasureProtocol.readTemperatureControl());
    _expectSportKey(reply, 0x24, 'temperature control');
    return decodeTemperatureControl(reply.value);
  }

  Future<void> setTemperatureControl(JWTemperatureControlSetting setting) async {
    _requireReady();
    _requireFunction(JWDeviceFunction.temperature);
    await _link.send(JWMeasureProtocol.setTemperatureControl(
        JWMeasureProtocol.encodeTemperatureControl(setting)));
  }

  Future<void> setPressureAutoMeasure(bool enabled) async {
    _requireReady();
    _requireFunction(JWDeviceFunction.pressure);
    await _link.send(JWMeasureProtocol.setPressureAutoMeasure(
        JWMeasureProtocol.encodeContinuousMonitoringSubCommand(0x07, enabled)));
  }

  Future<void> startHeartRateMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.startHeartRateMeasure');
    _requireSpotMeasure();
    _requireFunction(JWDeviceFunction.rate);
    await _link.send(JWMeasureProtocol.setHeartRateSpotMeasure(true));
  }

  Future<void> stopHeartRateMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.stopHeartRateMeasure');
    _requireReady();
    _requireFunction(JWDeviceFunction.rate);
    await _link.send(JWMeasureProtocol.setHeartRateSpotMeasure(false));
  }

  Future<void> startBloodPressureSpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.startBloodPressureSpotMeasure');
    _requireSpotMeasure();
    _requireFunction(JWDeviceFunction.bpDetection);
    await _link.send(JWMeasureProtocol.setBloodPressureSpotMeasure(true));
  }

  Future<void> stopBloodPressureSpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.stopBloodPressureSpotMeasure');
    _requireReady();
    _requireFunction(JWDeviceFunction.bpDetection);
    await _link.send(JWMeasureProtocol.setBloodPressureSpotMeasure(false));
  }

  Future<void> startSpO2SpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.startSpO2SpotMeasure');
    _requireSpotMeasure();
    _requireFunction(JWDeviceFunction.spo2Measure);
    await _link.send(JWMeasureProtocol.setSpO2SpotMeasure(true));
  }

  Future<void> stopSpO2SpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.stopSpO2SpotMeasure');
    _requireReady();
    _requireFunction(JWDeviceFunction.spo2Measure);
    await _link.send(JWMeasureProtocol.setSpO2SpotMeasure(false));
  }

  Future<void> checkSpO2SpotMeasure() async {
    _requireSpotMeasure();
    _requireFunction(JWDeviceFunction.spo2Measure);
    await _link.send(JWMeasureProtocol.checkSpO2SpotMeasure());
  }

  Future<void> startTemperatureSpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.startTemperatureSpotMeasure');
    _requireSpotMeasure();
    _requireFunction(JWDeviceFunction.temperature);
    await _link.send(JWMeasureProtocol.setTemperatureSpotMeasure(true));
  }

  Future<void> stopTemperatureSpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.stopTemperatureSpotMeasure');
    _requireReady();
    _requireFunction(JWDeviceFunction.temperature);
    await _link.send(JWMeasureProtocol.setTemperatureSpotMeasure(false));
  }

  Future<void> checkTemperatureSpotMeasure() async {
    _requireSpotMeasure();
    _requireFunction(JWDeviceFunction.temperature);
    await _link.send(JWMeasureProtocol.checkTemperatureSpotMeasure());
  }

  Future<void> startBloodGlucoseSpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.startBloodGlucoseSpotMeasure');
    _requireSpotMeasure();
    _requireFunction(JWDeviceFunction.bloodSugar);
    await _link.send(JWMeasureProtocol.setBloodSugarSpotMeasure(true));
    _coordinator.bloodSugarSpotActive = true;
  }

  Future<void> stopBloodGlucoseSpotMeasure() async {
    JWWatchDebugLog.apiIn('JWMeasure.stopBloodGlucoseSpotMeasure');
    _requireReady();
    _requireFunction(JWDeviceFunction.bloodSugar);
    await _link.send(JWMeasureProtocol.setBloodSugarSpotMeasure(false));
    _coordinator.bloodSugarSpotActive = false;
  }

  void _requireReady() {
    if (!_isReady()) {
      throw StateError('JW measure requires an authenticated session');
    }
  }

  void _requireSpotMeasure() {
    _requireReady();
    if (_isHealthSyncActive()) {
      throw StateError('JW spot measure is not allowed during health sync');
    }
  }

  void _requireFunction(JWDeviceFunction function) {
    final info = _functionInfo();
    if (info == null || !info.supports(function)) {
      throw const JWException(
          JWErrorCode.unavailable, 'JW device does not support this measure');
    }
  }

  void _expectSportKey(JWProtocolMessage reply, int key, String name) {
    if (reply.command != 5 || reply.key != key) {
      throw FormatException('Unexpected JW $name response');
    }
  }
}
