import 'dart:async';

import 'package:watch_transport/watch_transport.dart';

import '../config/ws_config.dart' show WSSessionConfig, WSLinkConfig;
import '../history/ws_health_history_sync.dart';
import '../history/ws_history_models.dart';
import '../history/ws_history_sync_frame.dart';
import '../history/ws_history_sync_listener.dart';
import '../capability/ws_capabilities.dart';
import '../debug/ws_debug_log.dart';
import '../wire/ws_bind_command.dart';
import '../wire/ws_device_command.dart';
import '../model/ws_device_info.dart';
import '../model/ws_error.dart';
import '../model/ws_identity.dart';
import '../model/ws_session_state.dart';
import '../control/ws_control.dart';
import '../measure/ws_measure.dart';
import '../measure/ws_measure_coordinator.dart';
import '../session/ws_history.dart';
import '../session/ws_settings.dart';
import '../today/ws_today.dart';
import '../simulation/ws_sim_constants.dart';
import '../storage/ws_history_store.dart';
import 'ws_link.dart';

final class WSWatchSession {
  WSWatchSession({
    required this.connection,
    required WSHistoryStore historyStore,
    WSSessionConfig config = const WSSessionConfig(),
    WSLinkConfig linkConfig = const WSLinkConfig(),
  })  : _historyStore = historyStore,
        _config = config,
        _link = WSLink(connection, config: linkConfig),
        _state = const WSSessionState();

  final WatchTransportConnection connection;
  final WSHistoryStore _historyStore;
  final WSSessionConfig _config;
  final WSLink _link;
  final _states = StreamController<WSSessionState>.broadcast(sync: true);
  WSSessionState _state;
  StreamSubscription<WSException>? _linkFailures;
  Future<void>? _opening;
  Future<void>? _healthSync;
  String? _authenticatedUserId;
  bool _disposed = false;
  WSToday? _today;
  WSMeasure? _measure;
  WSMeasureCoordinator? _measureCoordinator;
  WSControl? _control;

  bool get isHealthSyncActive => _healthSync != null;

  WSSessionState get state => _state;
  Stream<WSSessionState> get states => _states.stream;

  String? get authenticatedUserId => _authenticatedUserId;

  WSHistoryScope? get historyScope {
    final userId = _authenticatedUserId;
    if (userId == null) return null;
    final mac = _state.device?.deviceMac ?? connection.target.deviceId;
    return WSHistoryScope(userId: userId, deviceMac: mac);
  }

  WSHistoryStore get historyStore => _historyStore;

  late final WSSettings settings = WSSettings(
    _link,
    replyTimeout: _config.replyTimeout,
  );

  late final WSHistory history = WSHistory(
    link: _link,
    store: _historyStore,
    scope: () => historyScope,
  );

  WSToday get today => _today ??= WSToday(
        link: _link,
        isConnected: () => _state.isConnected,
        replyTimeout: _config.replyTimeout,
      );

  WSMeasure get measure => _measure ??= WSMeasure(
        link: _link,
        isConnected: () => _state.isConnected,
        isHealthSyncActive: () => isHealthSyncActive,
        coordinator: _measureCoordinator ??= WSMeasureCoordinator(
          link: _link,
          isHealthSyncActive: () => isHealthSyncActive,
        ),
        replyTimeout: _config.replyTimeout,
      );

  WSControl get control => _control ??= WSControl(
        link: _link,
        isConnected: () => _state.isConnected,
        replyTimeout: _config.replyTimeout,
      );

  Future<void> connect() => _opening ??= _connect();

