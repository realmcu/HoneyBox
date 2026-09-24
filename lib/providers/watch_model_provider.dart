import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/watch_model_protocol.dart';
import 'ble_provider.dart';
import 'watch_bind_provider.dart';

class WatchModelState {
  const WatchModelState({
    this.snapshot,
    this.loading = false,
    this.errorMessage,
  });

  final WatchModelSnapshot? snapshot;
  final bool loading;
  final String? errorMessage;
}

class WatchModelNotifier extends StateNotifier<WatchModelState> {
  WatchModelNotifier({
    required bool Function() commandAvailable,
    required bool Function() isBound,
    required int? Function(Uint8List) sendCommand,
    required Stream<Uint8List> notifications,
  })  : _commandAvailable = commandAvailable,
        _isBound = isBound,
        _sendCommand = sendCommand,
        super(const WatchModelState()) {
    _subscription = notifications.listen(_onNotification);
  }

  final bool Function() _commandAvailable;
  final bool Function() _isBound;
  final int? Function(Uint8List) _sendCommand;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _timeout;

  void refresh() {
    _timeout?.cancel();
    if (!_isBound()) {
      state = WatchModelState(
        snapshot: state.snapshot,
        errorMessage: '请先完成设备绑定',
      );
      return;
    }
    if (!_commandAvailable()) {
      state = const WatchModelState(errorMessage: '设备状态通道不可用');
      return;
    }

    state = WatchModelState(snapshot: state.snapshot, loading: true);
    final sequence = _sendCommand(WatchModelProtocol.buildGetRequest());
    if (sequence == null) {
      state = WatchModelState(
        snapshot: state.snapshot,
        errorMessage: '设备状态查询发送失败',
      );
      return;
    }

    _timeout = Timer(const Duration(seconds: 8), () {
      if (!state.loading) return;
      state = WatchModelState(
        snapshot: state.snapshot,
        errorMessage: '设备状态查询超时',
      );
    });
  }

  void _onNotification(Uint8List frame) {
    final snapshot = WatchModelProtocol.parseSnapshot(frame);
    if (snapshot == null) return;
    _timeout?.cancel();
    state = WatchModelState(snapshot: snapshot);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

final watchModelProvider =
    StateNotifierProvider.autoDispose<WatchModelNotifier, WatchModelState>((ref) {
  final ble = ref.read(bleManagerProvider);
  return WatchModelNotifier(
    commandAvailable: () => ble.commandAvailable,
    isBound: () =>
        ref.read(watchBindProvider).phase == WatchBindPhase.success,
    sendCommand: ble.sendCommand,
    notifications: ble.commandNotifications,
  );
});
