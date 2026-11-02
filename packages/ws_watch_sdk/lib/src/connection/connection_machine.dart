import 'dart:async';
import 'dart:io';

import '../capability/capabilities.dart';
import '../config.dart';
import '../debug/debug_api.dart';
import '../errors.dart';
import '../link/link.dart';
import '../model/device_info.dart';
import '../protocol/cmd_03_bind.dart';
import '../protocol/core_registry.dart';
import '../session/session.dart';
import '../simulation/sim_watch_session.dart';
import '../storage/device_store.dart';
import 'connection_state.dart';
import 'environment.dart';
import 'user_id.dart';

/// One attempt owns all of its async results and resources. Obsolete attempts
/// can finish cleanup but can never publish readiness into a new connection.
class WSConnectionMachine {
  WSConnectionMachine(this.config, this.debug, this.environment);
  final WSConfig config;
  final WSDebugController debug;
  final WSConnectionEnvironment environment;
  final _changes = StreamController<WSConnectionChange>.broadcast();
  static final Set<String> _leases = {};
  static int _generation = 0;
  WSConnectionState state = WSConnectionState.disconnected;
  WSDeviceInfo? deviceInfo;
  WSCapabilities? capabilities;
  String? userId;
  String? deviceId;
  Stream<WSConnectionChange> get changes => _changes.stream;
  _Attempt? _current;
  Future<void>? _disconnecting, _disposing;
  Future<WSDeviceStore>? _store;
  Timer? _reconnect;
  bool _disposed = false;
  (String, String?)? _desired;
  int _retries = 0, _targetEpoch = 0;

  Future<void> connect(String id, {String? userId}) {
    if (_disposed) return Future.error(const WSDisposedException());
    if (id.isEmpty) {
      return Future.error(ArgumentError('deviceId must not be empty'));
    }
    if (userId != null) {
      try {
        WSUserId(userId);
      } catch (error, stack) {
        return Future.error(error, stack);
      }
    }
    if (state != WSConnectionState.disconnected ||
        _current != null ||
        _disconnecting != null ||
        _leases.contains(id)) {
      return Future.error(WSConnectException(
          state,
          WSConnectFailure.alreadyConnected,
          'a connection or cleanup is already active for $id'));
    }
    if (config.phoneSystem != null &&
        config.phoneSystem != 1 &&
        config.phoneSystem != 2) {
      return Future.error(
          ArgumentError('phoneSystem must be iOS=1 or Android=2'));
    }
    config.link.validate();
    config.session.validate();
    if (config.connectTimeouts.connecting <= Duration.zero ||
        config.connectTimeouts.discovering <= Duration.zero ||
        config.connectTimeouts.awaitingConfirm <= Duration.zero) {
      return Future.error(
          ArgumentError('connection timeouts must be positive'));
    }
    _reconnect?.cancel();
    _desired = (id, userId);
    _targetEpoch++;
    return _start(id, userId);
  }

  Future<void> _start(String id, String? suppliedId) {
    _leases.add(id);
    final attempt = _Attempt(++_generation, id);
    _current = attempt;
    deviceId = id;
    deviceInfo = null;
    capabilities = null;
    userId = null;
    _set(WSConnectionState.connecting);
    return _run(attempt, suppliedId);
  }

