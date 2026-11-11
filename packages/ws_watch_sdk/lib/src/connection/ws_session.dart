import 'dart:async';

import 'package:watch_transport/watch_transport.dart';

import '../config/ws_config.dart' show WSSessionConfig, WSLinkConfig;
import '../history/ws_health_history_sync.dart';
import '../history/ws_history_models.dart';
import '../history/ws_history_sync_frame.dart';
import '../history/ws_history_sync_listener.dart';
import '../honey/honey_bind.dart';
import '../model/ws_device_info.dart';
import '../model/ws_error.dart';
import '../model/ws_identity.dart';
import '../model/ws_session_state.dart';
import '../control/ws_control.dart';
import '../measure/ws_measure.dart';
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
  WSControl? _control;

  bool get isHealthSyncActive => _healthSync != null;

  WSSessionState get state => _state;
  Stream<WSSessionState> get states => _states.stream;

  String? get authenticatedUserId => _authenticatedUserId;

  WSHistoryScope? get historyScope {
    final userId = _authenticatedUserId;
    if (userId == null || !_state.isReady) return null;
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
        isReady: () => _state.isReady,
        replyTimeout: _config.replyTimeout,
      );

  WSMeasure get measure => _measure ??= WSMeasure(
        link: _link,
        isReady: () => _state.isReady,
        replyTimeout: _config.replyTimeout,
      );

  WSControl get control => _control ??= WSControl(
        link: _link,
        isReady: () => _state.isReady,
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
    _publish(_state.copyWith(phase: WSSessionPhase.disconnected));
  }

  Future<void> unbind({required bool confirmed}) async {
    if (!confirmed) {
      throw StateError('WS unbind requires explicit user confirmation');
    }
    if (_state.phase != WSSessionPhase.ready) {
      throw StateError('WS unbind is not available in ${_state.phase.name}');
    }
    await _link.send(HoneyBindCommand.unbindRequest());
    _authenticatedUserId = null;
    _publish(_state.copyWith(phase: WSSessionPhase.connected));
  }

  Future<void> login(String userId) async {
    final identity = WSIdentity(userId);
    _requireConnected();
    _publish(
        _state.copyWith(phase: WSSessionPhase.loggingIn, clearError: true));
    final reply = await _link.request(
      HoneyBindCommand.loginRequest(identity.value),
      replyKey: HoneyBindCommand.keyLoginReply,
      timeout: _config.replyTimeout,
    );
    final code = HoneyBindCommand.decodeResultByte(reply.value);
    if (!HoneyBindCommand.isLoginSuccess(code)) {
      _authenticatedUserId = null;
      _publish(_state.copyWith(phase: WSSessionPhase.loginRejected));
      return;
    }
    _authenticatedUserId = identity.value;
    _publish(_state.copyWith(phase: WSSessionPhase.ready));
    await _applyPhoneDefaults();
  }

  Future<void> bindFirstTime(String userId, {required bool confirmed}) async {
    final identity = WSIdentity(userId);
    if (!confirmed) {
      throw StateError('WS bind requires explicit user confirmation');
    }
    _requireConnected();
    _publish(
        _state.copyWith(phase: WSSessionPhase.loggingIn, clearError: true));
    final reply = await _link.request(
      HoneyBindCommand.bindRequest(identity.value),
      replyKey: HoneyBindCommand.keyBindReply,
      timeout: _config.replyTimeout,
    );
    final code = HoneyBindCommand.decodeResultByte(reply.value);
    if (!HoneyBindCommand.isBindSuccess(code)) {
      _authenticatedUserId = null;
      _publish(_state.copyWith(phase: WSSessionPhase.loginRejected));
      return;
    }
    _authenticatedUserId = identity.value;
    _publish(_state.copyWith(phase: WSSessionPhase.ready));
    await _applyPhoneDefaults();
  }

  Future<void> _applyPhoneDefaults() async {
    await settings.setPhoneSystem(_config.phoneSystem);
    await settings.setTimeUnix(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Full Honey `0x05` sync (`0x00` all types) into [historyStore].
  Future<void> syncHealthData(
    WSHistorySyncListener listener, {
    void Function(WSHistorySyncFrame frame)? onHistoryFrame,
  }) {
    final scope = historyScope;
    if (scope == null || !_state.isReady) {
      throw StateError('syncHealthData requires authenticated ready session');
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
