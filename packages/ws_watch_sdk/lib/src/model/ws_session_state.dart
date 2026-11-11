import 'ws_device_info.dart';

enum WSSessionPhase {
  idle,
  connecting,
  connected,
  loggingIn,
  ready,
  loginRejected,
  failed,
  disconnected,
  disposed,
}

final class WSSessionState {
  const WSSessionState({
    this.phase = WSSessionPhase.idle,
    this.device,
    this.error,
  });

  final WSSessionPhase phase;
  final WSDeviceInfo? device;
  final Object? error;

  bool get isReady => phase == WSSessionPhase.ready;

  bool get isConnected => switch (phase) {
        WSSessionPhase.connected ||
        WSSessionPhase.loggingIn ||
        WSSessionPhase.ready ||
        WSSessionPhase.loginRejected =>
          true,
        _ => false,
      };

  WSSessionState copyWith({
    WSSessionPhase? phase,
    WSDeviceInfo? device,
    Object? error,
    bool clearError = false,
  }) =>
      WSSessionState(
        phase: phase ?? this.phase,
        device: device ?? this.device,
        error: clearError ? null : error ?? this.error,
      );
}
