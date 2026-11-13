import 'dart:async';

import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

import '../model/jw_error.dart';
import '../model/jw_session_state.dart';
import '../simulation/jw_sim_device.dart';
import 'jw_attached_session.dart';

import '../storage/jw_history_store.dart';
import 'jw_scan_device.dart';
import 'jw_session.dart';

/// Public JW entry point. It owns scanning, the JW health database, and every
/// single-use session. Repeated opens reuse a live session; reconnection after
/// terminal state creates a new session. Apps share one Watch through DI.
final class JWWatch {
  /// Optional override for the on-disk database file. When omitted,
  /// [initialize] creates `jw_watch.db` under the application support directory.
  ///
  /// Optional pre-opened store, intended for unit tests. Production apps should
  /// leave this null so [initialize] owns the default database lifecycle.
  JWWatch({
    WatchBleScanner? scanner,
    WatchTransport? transport,
    String? historyDatabasePath,
    JWHistoryStore? historyStore,
    this.maxConnectedDevices = 4,
    this.maxAttachedSessions = 64,
    List<JWScanDevice> simulatedDevices = const [],
  })  : _historyDatabasePath = historyDatabasePath,
        _injectedHistoryStore = historyStore,
        _scanner = scanner ?? WatchBleScanner(),
        _transport = transport ??
            WatchBleTransport(config: WatchBleConfig(profile: jwBleProfile())) {
    if (maxConnectedDevices < 1 || maxAttachedSessions < 1) {
      throw ArgumentError('Session limits must be positive');
    }
    if (_transport is! WatchSimulationTransport &&
        simulatedDevices.isNotEmpty) {
      throw ArgumentError(
          'Simulated scan devices require a simulation transport');
    }
    _simulatedDevices = List.unmodifiable(simulatedDevices.isNotEmpty
        ? simulatedDevices
        : _transport is WatchSimulationTransport
            ? _transport.devices.map(
                (d) => JWScanDevice(deviceMac: d.id, name: d.name, rssi: 0))
            : <JWScanDevice>[]);

    _subscriptions.add(_scanner.results.listen((advertisements) {
      if (!_devices.isClosed) {
        _devices.add([
          ..._simulatedDevices,
          for (final advertisement in advertisements)
            if (isJWCandidate(advertisement))
              JWScanDevice.fromAdvertisement(advertisement),
        ]);
      }
    }));
    _subscriptions.add(_scanner.errors.listen(_errors.add));
  }

  /// Two independent simulated watches using real JW framing and L2 commands.
  factory JWWatch.simulation({
    JWHistoryStore? historyStore,
    String? historyDatabasePath,
    int maxConnectedDevices = 4,
  }) {
    final transport = WatchSimulationTransport();
    final devices = <JWScanDevice>[];
    for (var i = 1; i <= 2; i++) {
      final id = 'jw-sim-$i';
      final name = 'JW Simulator $i';
      transport.register(jwSimWatchDevice(
        id: id,
        name: name,
        state: JWSimWatchState(heartRate: 60 + i * 10),
      ));
      devices.add(JWScanDevice(deviceMac: id, name: name, rssi: 0));
    }
    return JWWatch(
      transport: transport,
      simulatedDevices: devices,
      historyStore: historyStore,
      historyDatabasePath: historyDatabasePath,
      maxConnectedDevices: maxConnectedDevices,
    );
  }

  final int maxConnectedDevices;
  final int maxAttachedSessions;
  late final List<JWScanDevice> _simulatedDevices;
  final _sessions = <String, _SessionEntry>{};
  final _attached = StreamController<List<JWAttachedSession>>.broadcast();
  Future<void>? _closingAll;
  Future<void>? _disposing;
  Future<void>? _initializing;

  bool get usesBleScan => _transport is! WatchSimulationTransport;
  Stream<List<JWAttachedSession>> get attachedSessions => _attached.stream;
  List<JWAttachedSession> get attachedSessionsSnapshot => List.unmodifiable([
        for (final entry in _sessions.values) entry.snapshot,
      ]);

