import '../connection/ws_link.dart';
import '../debug/ws_debug_log.dart';
import '../measure/ws_measure_models.dart';
import '../wire/ws_health_monitor_codec.dart';
import '../wire/ws_settings_command.dart';

final class WSSettings {
  WSSettings(this._link, {Duration replyTimeout = const Duration(seconds: 8)})
      : _replyTimeout = replyTimeout;

  final WSLink _link;
  final Duration _replyTimeout;

  Future<void> setPhoneSystem(int system) =>
      _link.send(WSSettingsCommand.setPhoneSystem(system));

  Future<void> setTimeUnix(int wallSeconds) =>
      _link.send(WSSettingsCommand.setTimeUnix(wallSeconds));

  Future<int> readLanguage() async {
    final reply = await _link.requestWhere(
      WSSettingsCommand.readLanguage(),
      matches: WSSettingsCommand.isLanguageReadReply,
      timeout: _replyTimeout,
    );
    return WSSettingsCommand.decodeLanguageCode(reply);
  }

  Future<WSHeartRateHighAlarm> readHeartRateHighAlarm() async {
    WSWatchDebugLog.apiIn('WSSettings.readHeartRateHighAlarm');
    final reply = await _link.request(
      WSSettingsCommand.readKey(WSHealthMonitorCodec.keyHeartRateAlarm),
      replyKey: WSHealthMonitorCodec.keyHeartRateAlarm,
      timeout: _replyTimeout,
    );
    return WSHealthMonitorCodec.decodeHeartRateHighAlarm(
      WSHealthMonitorCodec.extractSettingBody(reply),
    );
  }

  Future<void> setHeartRateHighAlarm(WSHeartRateHighAlarm alarm) async {
    WSWatchDebugLog.apiIn('WSSettings.setHeartRateHighAlarm');
    await _link.send(
      WSSettingsCommand.setKey(
        WSHealthMonitorCodec.keyHeartRateAlarm,
        WSHealthMonitorCodec.encodeHeartRateHighAlarm(alarm),
      ),
    );
  }

  Future<WSSpO2LowAlarm> readSpO2LowAlarm() async {
    WSWatchDebugLog.apiIn('WSSettings.readSpO2LowAlarm');
    final reply = await _link.request(
      WSSettingsCommand.readKey(WSHealthMonitorCodec.keySpO2Alarm),
      replyKey: WSHealthMonitorCodec.keySpO2Alarm,
      timeout: _replyTimeout,
    );
    return WSHealthMonitorCodec.decodeSpO2LowAlarm(
      WSHealthMonitorCodec.extractSettingBody(reply),
    );
  }

  Future<void> setSpO2LowAlarm(WSSpO2LowAlarm alarm) async {
    WSWatchDebugLog.apiIn('WSSettings.setSpO2LowAlarm');
    await _link.send(
      WSSettingsCommand.setKey(
        WSHealthMonitorCodec.keySpO2Alarm,
        WSHealthMonitorCodec.encodeSpO2LowAlarm(alarm),
      ),
    );
  }
}
