import '../capability/ws_capabilities.dart';
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
    this.capabilities,
    this.error,
  });

  final WSSessionPhase phase;
  final WSDeviceInfo? device;

  /// Parsed `0x02` / key `0x31` capability bitmap after [WSWatchSession.readDeviceFeatures].
  final WSCapabilities? capabilities;
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
    WSCapabilities? capabilities,
    bool clearCapabilities = false,
    Object? error,
    bool clearError = false,
  }) =>
      WSSessionState(
        phase: phase ?? this.phase,
        device: device ?? this.device,
        capabilities:
            clearCapabilities ? null : capabilities ?? this.capabilities,
        error: clearError ? null : error ?? this.error,
      );
}
