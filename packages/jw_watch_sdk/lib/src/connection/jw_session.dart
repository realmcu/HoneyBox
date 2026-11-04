import 'dart:async';
import 'dart:convert';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import '../capability/jw_feature.dart';
import '../model/jw_device_info.dart';
import '../model/jw_device_function_info.dart';
import '../model/jw_identity.dart';
import '../model/jw_session_state.dart';
import 'jw_link.dart';
import 'jw_protocol.dart';

/// One owned connection/session. Reconnection creates a new instance.
final class JWWatchSession {
  JWWatchSession(this.connection)
      : _link = JWLink(connection),
        _state = const JWSessionState();

  final WatchTransportConnection connection;
  final JWLink _link;
  final _states = StreamController<JWSessionState>.broadcast(sync: true);
  JWSessionState _state;
  StreamSubscription<JWLinkException>? _linkFailures;
  Future<void>? _opening;
  bool _disposed = false;

  JWSessionState get state => _state;
  Stream<JWSessionState> get states => _states.stream;

  /// Opens the JW byte channel. This does not log in, bind, or query device
  /// characteristics; applications can present those as explicit steps.
  Future<void> connect() => _opening ??= _connect();

  Future<void> _connect() async {
    _publish(
        _state.copyWith(phase: JWSessionPhase.connecting, clearError: true));
    _linkFailures = _link.failures.listen((error) {
      if (!_disposed) {
        _publish(
            _state.copyWith(phase: JWSessionPhase.disconnected, error: error));
      }
    });
    try {
      await _link.open();
      _publish(_state.copyWith(phase: JWSessionPhase.connected));
    } catch (error) {
      if (!_disposed) {
        _publish(_state.copyWith(phase: JWSessionPhase.failed, error: error));
      }
      rethrow;
    }
  }

  /// Reads standard GATT device information. Does not read the JW capability
  /// report.
  Future<void> readDeviceInfo() async {
    _requireConnected();
    final wasReady = _state.isReady;
    _publish(_state.copyWith(clearError: true));
    try {
      final info = await _readDeviceInfo();
      final phase = wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
      _publish(_state.copyWith(phase: phase, device: info));
    } catch (error) {
      if (!_disposed) {
        final phase =
            wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
        _publish(_state.copyWith(phase: phase, error: error));
      }
      rethrow;
    }
  }

  /// Reads optional GATT device information and the JW capability report.
  /// The connection remains usable even when this optional discovery fails.
  Future<void> readDeviceDetails() async {
    _requireConnected();
    final wasReady = _state.isReady;
    _publish(_state.copyWith(clearError: true));
    try {
      final info = await _readDeviceInfo();
      final features = await _readFeatures();
      final phase = wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
      _publish(_state.copyWith(phase: phase, device: info, features: features));
    } catch (error) {
      if (!_disposed) {
        final phase =
            wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
        _publish(_state.copyWith(phase: phase, error: error));
      }
      rethrow;
    }
  }

  /// Reads the complete eight-byte JW device-function report (0x02/0x37).
  ///
  /// This is independent from standard GATT device information. The parsed
  /// result is retained in [state.functionInfo] and is also summarized into
  /// the existing top-level [JWFeature] groups.
  Future<void> readDeviceFeatures() async {
    _requireConnected();
    final wasReady = _state.isReady;
    _publish(_state.copyWith(clearError: true));
    try {
      final reply = await _link.request(JWProtocolCommands.functions());
      final functionInfo = JWDeviceFunctionInfo.fromWire(reply.value);
      final features = await _readFeatures();
      _publish(_state.copyWith(
          phase: wasReady ? JWSessionPhase.ready : JWSessionPhase.connected,
          functionInfo: functionInfo,
          features: features));
    } catch (error) {
      if (!_disposed) {
        _publish(_state.copyWith(
            phase: wasReady ? JWSessionPhase.ready : JWSessionPhase.connected,
            error: error));
      }
      rethrow;
    }
  }

  Future<void> login(JWIdentity identity) async {
    _requireConnected();
    _publish(
        _state.copyWith(phase: JWSessionPhase.loggingIn, clearError: true));
    final reply = await _link.request(JWProtocolCommands.login(identity.bytes));
    if (!_isSuccess(reply)) {
      _publish(_state.copyWith(phase: JWSessionPhase.loginRejected));
      return;
    }
    _publish(_state.copyWith(phase: JWSessionPhase.ready));
  }