  Future<void> _run(_Attempt attempt, String? suppliedId) async {
    try {
      await _phase(attempt, _open(attempt, suppliedId),
          config.connectTimeouts.connecting, WSTimeoutKind.connect);
      _check(attempt);
      _set(WSConnectionState.discovering);
      final managed = attempt.transport!;
      // Listen before subscribing to Notify so early bytes cannot be lost.
      final link = WSLink(managed.connection,
          config: config.link, generation: attempt.generation);
      attempt.session = WSSession(link, WSInitializationProtocol.registry(),
          config: config.session);
      unawaited(link.terminated.then((error) {
        if (identical(_current, attempt) &&
            attempt.ready &&
            !attempt.cancelled) {
          unawaited(_lost(attempt, error));
        }
      }));
      debug.attach(attempt.session!,
          allowRaw: () =>
              identical(_current, attempt) &&
              attempt.ready &&
              !attempt.cancelled);
      attempt.debugAttached = true;
      await _phase(attempt, managed.connection.prepare(),
          config.connectTimeouts.discovering, WSTimeoutKind.discover);
      _check(attempt);
      _set(WSConnectionState.authenticating);
      final session = attempt.session!;
      final uid = WSUserId(userId!);
      final login =
          await _cancelable(attempt, session.query(WSBindProtocol.login, uid));
      if (login == 1) {
        final result = await _cancelable(
            attempt,
            session.query(
                WSBindProtocol.bind(config.connectTimeouts.awaitingConfirm),
                uid, onAcknowledged: () {
              if (_valid(attempt)) _set(WSConnectionState.awaitingConfirm);
            }));
        _check(attempt);
        if (result != 0) {
          throw WSConnectException(
              state,
              result == 1
                  ? WSConnectFailure.confirmTimeout
                  : result == 2
                      ? WSConnectFailure.confirmRejected
                      : WSConnectFailure.protocolError,
              'binding returned $result');
        }
      } else if (login != 0) {
        throw WSConnectException(
            state, WSConnectFailure.protocolError, 'login returned $login');
      }
      _check(attempt);
      try {
        await _cancelable(
            attempt, (await _store!).rememberUserId(attempt.id, userId!));
      } on WSConnectException {
        rethrow;
      } catch (error) {
        throw WSStorageException(
            'cannot persist authenticated identity: $error');
      }
      _check(attempt);
      _set(WSConnectionState.initializing);
      // Desktop values are unspecified in the wire protocol. Simulate Android
      // only for the virtual watch; real desktop integrations must opt in.
      final system = config.phoneSystem ??
          (Platform.isIOS
              ? 1
              : Platform.isAndroid || idIsSim(attempt.id)
                  ? 2
                  : null);
      if (system == null) {
        throw const WSConnectException(
            WSConnectionState.initializing,
            WSConnectFailure.protocolError,
            'configure phoneSystem for this platform');
      }
      await _cancelable(
          attempt, session.send(WSInitializationProtocol.system, system));
      await _cancelable(attempt,
          session.send(WSInitializationProtocol.time, environment.now()));
      final capBytes = await _cancelable(
          attempt, session.query(WSInitializationProtocol.capabilities, null));
      final info = await _cancelable(
          attempt, session.query(WSInitializationProtocol.info, null));
      final caps = WSCapabilities.fromBytes(capBytes);
      try {
        await _cancelable(attempt,
            (await _store!).saveReady(attempt.id, userId!, info, caps));
      } on WSConnectException {
        rethrow;
      } catch (error) {
        throw WSStorageException('cannot persist initialized device: $error');
      }
      _check(attempt);
      deviceInfo = info;
      capabilities = caps;
      attempt.ready = true;
      _retries = 0;
      _set(WSConnectionState.ready);
    } catch (error, stack) {
      final failureStage = state;
      final reason = attempt.cancelled
          ? WSConnectFailure.cancelled
          : error is WSStorageException
              ? WSConnectFailure.storageFailed
              : error is WSProtocolDecodeException
                  ? WSConnectFailure.protocolError
                  : error is WSTimeoutException
                      ? (failureStage == WSConnectionState.awaitingConfirm
                          ? WSConnectFailure.confirmTimeout
                          : WSConnectFailure.timeout)
                      : error is WSDisconnectedException ||
                              error is WSSessionInvalidatedException
                          ? WSConnectFailure.disconnected
                          : WSConnectFailure.initFailed;
      final failure = error is WSConnectException
          ? error
          : WSConnectException(failureStage, reason, '$error');
      attempt.cancel(failure);
      await _cleanup(attempt);
      if (identical(_current, attempt)) {
        _current = null;
        deviceInfo = null;
        capabilities = null;
        _set(WSConnectionState.disconnected, failure);
      }
      Error.throwWithStackTrace(failure, stack);
    }
  }

  static bool idIsSim(String id) => id == kWsWatchSimDeviceId;

  Future<void> _open(_Attempt attempt, String? suppliedId) async {
    try {
      final store = await _loadStore();
      _check(attempt);
      final id = suppliedId ?? await store.defaultUserId(attempt.id);
      _check(attempt);
      userId = id;
    } on WSConnectException {
      rethrow;
    } catch (error) {
      throw WSStorageException('cannot load user identity: $error');
    }
    final transport = await environment.openTransport(attempt.id, config);
    if (!_valid(attempt)) {
      await transport.close();
      throw const WSConnectException(WSConnectionState.connecting,
          WSConnectFailure.cancelled, 'obsolete connection result');
    }
    attempt.transport = transport;
  }

  Future<WSDeviceStore> _loadStore() async {
    final pending = _store ??= environment.openStore(config.databasePath);
    try {
      return await pending;
    } catch (_) {
      if (identical(_store, pending)) _store = null;
      rethrow;
    }
  }

