import '../capability/jw_feature.dart';
import 'jw_device_function_info.dart';
import 'jw_device_info.dart';

enum JWSessionPhase {
  idle,
  connecting,
  connected,
  initializing,
  readOnly,
  loggingIn,
  ready,
  loginRejected,
  failed,
  disconnected,
  disposed,
}

final class JWSessionState {
  const JWSessionState({
    this.phase = JWSessionPhase.idle,
    this.device,
    this.functionInfo,
    this.features = const {},
    this.error,
  });

  final JWSessionPhase phase;
  final JWDeviceInfo? device;
  final JWDeviceFunctionInfo? functionInfo;
  final Map<JWFeature, JWFeatureSupport> features;
  final Object? error;

  bool get isReady => phase == JWSessionPhase.ready;

  /// The byte channel is live, independently of login/bind state.
  bool get isConnected => switch (phase) {
        JWSessionPhase.connected ||
        JWSessionPhase.initializing ||
        JWSessionPhase.readOnly ||
        JWSessionPhase.loggingIn ||
        JWSessionPhase.ready ||
        JWSessionPhase.loginRejected =>
          true,
        _ => false,
      };

  JWSessionState copyWith({
    JWSessionPhase? phase,
    JWDeviceInfo? device,
    JWDeviceFunctionInfo? functionInfo,
    Map<JWFeature, JWFeatureSupport>? features,
    Object? error,
    bool clearError = false,
  }) =>
      JWSessionState(
        phase: phase ?? this.phase,
        device: device ?? this.device,
        functionInfo: functionInfo ?? this.functionInfo,
        features: features ?? this.features,
        error: clearError ? null : error ?? this.error,
      );
}
