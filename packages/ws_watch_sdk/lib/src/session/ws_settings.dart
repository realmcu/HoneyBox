import '../connection/ws_link.dart';
import '../honey/honey_settings.dart';

final class WSSettings {
  WSSettings(this._link, {Duration replyTimeout = const Duration(seconds: 8)})
      : _replyTimeout = replyTimeout;

  final WSLink _link;
  final Duration _replyTimeout;

  Future<void> setPhoneSystem(int system) =>
      _link.send(HoneySettingsCommand.setPhoneSystem(system));

  Future<void> setTimeUnix(int wallSeconds) =>
      _link.send(HoneySettingsCommand.setTimeUnix(wallSeconds));

  Future<int> readLanguage() async {
    final reply = await _link.requestWhere(
      HoneySettingsCommand.readLanguage(),
      matches: HoneySettingsCommand.isLanguageReadReply,
      timeout: _replyTimeout,
    );
    return HoneySettingsCommand.decodeLanguageCode(reply);
  }
}