  String _key(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(id, 'deviceId');
    return usesBleScan ? trimmed.toLowerCase() : trimmed;
  }

  void _publishSessions() {
    if (!_attached.isClosed) _attached.add(attachedSessionsSnapshot);
  }

  JWWatchSession? sessionOf(String deviceId) {
    final entry = _sessions[_key(deviceId)];
    return entry == null ||
            entry.closing != null ||
            entry.session.isDisposed ||
            _terminal(entry.session.state.phase)
        ? null
        : entry.session;
  }

  /// Creates/reuses a session without connecting. Waits for an old generation's
  /// cleanup; it never acquires a second connection for the same device.
  Future<JWWatchSession> openSession(String deviceId) async {
    _checkCanOpen();
    final entry = _sessions[_key(deviceId)];
    if (entry != null &&
        (entry.closing != null ||
            entry.session.isDisposed ||
            _terminal(entry.session.state.phase))) {
      await closeSession(deviceId);
    }
    return createSession(deviceId);
  }

  void _checkCanOpen() {
    _checkNotDisposed();
    if (!_initialized) {
      throw StateError('JW SDK must be initialized before connecting.');
    }
    if (_closingAll != null) {
      throw const JWException(
          JWErrorCode.unavailable, 'All sessions are closing');
    }
  }

  static bool _terminal(JWSessionPhase phase) => switch (phase) {
        JWSessionPhase.failed ||
        JWSessionPhase.disconnected ||
        JWSessionPhase.disposed =>
          true,
        _ => false,
      };

  Future<void> closeSession(String deviceId) {
    final entry = _sessions[_key(deviceId)];
    if (entry == null) return Future.value();
    if (entry.closing != null) return entry.closing!;
    final done = Completer<void>();
    entry.closing = done.future;
    entry.closeError = null;
    _publishSessions();
    () async {
      try {
        await entry.session.dispose();
        await entry.subscription?.cancel();
        if (identical(_sessions[entry.id], entry)) _sessions.remove(entry.id);
        _publishSessions();
        done.complete();
      } catch (error, stack) {
        entry.closing = null;
        entry.closeError = error;
        _publishSessions();
        done.completeError(error, stack);
      }
    }();
    return done.future;
  }

  /// Attempts every entry even if one fails. Failed entries remain visible and
  /// retain their capacity reservation, so cleanup can be retried safely.
  Future<void> closeAllSessions() {
    if (_closingAll != null) return _closingAll!;
    final done = Completer<void>();
    _closingAll = done.future;
    () async {
      final failures = <String, Object>{};
      await Future.wait(_sessions.keys.toList().map((id) async {
        try {
          await closeSession(id);
        } catch (error) {
          failures[id] = error;
        }
      }));
      _closingAll = null;
      if (failures.isEmpty) {
        done.complete();
      } else {
        done.completeError(JWSessionCloseException(Map.unmodifiable(failures)));
      }
    }();
    return done.future;
  }

  final String? _historyDatabasePath;
  final JWHistoryStore? _injectedHistoryStore;
  final WatchBleScanner _scanner;
  final WatchTransport _transport;
  final _devices = StreamController<List<JWScanDevice>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  JWHistoryStore? _historyStore;
  bool _initialized = false;
  bool _disposed = false;

  Stream<List<JWScanDevice>> get scanResults => _devices.stream;
  Stream<Object> get scanErrors => _errors.stream;
  bool get isScanning => _scanner.isScanning;
  bool get isInitialized => _initialized;

  /// Opens `jw_watch.db` and marks this SDK instance ready for use.
  ///
  /// Health history is persisted automatically during [JWWatchSession]
  /// synchronization; callers query through [historyStore] and
  /// [JWWatchSession.historyScope] without opening storage themselves.
  Future<void> initialize() {
    _checkNotDisposed();
    if (_initialized || _initializing != null) {
      return Future.error(StateError('JW SDK has already been initialized.'));
    }
    return _initializing =
        _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
    final store = _injectedHistoryStore ??
        await JWHistoryStore.open(databasePath: _historyDatabasePath);
    if (_disposed) {
      if (_injectedHistoryStore == null) await store.dispose();
      throw StateError('JWWatch disposed during initialization');
    }
    _historyStore = store;
    _initialized = true;
  }

