import '../connection/ws_link.dart';
import '../honey/honey_today.dart';
import 'ws_today_models.dart';

final class WSToday {
  WSToday({
    required WSLink link,
    required bool Function() isReady,
    Duration replyTimeout = const Duration(seconds: 8),
  })  : _link = link,
        _isReady = isReady,
        _replyTimeout = replyTimeout;

  final WSLink _link;
  final bool Function() _isReady;
  final Duration _replyTimeout;

  Future<WSTodaySnapshot> queryToday() async {
    _requireReady();
    final reply = await _link.request(
      HoneyTodayCommand.query(),
      replyKey: HoneyTodayCommand.keyTodayPayload,
      timeout: _replyTimeout,
    );
    return HoneyTodayCommand.decodePayload(reply.value);
  }

  void _requireReady() {
    if (!_isReady()) {
      throw StateError('WSToday requires an authenticated ready session');
    }
  }
}
