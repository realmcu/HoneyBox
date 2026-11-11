import '../connection/ws_link.dart';
import '../honey/honey_control.dart';

final class WSControl {
  WSControl({
    required WSLink link,
    required bool Function() isReady,
    Duration replyTimeout = const Duration(seconds: 8),
  })  : _link = link,
        _isReady = isReady,
        _replyTimeout = replyTimeout;

  final WSLink _link;
  final bool Function() _isReady;
  final Duration _replyTimeout;

  Future<int> queryBatteryPercent() async {
    _requireReady();
    final reply = await _link.request(
      HoneyControlCommand.batteryQuery(),
      replyKey: HoneyControlCommand.keyBatteryReply,
      timeout: _replyTimeout,
    );
    return HoneyControlCommand.decodeBatteryPercent(reply);
  }

  void _requireReady() {
    if (!_isReady()) {
      throw StateError('WSControl requires an authenticated ready session');
    }
  }
}