  /// Local JW health history opened by [initialize].
  JWHistoryStore get historyStore {
    _checkNotDisposed();
    final store = _historyStore;
    if (!_initialized || store == null) {
      throw StateError(
          'JW SDK must be initialized before using history storage.');
    }
    return store;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) {
    _checkNotDisposed();
    if (!_initialized) {
      return Future.error(
          StateError('JW SDK must be initialized before scanning.'));
    }
    if (_simulatedDevices.isNotEmpty) _devices.add(_simulatedDevices);
    if (!usesBleScan) return Future.value();
    return _scanner.start(
      services: jwBleScanServiceUuids,
      timeout: timeout,
    );
  }

  Future<void> stopScan() => _scanner.stop();

  /// Synchronous compatibility entry point with the same ownership/dedupe as
  /// [openSession]. Use openSession when a prior session may still be closing.
  JWWatchSession createSession(String deviceMac) {
    _checkCanOpen();
    final id = _key(deviceMac);
    // Registry keys are case-insensitive, but preserve the transport's scanned
    // ID (and existing history scope spelling) at the device boundary.
    final targetId = deviceMac.trim();
    final existing = _sessions[id];
    if (existing != null) {
      final live = sessionOf(id);
      if (live != null) return live;
      throw const JWException(JWErrorCode.unavailable,
          'Device session is closing; await openSession');
    }
    if (_sessions.length >= maxAttachedSessions) {
      throw const JWException(
          JWErrorCode.sessionLimit, 'Attached session limit reached');
    }
    late final _SessionEntry entry;
    final session = JWWatchSession(
      _transport.createConnection(WatchDeviceTarget(
        transportId: usesBleScan ? 'ble' : 'simulation',
        deviceId: targetId,
      )),
      historyStore: historyStore,
      onConnectRequested: () {
        _checkCanOpen();
        if (entry.closing != null) {
          throw const JWException(
              JWErrorCode.unavailable, 'Session is closing');
        }
        if (!entry.reserved &&
            _sessions.values.where((e) => e.reserved).length >=
                maxConnectedDevices) {
          throw const JWException(
              JWErrorCode.sessionLimit, 'Connected device limit reached');
        }
        entry.reserved = true;
      },
    );
    entry = _SessionEntry(id, session, !usesBleScan);
    _sessions[id] = entry;
    entry.subscription = session.states.listen((state) {
      _publishSessions();
      if (_terminal(state.phase) && entry.closing == null) {
        scheduleMicrotask(() {
          if (identical(_sessions[id], entry)) {
            // Error is exposed on attachedSessionsSnapshot.closeError.
            closeSession(id).catchError((Object _) {});
          }
        });
      }
    });
    _publishSessions();
    return session;
  }

  Future<void> dispose() =>
      _disposing ??= _dispose().catchError((Object error) {
        _disposing = null;
        throw error;
      });

  Future<void> _dispose() async {
    _disposed = true;
    try {
      await _initializing;
    } catch (_) {}
    await _scanner.stop();
    await closeAllSessions();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _scanner.dispose();
    if (_injectedHistoryStore == null) {
      await _historyStore?.dispose();
    }
    _historyStore = null;
    _initialized = false;
    await _devices.close();
    await _errors.close();
    await _attached.close();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('JWWatch has been disposed');
  }
}

final class _SessionEntry {
  _SessionEntry(this.id, this.session, this.isSimulated);
  final String id;
  final JWWatchSession session;
  final bool isSimulated;
  bool reserved = false;
  StreamSubscription<JWSessionState>? subscription;
  Future<void>? closing;
  Object? closeError;
  JWAttachedSession get snapshot => JWAttachedSession(
        deviceId: session.connection.target.deviceId,
        session: session,
        state: session.state,
        isSimulated: isSimulated,
        isClosing: closing != null,
        closeError: closeError,
      );
}