  bool _valid(_Attempt attempt) =>
      !_disposed && identical(_current, attempt) && !attempt.cancelled;
  void _check(_Attempt attempt) {
    if (!_valid(attempt)) {
      throw const WSConnectException(WSConnectionState.disconnecting,
          WSConnectFailure.cancelled, 'connection cancelled');
    }
  }

  Future<T> _cancelable<T>(_Attempt attempt, Future<T> work) => Future.any([
        work,
        attempt.cancellation.future.then<T>((error) => throw error),
      ]);
  Future<T> _phase<T>(_Attempt attempt, Future<T> work, Duration duration,
      WSTimeoutKind kind) async {
    final expired = Completer<T>();
    final timer = Timer(
        duration,
        () => expired
            .completeError(WSTimeoutException(kind, '$kind stage timed out')));
    try {
      return await _cancelable(attempt, Future.any([work, expired.future]));
    } finally {
      timer.cancel();
    }
  }

  Future<void> _lost(_Attempt attempt, Object error) async {
    final targetEpoch = _targetEpoch;
    attempt.cancel(error);
    await _cleanup(attempt);
    if (identical(_current, attempt)) {
      _current = null;
      deviceInfo = null;
      capabilities = null;
      _set(WSConnectionState.disconnected, error);
    }
    _scheduleReconnect(targetEpoch);
  }

  void _scheduleReconnect(int targetEpoch) {
    if (_disposed ||
        !config.autoReconnect ||
        _desired == null ||
        targetEpoch != _targetEpoch) {
      return;
    }
    _reconnect = Timer(environment.reconnectDelay(_retries++), () {
      if (_disposed ||
          _desired == null ||
          targetEpoch != _targetEpoch ||
          _current != null) {
        return;
      }
      final (id, uid) = _desired!;
      if (_leases.contains(id)) {
        _scheduleReconnect(targetEpoch);
        return;
      }
      unawaited(_start(id, uid).catchError((Object _) {
        _scheduleReconnect(targetEpoch);
      }));
    });
  }

  Future<void> disconnect() {
    _reconnect?.cancel();
    _desired = null;
    _targetEpoch++;
    return _disconnecting ??= _disconnect().whenComplete(() {
      _disconnecting = null;
    });
  }

  Future<void> _disconnect() async {
    final attempt = _current;
    if (attempt == null) return;
    attempt.cancel(const WSConnectException(WSConnectionState.disconnecting,
        WSConnectFailure.cancelled, 'disconnect requested'));
    _set(WSConnectionState.disconnecting);
    await _cleanup(attempt);
    if (identical(_current, attempt)) {
      _current = null;
      deviceInfo = null;
      capabilities = null;
      _set(WSConnectionState.disconnected);
    }
  }

  Future<void> unbind() async {
    if (_disposed) throw const WSDisposedException();
    final attempt = _current;
    if (state != WSConnectionState.ready || attempt?.session == null) {
      throw WSNotReadyException(state);
    }
    // Disable reconnect before issuing the non-idempotent operation.
    _desired = null;
    _targetEpoch++;
    _reconnect?.cancel();
    try {
      await attempt!.session!.send(WSBindProtocol.unbind, null);
    } finally {
      await disconnect();
    }
  }

  Future<void> _cleanup(_Attempt attempt) =>
      attempt.cleanup ??= _clean(attempt);
  Future<void> _clean(_Attempt attempt) async {
    try {
      if (attempt.debugAttached) await debug.detach();
      await attempt.session?.dispose();
      await attempt.transport?.close();
    } finally {
      _leases.remove(attempt.id);
    }
  }

  void _set(WSConnectionState next, [Object? reason]) {
    if (_changes.isClosed || state == next) return;
    final previous = state;
    state = next;
    _changes.add(WSConnectionChange(
        previous: previous,
        current: next,
        at: environment.now(),
        reason: reason?.toString()));
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    await disconnect();
    try {
      await (await _store)?.close();
    } catch (_) {/* opening failure was returned to connect */}
    await _changes.close();
  }
}

class _Attempt {
  _Attempt(this.generation, this.id);
  final int generation;
  final String id;
  bool ready = false, cancelled = false, debugAttached = false;
  final cancellation = Completer<Object>();
  WSManagedTransport? transport;
  WSSession? session;
  Future<void>? cleanup;
  void cancel(Object error) {
    if (!cancelled) {
      cancelled = true;
      cancellation.complete(error);
    }
  }
}
