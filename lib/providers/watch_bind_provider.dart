import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/watch_bind_protocol.dart';
import '../services/watch_identity_store.dart';
import '../services/watch_time_protocol.dart';
import 'ble_provider.dart';

enum WatchBindPhase { idle, binding, success, failure, unavailable }

enum WatchTimeSyncPhase { notStarted, syncing, synced, failed }

class WatchBindState {
  final WatchBindPhase phase;
  final WatchTimeSyncPhase timeSyncPhase;
  final String? message;

  const WatchBindState(
    this.phase, {
    this.timeSyncPhase = WatchTimeSyncPhase.notStarted,
    this.message,
  });
}

typedef WatchCommandAvailable = bool Function();
typedef WatchSendCommand = int? Function(Uint8List frame);
typedef WatchUserIdLoader = Future<Uint8List> Function();
typedef WatchClock = DateTime Function();

class WatchBindNotifier extends StateNotifier<WatchBindState> {
  WatchBindNotifier({
    required WatchCommandAvailable commandAvailable,
    required WatchSendCommand sendCommand,
    required Stream<Uint8List> notifications,
    Uint8List? userId,
    WatchUserIdLoader? userIdLoader,
    this.timeout = const Duration(seconds: 15),
    WatchClock clock = DateTime.now,
  })  : assert((userId == null) != (userIdLoader == null)),
        _commandAvailable = commandAvailable,
        _sendCommand = sendCommand,
        _userId = userId == null ? null : Uint8List.fromList(userId),
        _userIdLoader = userIdLoader,
        _clock = clock,
        super(WatchBindState(
          commandAvailable() ? WatchBindPhase.idle : WatchBindPhase.unavailable,
        )) {
    _notificationSubscription = notifications.listen(_onNotification);
  }

  final WatchCommandAvailable _commandAvailable;
  final WatchSendCommand _sendCommand;
  final WatchUserIdLoader? _userIdLoader;
  final WatchClock _clock;
  final Duration timeout;

  Uint8List? _userId;
  StreamSubscription<Uint8List>? _notificationSubscription;
  Timer? _responseTimer;

  Future<void> bind() async {
    if (state.phase == WatchBindPhase.binding ||
        state.phase == WatchBindPhase.success) {
      return;
    }
    if (!_commandAvailable()) {
      state = const WatchBindState(WatchBindPhase.unavailable);
      return;
    }

    state = const WatchBindState(WatchBindPhase.binding);
    final cached = _userId;
    if (cached != null) {
      _sendLogin(cached);
      return;
    }
    final identity = await _resolveUserId();
    if (identity == null) {
      state = const WatchBindState(
        WatchBindPhase.unavailable,
        message: '无法读取用户标识',
      );
      return;
    }

    _userId = identity;
    _sendLogin(identity);
  }

  void _sendLogin(Uint8List identity) {
    debugPrint('Watch login: userId=${WatchBindProtocol.toHex(identity)}');
    if (!_send(WatchBindProtocol.buildLoginRequest(identity))) {
      state = const WatchBindState(
        WatchBindPhase.unavailable,
        message: '登录命令发送失败',
      );
      return;
    }
    _armTimeout('等待手环登录响应超时');
  }

  Future<Uint8List?> _resolveUserId() async {
    final cached = _userId;
    if (cached != null) return cached;
    try {
      return await _userIdLoader!();
    } catch (error) {
      debugPrint('Watch identity: load failed: $error');
      return null;
    }
  }

  bool _send(Uint8List frame) {
    try {
      return _sendCommand(frame) != null;
    } catch (error) {
      debugPrint('Watch command: send failed: $error');
      return false;
    }
  }

  void _armTimeout(String message) {
    _responseTimer?.cancel();
    _responseTimer = Timer(timeout, () {
      if (state.phase == WatchBindPhase.binding) {
        state = WatchBindState(
          WatchBindPhase.failure,
          message: message,
        );
      }
    });
  }

  void _onNotification(Uint8List frame) {
    if (state.phase != WatchBindPhase.binding) return;

    final login = WatchBindProtocol.parseLoginResponse(frame);
    if (login != null) {
      _responseTimer?.cancel();
      if (login == WatchBindResult.success) {
        _finishBound();
      } else {
        _sendBindRequest();
      }
      return;
    }

    final bind = WatchBindProtocol.parseResponse(frame);
    if (bind == null) return;
    _responseTimer?.cancel();
    if (bind == WatchBindResult.success) {
      _finishBound();
    } else {
      state = const WatchBindState(
        WatchBindPhase.failure,
        message: '设备绑定失败',
      );
    }
  }

  void _sendBindRequest() {
    final identity = _userId;
    if (identity == null) {
      state = const WatchBindState(
        WatchBindPhase.failure,
        message: '缺少用户标识',
      );
      return;
    }
    debugPrint('Watch bind: userId=${WatchBindProtocol.toHex(identity)}');
    if (!_send(WatchBindProtocol.buildRequest(identity))) {
      state = const WatchBindState(
        WatchBindPhase.unavailable,
        message: '绑定命令发送失败',
      );
      return;
    }
    _armTimeout('等待设备响应超时');
  }

  void _finishBound() {
    _responseTimer?.cancel();
    _responseTimer = null;
    state = const WatchBindState(
      WatchBindPhase.success,
      timeSyncPhase: WatchTimeSyncPhase.syncing,
    );
    _syncTime();
  }

  void retryTimeSync() {
    if (state.phase != WatchBindPhase.success ||
        state.timeSyncPhase != WatchTimeSyncPhase.failed) {
      return;
    }
    _syncTime();
  }

  void _syncTime() {
    if (!_commandAvailable()) {
      _setTimeSyncFailed();
      return;
    }

    state = const WatchBindState(
      WatchBindPhase.success,
      timeSyncPhase: WatchTimeSyncPhase.syncing,
    );

    final sent = _send(WatchTimeProtocol.buildSetTime(_clock()));
    if (!sent) {
      _setTimeSyncFailed();
      return;
    }

    state = const WatchBindState(
      WatchBindPhase.success,
      timeSyncPhase: WatchTimeSyncPhase.synced,
      message: '设备绑定成功，时间已同步',
    );
  }

  void _setTimeSyncFailed() {
    state = const WatchBindState(
      WatchBindPhase.success,
      timeSyncPhase: WatchTimeSyncPhase.failed,
      message: '设备绑定成功，时间同步失败',
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
    userIdLoader: WatchIdentityStore().loadOrCreate,
  );
});
