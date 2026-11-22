import '../connection/ws_link.dart';
import '../wire/ws_today_codec.dart';
import '../wire/ws_data_command.dart';
import '../wire/ws_data_extra_codec.dart';
import '../data/ws_data_models.dart';
import 'ws_today_models.dart';

final class WSToday {
  WSToday({
    required WSLink link,
    required bool Function() isConnected,
    Duration replyTimeout = const Duration(seconds: 8),
  })  : _link = link,
        _isConnected = isConnected,
        _replyTimeout = replyTimeout;

  final WSLink _link;
  final bool Function() _isConnected;
  final Duration _replyTimeout;

  Future<WSTodaySnapshot> queryToday() async {
    _requireConnected();
    final reply = await _link.request(
      WSTodayCodec.query(),
      replyKey: WSTodayCodec.keyTodayPayload,
      timeout: _replyTimeout,
    );
    return WSTodayCodec.decodePayload(reply.value);
  }

  Future<WSTodayNotificationConfigResult> readNotificationConfig() =>
      _notificationConfig(null);

  Future<WSTodayNotificationConfigResult> setNotificationConfig(
    WSTodayNotificationConfig config,
  ) =>
      _notificationConfig(config);

  Future<WSTodayNotificationConfigResult> _notificationConfig(
    WSTodayNotificationConfig? config,
  ) async {
    _requireConnected();
    final reply = await _link.request(
      WSDataExtraCodec.todayConfig(config),
      replyKey: WSDataCommand.keyTodayConfigReply,
      timeout: _replyTimeout,
    );
    return WSDataExtraCodec.decodeTodayConfigReply(reply.value);
  }

  void _requireConnected() {
    if (!_isConnected()) {
      throw StateError('WSToday requires an open connected session');
    }
  }
}