  Future<void> bindFirstTime(JWIdentity identity,
      {required bool confirmed}) async {
    if (!confirmed) {
      throw StateError('First JW bind requires explicit user confirmation');
    }
    if (_state.phase != JWSessionPhase.loginRejected &&
        _state.phase != JWSessionPhase.connected &&
        _state.phase != JWSessionPhase.readOnly) {
      throw StateError('JW bind is not available in ${_state.phase.name}');
    }
    _publish(
        _state.copyWith(phase: JWSessionPhase.loggingIn, clearError: true));
    final reply = await _link.request(JWProtocolCommands.bind(identity.bytes));
    if (!_isSuccess(reply)) {
      _publish(_state.copyWith(phase: JWSessionPhase.loginRejected));
      return;
    }
    _publish(_state.copyWith(phase: JWSessionPhase.ready));
  }

  /// Removes this installation's binding after an explicit application-level
  /// confirmation. JW firmware does not send a business reply for this command.
  Future<void> unbind({required bool confirmed}) async {
    if (!confirmed) {
      throw StateError('JW unbind requires explicit user confirmation');
    }
    if (_state.phase != JWSessionPhase.ready) {
      throw StateError('JW unbind is not available in ${_state.phase.name}');
    }
    await _link.send(JWProtocolCommands.unbind());
    _publish(_state.copyWith(phase: JWSessionPhase.readOnly));
  }

  Future<JWDeviceInfo> _readDeviceInfo() async {
    if (connection is! WatchBleConnection) {
      return JWDeviceInfo(targetId: connection.target.deviceId);
    }
    final ble = connection as WatchBleConnection;
    Future<String?> text(String service, String characteristic) async {
      try {
        final bytes = await ble.readGatt(
            service: service, characteristic: characteristic);
        final value = utf8
            .decode(bytes, allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim();
        return value.isEmpty ? null : value;
      } catch (_) {
        return null;
      }
    }

    int? battery;
    try {
      final bytes = await ble.readGatt(service: '180f', characteristic: '2a19');
      battery = bytes.length == 1 && bytes.single <= 100 ? bytes.single : null;
    } catch (_) {}
    return JWDeviceInfo(
      targetId: connection.target.deviceId,
      name: await text('1800', '2a00'),
      serialNumber: await text('180a', '2a25'),
      firmware: await text('180a', '2a26'),
      hardware: await text('180a', '2a27'),
      battery: battery,
    );
  }

  Future<Map<JWFeature, JWFeatureSupport>> _readFeatures() async {
    final functions = await _link.request(JWProtocolCommands.functions());
    final factory = await _link.request(JWProtocolCommands.factorySwitch());
    if (functions.value.length != 8 || factory.value.length != 1) {
      throw const FormatException('Invalid JW capability payload');
    }
    final bits = BigInt.parse(
        functions.value
            .map((value) => value.toRadixString(16).padLeft(2, '0'))
            .join(),
        radix: 16);
    bool bit(int index) => ((bits >> index) & BigInt.one) == BigInt.one;
    JWFeatureSupport support(JWFeature feature, bool value) => JWFeatureSupport(
        feature: feature,
        availability: value
            ? JWFeatureAvailability.supported
            : JWFeatureAvailability.unsupported,
        reason: value
            ? null
            : 'Current device capability list does not report support');
    return Map.unmodifiable({
      JWFeature.connection: support(JWFeature.connection, true),
      JWFeature.deviceInformation: support(JWFeature.deviceInformation, true),
      JWFeature.settings:
          support(JWFeature.settings, bit(43) || bit(44) || bit(45)),
      JWFeature.reminders:
          support(JWFeature.reminders, bit(58) || bit(59) || bit(40)),
      JWFeature.measurements: support(
          JWFeature.measurements, bit(24) || bit(29) || bit(33) || bit(34)),
      JWFeature.history:
          support(JWFeature.history, bit(34) || bit(36) || bit(37)),
      JWFeature.notifications: support(JWFeature.notifications, bit(40)),
      JWFeature.controls: support(JWFeature.controls, bit(52) || bit(54)),
      JWFeature.sport: support(JWFeature.sport, bit(3) || bit(48)),
      JWFeature.advancedHealth: support(
          JWFeature.advancedHealth, bit(0) || bit(2) || bit(5) || bit(15)),
    });
  }

  bool _isSuccess(JWProtocolMessage reply) =>
      reply.value.length == 1 && reply.value.single == 0;

  void _requireConnected() {
    if (!_link.isOpen || _state.phase == JWSessionPhase.disconnected) {
      throw StateError('JW session is not connected');
    }
  }

  void _publish(JWSessionState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _linkFailures?.cancel();
    await _link.dispose();
    _state = _state.copyWith(phase: JWSessionPhase.disposed);
    await _states.close();
  }
}