  Future<void> _connect() async {
    _publish(_state.copyWith(
        phase: WSSessionPhase.connecting, clearError: true));
    _linkFailures = _link.failures.listen((error) {
      if (!_disposed) {
        _publish(_state.copyWith(
            phase: WSSessionPhase.disconnected, error: error));
      }
    });
    try {
      await _link.open();
      final deviceMac = connection.target.deviceId;
      _publish(_state.copyWith(
        phase: WSSessionPhase.connected,
        device: WSDeviceInfo(
          deviceMac: deviceMac,
          name: connection.target.deviceId == kWsWatchSimDeviceId
              ? 'WS Watch Simulator'
              : null,
        ),
      ));
    } catch (error) {
      if (!_disposed) {
        _publish(
            _state.copyWith(phase: WSSessionPhase.failed, error: error));
      }
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_disposed) return;
    _authenticatedUserId = null;
    _opening = null;
    await _linkFailures?.cancel();
    _linkFailures = null;
    await _link.close();
    _publish(_state.copyWith(
      phase: WSSessionPhase.disconnected,
      clearCapabilities: true,
    ));
  }

  /// Reads WS device info (`0x02` key `0x30`). Updates [WSSessionState.device].
  Future<void> readDeviceInfo() async {
    _requireConnected();
    final phaseAfter = _preservePhaseAfterSideEffect();
    _publish(_state.copyWith(clearError: true));
    WSWatchDebugLog.apiIn('WSWatchSession.readDeviceInfo');
    try {
      final reply = await _link.requestWhere(
        WSDeviceCommand.readDeviceInfo(),
        matches: WSDeviceCommand.isDeviceInfoReadReply,
        timeout: _config.replyTimeout,
      );
      final stub = WSDeviceCommand.decodeDeviceInfoStub(reply);
      final current = _state.device;
      final deviceMac = current?.deviceMac ?? connection.target.deviceId;
      _publish(_state.copyWith(
        phase: phaseAfter,
        device: WSDeviceInfo(
          deviceMac: deviceMac,
          name: current?.name,
          modelId: stub.modelId,
          serialNumber:
              stub.serialNumber.isEmpty ? null : stub.serialNumber,
        ),
      ));
      WSWatchDebugLog.apiOut(
        'WSWatchSession.readDeviceInfo',
        'model=0x${stub.modelId.toRadixString(16)} '
        'serial=${stub.serialNumber.isEmpty ? "—" : stub.serialNumber}',
      );
    } catch (error) {
      if (!_disposed) {
        _publish(_state.copyWith(phase: phaseAfter, error: error));
      }
      rethrow;
    }
  }

  /// Reads the 16-byte capability bitmap (`0x02` key `0x31`).
  ///
  /// Result is stored on [WSSessionState.capabilities]. Same entry point as
  /// legacy JW demos (`readDeviceFeatures`).
  Future<void> readDeviceFeatures() async {
    _requireConnected();
    final phaseAfter = _preservePhaseAfterSideEffect();
    _publish(_state.copyWith(clearError: true));
    WSWatchDebugLog.apiIn('WSWatchSession.readDeviceFeatures');
    try {
      final reply = await _link.requestWhere(
        WSDeviceCommand.readCapabilities(),
        matches: WSDeviceCommand.isCapabilitiesReadReply,
        timeout: _config.replyTimeout,
      );
      final blob = WSDeviceCommand.decodeCapabilitiesBlob(reply);
      final capabilities = WSCapabilities.parse(blob);
      _publish(_state.copyWith(
        phase: phaseAfter,
        capabilities: capabilities,
      ));
      WSWatchDebugLog.apiOut(
        'WSWatchSession.readDeviceFeatures',
        'capabilities=${capabilities.raw.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}',
      );
    } catch (error) {
      if (!_disposed) {
        _publish(_state.copyWith(phase: phaseAfter, error: error));
      }
      rethrow;
    }
  }

  WSSessionPhase _preservePhaseAfterSideEffect() =>
      _state.isReady ? WSSessionPhase.ready : _state.phase;

