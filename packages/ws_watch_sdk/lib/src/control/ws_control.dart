import '../connection/ws_link.dart';
import '../wire/ws_control_command.dart';

final class WSControl {
  WSControl({
    required WSLink link,
    required bool Function() isConnected,
    Duration replyTimeout = const Duration(seconds: 8),
  })  : _link = link,
        _isConnected = isConnected,
        _replyTimeout = replyTimeout;

  final WSLink _link;
  final bool Function() _isConnected;
  final Duration _replyTimeout;

  Future<int> queryBatteryPercent() async {
    _requireConnected();
    final reply = await _link.request(
      WSControlCommand.batteryQuery(),
      replyKey: WSControlCommand.keyBatteryReply,
      timeout: _replyTimeout,
    );
    return WSControlCommand.decodeBatteryPercent(reply);
  }

  void _requireConnected() {
    if (!_isConnected()) {
      throw StateError('WSControl requires an open connected session');
    }
  }
}
