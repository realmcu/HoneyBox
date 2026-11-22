import 'dart:async';

import '../connection/ws_link.dart';
import '../wire/ws_notification_command.dart';
import '../wire/ws_l2_message.dart';
import 'ws_notification_models.dart';

final class WSNotifications {
  WSNotifications({
    required WSLink link,
    required bool Function() isConnected,
    Duration replyTimeout = const Duration(seconds: 5),
  })  : _link = link,
        _isConnected = isConnected,
        _replyTimeout = replyTimeout {
    _incoming = _link.incoming.listen((message) {
      final event = WSNotificationCommand.decodeEvent(message);
      if (event != null && !_events.isClosed) _events.add(event);
    });
  }

  final WSLink _link;
  final bool Function() _isConnected;
  final Duration _replyTimeout;
  final _events = StreamController<WSNotificationEvent>.broadcast(sync: true);
  late final StreamSubscription<Object?> _incoming;

  Stream<WSNotificationEvent> get events => _events.stream;

  Future<void> pushIncomingCall(WSIncomingCall call) =>
      _send(WSNotificationCommand.incomingCall(call));
  Future<void> updateCallState(int state) =>
      _send(WSNotificationCommand.callState(state));
  Future<void> pushMessage(WSAppNotification item) =>
      _send(WSNotificationCommand.appNotification(item));
  Future<void> deleteMessage(int id) =>
      _send(WSNotificationCommand.deleteMessage(id));
  Future<void> clearMessages() => _send(WSNotificationCommand.clearMessages());
  Future<void> updateMusicState(WSMusicState state) =>
      _send(WSNotificationCommand.musicState(state));
  Future<void> findWatch(bool start) =>
      _send(WSNotificationCommand.findWatch(start));
  Future<void> finishFindPhone(int reason) =>
      _send(WSNotificationCommand.findPhoneEnded(reason));
  Future<void> setCameraOpen(bool open) =>
      _send(WSNotificationCommand.cameraState(open));

  Future<WSBatteryStatus> queryBattery() async {
    _requireConnected();
    final reply = await _link.request(
      WSNotificationCommand.batteryQuery(),
      replyKey: WSNotificationCommand.keyBattery,
      timeout: _replyTimeout,
    );
    return WSNotificationCommand.decodeBattery(reply.value);
  }

  Future<void> _send(WSL2Message message) {
    _requireConnected();
    return _link.send(message);
  }

  void _requireConnected() {
    if (!_isConnected())
      throw StateError('WSNotifications requires a connected session');
  }

  Future<void> dispose() async {
    await _incoming.cancel();
    await _events.close();
  }
}