  Future<void> unbind({required bool confirmed}) async {
    if (!confirmed) {
      throw StateError('WS unbind requires explicit user confirmation');
    }
    if (_state.phase != WSSessionPhase.ready) {
      throw StateError('WS unbind is not available in ${_state.phase.name}');
    }
    await _link.send(WSBindCommand.unbindRequest());
    _authenticatedUserId = null;
    _publish(_state.copyWith(phase: WSSessionPhase.connected));
  }

  Future<void> login(String userId) async {
    final identity = WSIdentity(userId);
    _requireConnected();
    _publish(
        _state.copyWith(phase: WSSessionPhase.loggingIn, clearError: true));
    try {
      final reply = await _link.request(
        WSBindCommand.loginRequest(identity.value),
        replyKey: WSBindCommand.keyLoginReply,
        timeout: _config.replyTimeout,
      );
      final code = WSBindCommand.decodeResultByte(reply.value);
      if (!WSBindCommand.isLoginSuccess(code)) {
        _authenticatedUserId = null;
        _publish(_state.copyWith(phase: WSSessionPhase.loginRejected));
        return;
      }
      _authenticatedUserId = identity.value;
      _publish(_state.copyWith(phase: WSSessionPhase.ready));
      await _applyPhoneDefaults();
    } catch (error) {
      _authenticatedUserId = null;
      if (!_disposed) {
        _publish(_state.copyWith(
          phase: WSSessionPhase.connected,
          error: error,
        ));
      }
      rethrow;
    }
  }

  Future<void> bindFirstTime(String userId, {required bool confirmed}) async {
    final identity = WSIdentity(userId);
    if (!confirmed) {
      throw StateError('WS bind requires explicit user confirmation');
    }
    _requireConnected();
    _publish(
        _state.copyWith(phase: WSSessionPhase.loggingIn, clearError: true));
    try {
      final reply = await _link.request(
        WSBindCommand.bindRequest(identity.value),
        replyKey: WSBindCommand.keyBindReply,
        timeout: _config.replyTimeout,
      );
      final code = WSBindCommand.decodeResultByte(reply.value);
      if (!WSBindCommand.isBindSuccess(code)) {
        _authenticatedUserId = null;
        _publish(_state.copyWith(phase: WSSessionPhase.loginRejected));
        return;
      }
      _authenticatedUserId = identity.value;
      _publish(_state.copyWith(phase: WSSessionPhase.ready));
      await _applyPhoneDefaults();
    } catch (error) {
      _authenticatedUserId = null;
      if (!_disposed) {
        _publish(_state.copyWith(
          phase: WSSessionPhase.connected,
          error: error,
        ));
      }
      rethrow;
    }
  }

  Future<void> _applyPhoneDefaults() async {
    await settings.setPhoneSystem(_config.phoneSystem);
    await settings.setTimeUnix(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Full WS `0x05` sync (`0x00` all types) into [historyStore].
  Future<void> syncHealthData(
    WSHistorySyncListener listener, {
    void Function(WSHistorySyncFrame frame)? onHistoryFrame,
  }) {
    _requireConnected();
    final scope = historyScope;
    if (scope == null) {
      throw StateError(
        'syncHealthData requires historyScope (set userId via login/bind)',
      );
    }
    if (_healthSync != null) {
      throw StateError('health sync already active');
    }
    final engine = WSHealthHistorySync(
      link: _link,
      store: _historyStore,
      scope: scope,
      listener: listener,
      onHistoryFrame: onHistoryFrame,
    );
    _healthSync = engine.run().whenComplete(() => _healthSync = null);
    return _healthSync!;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _measureCoordinator?.dispose();
    _measureCoordinator = null;
    await _linkFailures?.cancel();
    await _link.close();
    _publish(_state.copyWith(phase: WSSessionPhase.disposed));
    await _states.close();
  }

  void _requireConnected() {
    if (_disposed) {
      throw const WSException(WSErrorCode.disposed, 'Session disposed');
    }
    if (!_state.isConnected) {
      throw StateError('WS session is not connected (${_state.phase.name})');
    }
  }

  void _publish(WSSessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
