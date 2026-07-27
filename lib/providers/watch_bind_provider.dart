import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/watch_bind_protocol.dart';
import 'ble_provider.dart';

enum WatchBindPhase { idle, binding, success, failure, unavailable }

class WatchBindState {
  final WatchBindPhase phase;
  final String? message;

  const WatchBindState(this.phase, {this.message});
}

typedef WatchCommandAvailable = bool Function();
typedef WatchSendCommand = int? Function(Uint8List frame);

class WatchBindNotifier extends StateNotifier<WatchBindState> {
  WatchBindNotifier({
    required WatchCommandAvailable commandAvailable,
    required WatchSendCommand sendCommand,
    required Stream<Uint8List> notifications,
    required Uint8List userId,
    this.timeout = const Duration(seconds: 8),
  })  : _commandAvailable = commandAvailable,
        _sendCommand = sendCommand,
        _userId = Uint8List.fromList(userId),
        super(WatchBindState(
          commandAvailable() ? WatchBindPhase.idle : WatchBindPhase.unavailable,
        )) {
    _notificationSubscription = notifications.listen(_onNotification);
  }

  final WatchCommandAvailable _commandAvailable;
  final WatchSendCommand _sendCommand;
  final Uint8List _userId;
  final Duration timeout;

  StreamSubscription<Uint8List>? _notificationSubscription;
  Timer? _responseTimer;

  void bind() {
    if (state.phase == WatchBindPhase.binding ||
        state.phase == WatchBindPhase.success) {
      return;
    }
    if (!_commandAvailable()) {
      state = const WatchBindState(WatchBindPhase.unavailable);
      return;
    }

    final request = WatchBindProtocol.buildRequest(_userId);
    debugPrint(
      'Watch bind: userId=${WatchBindProtocol.toHex(_userId)}',
    );

    int? sequence;
    try {
      sequence = _sendCommand(request);
    } catch (error) {
      debugPrint('Watch bind: send failed: $error');
    }
    if (sequence == null) {
      state = const WatchBindState(
        WatchBindPhase.unavailable,
        message: '绑定命令发送失败',
      );
      return;
    }

    state = const WatchBindState(WatchBindPhase.binding);
    _responseTimer?.cancel();
    _responseTimer = Timer(timeout, () {
      if (state.phase == WatchBindPhase.binding) {
        state = const WatchBindState(
          WatchBindPhase.failure,
          message: '等待设备响应超时',
        );
      }
    });
  }

  void _onNotification(Uint8List frame) {
    if (state.phase != WatchBindPhase.binding) return;
    final result = WatchBindProtocol.parseResponse(frame);
    if (result == null) return;

    _responseTimer?.cancel();
    _responseTimer = null;
    state = result == WatchBindResult.success
        ? const WatchBindState(
            WatchBindPhase.success,
            message: '设备绑定成功',
          )
        : const WatchBindState(
            WatchBindPhase.failure,
            message: '设备绑定失败',
          );
  }

  @override
  void dispose() {
    _responseTimer?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }
}

final watchBindProvider =
    StateNotifierProvider.autoDispose<WatchBindNotifier, WatchBindState>((ref) {
  final bleManager = ref.read(bleManagerProvider);
  return WatchBindNotifier(
    commandAvailable: () => bleManager.commandAvailable,
    sendCommand: bleManager.sendCommand,
    notifications: bleManager.commandNotifications,
    userId: WatchBindProtocol.processUserId,
  );
});
