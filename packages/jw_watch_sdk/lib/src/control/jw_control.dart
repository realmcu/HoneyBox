import '../connection/jw_link.dart';
import '../model/jw_device_function_info.dart';
import '../settings/jw_settings_models.dart';
import 'jw_control_coordinator.dart';
import 'jw_control_listener.dart';
import 'jw_control_protocol.dart';
import 'jw_music_status_info.dart';
import 'jw_weather_info.dart';

/// HL `cmd 0x07` control: take-photo, find-phone, music, and weather.
final class JWControl {
  JWControl({
    required JWLink link,
    required JWControlCoordinator coordinator,
    required bool Function() isReady,
    required JWDeviceFunctionInfo? Function() functionInfo,
  })  : _link = link,
        _coordinator = coordinator,
        _isReady = isReady,
        _functionInfo = functionInfo;

  final JWLink _link;
  final JWControlCoordinator _coordinator;
  final bool Function() _isReady;
  final JWDeviceFunctionInfo? Function() _functionInfo;

  void addControlListener(JWControlListener listener) =>
      _coordinator.addListener(listener);

  void removeControlListener(JWControlListener listener) =>
      _coordinator.removeListener(listener);

  /// Register a [JWControlListener] before enabling so gestures invoke [JWControlListener.onTakePhoto].
  Future<JWSettingSubmission> setTakePhotoControl(bool enable) async {
    _requireReady();
    _requireCapability(JWDeviceFunction.cameraControl, 'take photo control');
    await _link.send(JWControlProtocol.setTakePhotoControl(enable));
    return JWSettingSubmission(
        enable ? 'take photo control enabled' : 'take photo control disabled');
  }

  Future<JWSettingSubmission> setMusicStatus(JWMusicStatusInfo musicStatusInfo) async {
    _requireReady();
    _requireCapability(JWDeviceFunction.musicControl, 'music status');
    if (musicStatusInfo.volumePercent < 0 || musicStatusInfo.volumePercent > 63) {
      throw ArgumentError('volumePercent must be 0 - 63');
    }
    await _link.send(JWControlProtocol.setMusicStatus(musicStatusInfo));
    return const JWSettingSubmission('music status');
  }

  Future<JWSettingSubmission> setWeather(JWWeatherInfo weatherInfo) async {
    _requireReady();
    await _link.send(JWControlProtocol.setWeather(weatherInfo));
    return const JWSettingSubmission('weather');
  }

  void _requireReady() {
    if (!_isReady()) {
      throw StateError('JW control requires an authenticated session');
    }
  }

  void _requireCapability(JWDeviceFunction function, String name) {
    final info = _functionInfo();
    if (info == null || !info.supports(function)) {
      throw StateError('JW device does not support $name');
    }
  }
}
