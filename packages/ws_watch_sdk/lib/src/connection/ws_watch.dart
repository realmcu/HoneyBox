import 'dart:async';

import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

import '../ble/ws_ble_profile.dart';
import '../config/ws_config.dart';
import '../model/ws_error.dart';
import '../model/ws_session_state.dart';
import 'ws_attached_session.dart';
import '../simulation/ws_sim_constants.dart';
import '../simulation/ws_sim_device.dart';
import '../simulation/ws_sim_state.dart';
import '../storage/ws_history_store.dart';
import 'ws_scan_device.dart';
import 'ws_session.dart';

final class WSWatch {
  WSWatch({
    WSConfig config = const WSConfig(),
    WatchBleScanner? scanner,
    WatchTransport? bleTransport,
    WatchSimulationTransport? simulationTransport,
    WSHistoryStore? historyStore,
    this.maxConnectedDevices = 4,
    this.maxAttachedSessions = 64,
  })  : config = config,
        _historyDatabasePath = config.historyDatabasePath,
        _injectedHistoryStore = historyStore,
        _scanner = scanner ?? WatchBleScanner(),
        _bleTransport = bleTransport ??
            WatchBleTransport(config: WatchBleConfig(profile: wsBleProfile())),
        _simulationTransport =
            simulationTransport ?? WatchSimulationTransport(),
        _simState = WsSimWatchState() {
    if (maxConnectedDevices < 1 || maxAttachedSessions < 1) {
      throw ArgumentError("Session limits must be positive");
    }
    if (config.simulationEnabled) {
      _simulationTransport.register(
        wsSimWatchDevice(state: _simState),
      );
      _simulationTransport.register(wsSimWatchDevice(
        id: kWsWatchSimDeviceId2,
        name: 'WS Watch Simulator 2',
        state: WsSimWatchState()
          ..batteryPercent = 55
          ..heartRateDataFrame[7] = 82
          ..heartRateDataFrame[12] = 85,
      ));
    }
    _subscriptions.add(_scanner.results.listen((advertisements) {
      if (_devices.isClosed) return;
      if (config.simulationExclusive) return;
      final list = <WSScanDevice>[
        ..._simulatedDevices,
        for (final a in advertisements)
          if (isWSCandidate(a))
            WSScanDevice(
              deviceMac: a.deviceId,
              name: a.name,
              rssi: a.rssi,
            ),
      ];
      _devices.add(list);
    }));
    _subscriptions.add(_scanner.errors.listen(_errors.add));
  }

  final int maxConnectedDevices;
  final int maxAttachedSessions;
  List<WSScanDevice> get _simulatedDevices => !config.simulationEnabled
      ? const []
      : [
          for (final device in _simulationTransport.devices)
            WSScanDevice(
                deviceMac: device.id,
                name: device.name,
                rssi: 0,
                isSimulated: true),
        ];
  bool _isSim(String id) =>
      config.simulationEnabled &&
      _simulationTransport.devices.any((d) => d.id == id.trim());
  final _sessions = <String, _SessionEntry>{};
  final _attached = StreamController<List<WSAttachedSession>>.broadcast();
  Future<void>? _closingAll;
  Future<void>? _disposing;
  Future<void>? _initializing;

  Stream<List<WSAttachedSession>> get attachedSessions => _attached.stream;
  List<WSAttachedSession> get attachedSessionsSnapshot => List.unmodifiable([
        for (final entry in _sessions.values) entry.snapshot,
      ]);

  String _key(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(id, 'deviceId');
    return _isSim(trimmed) ? trimmed : trimmed.toLowerCase();
  }

  void _publishSessions() {
    if (!_attached.isClosed) _attached.add(attachedSessionsSnapshot);
  }

  WSWatchSession? sessionOf(String deviceId) {
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
  Future<WSWatchSession> openSession(String deviceId) async {
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
      throw StateError('WS SDK must be initialized before connecting.');
    }
    if (_closingAll != null) {
      throw const WSException(
          WSErrorCode.unavailable, 'All sessions are closing');
    }
  }

  static bool _terminal(WSSessionPhase phase) => switch (phase) {
        WSSessionPhase.failed ||
        WSSessionPhase.disconnected ||
        WSSessionPhase.disposed =>
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
        done.completeError(WSSessionCloseException(Map.unmodifiable(failures)));
      }
    }();
    return done.future;
  }

  final WSConfig config;
  final String? _historyDatabasePath;
  final WSHistoryStore? _injectedHistoryStore;
  final WatchBleScanner _scanner;
  final WatchTransport _bleTransport;
  final WatchSimulationTransport _simulationTransport;
  final WsSimWatchState _simState;
  final _devices = StreamController<List<WSScanDevice>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  WSHistoryStore? _historyStore;
  bool _initialized = false;
  bool _disposed = false;

  Stream<List<WSScanDevice>> get scanResults => _devices.stream;
  Stream<Object> get scanErrors => _errors.stream;
  bool get isScanning => _scanner.isScanning;
  bool get isInitialized => _initialized;

  Future<void> initialize() {
    _checkNotDisposed();
    if (_initialized || _initializing != null) {
      return Future.error(StateError('WS SDK has already been initialized.'));
    }
    return _initializing =
        _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
    final store = _injectedHistoryStore ??
        await WSHistoryStore.open(databasePath: _historyDatabasePath);
    if (_disposed) {
      if (_injectedHistoryStore == null) await store.dispose();
      throw StateError('WSWatch disposed during initialization');
    }
    _historyStore = store;
    _initialized = true;
  }

  /// Local WS health history opened by [initialize].
  WSHistoryStore get historyStore {
    _checkNotDisposed();
    final store = _historyStore;
    if (!_initialized || store == null) {
      throw StateError(
          'WS SDK must be initialized before using history storage.');
    }
    return store;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) {
    _checkNotDisposed();
    if (!_initialized) {
      return Future.error(
          StateError('WSWatch must be initialized before scanning.'));
    }
    if (config.simulationEnabled) {
      _devices.add(_simulatedDevices);
    }
    if (config.simulationExclusive) {
      return Future.value();
    }
    return _scanner.start(
      services: wsBleScanServiceUuids,
      timeout: timeout,
    );
  }

  Future<void> stopScan() {
    if (config.simulationExclusive) return Future.value();
    return _scanner.stop();
  }

  /// True when scan skips the platform BLE radio (simulator-only config).
  bool get isSimulationExclusive => config.simulationExclusive;

  /// Whether [startScan] uses the platform BLE scanner for this instance.
  bool get usesBleScan => config.usesBleScan;

  /// Active transport profile; fixed for the lifetime of this [WSWatch].
  WSTransportMode get transportMode => config.transportMode;

  /// Synchronous compatibility entry point with the same ownership/dedupe as
  /// [openSession]. Use openSession when a prior session may still be closing.
  WSWatchSession createSession(String deviceMac) {
    _checkCanOpen();
    final id = _key(deviceMac);
    // Registry keys are case-insensitive, but preserve the transport's scanned
    // ID (and existing history scope spelling) at the device boundary.
    final targetId = deviceMac.trim();
    final existing = _sessions[id];
    if (existing != null) {
      final live = sessionOf(id);
      if (live != null) return live;
      throw const WSException(WSErrorCode.unavailable,
          'Device session is closing; await openSession');
    }
    if (_sessions.length >= maxAttachedSessions) {
      throw const WSException(
          WSErrorCode.sessionLimit, 'Attached session limit reached');
    }
    late final _SessionEntry entry;
    final session = WSWatchSession(
      connection: (_isSim(targetId) ? _simulationTransport : _bleTransport)
          .createConnection(WatchDeviceTarget(
        transportId: _isSim(targetId) ? 'simulation' : 'ble',
        deviceId: targetId,
      )),
      historyStore: historyStore,
      config: config.session,
      linkConfig: config.link,
      onConnectRequested: () {
        _checkCanOpen();
        if (entry.closing != null) {
          throw const WSException(
              WSErrorCode.unavailable, 'Session is closing');
        }
        if (!entry.reserved &&
            _sessions.values.where((e) => e.reserved).length >=
                maxConnectedDevices) {
          throw const WSException(
              WSErrorCode.sessionLimit, 'Connected device limit reached');
        }
        entry.reserved = true;
      },
    );
    entry = _SessionEntry(id, session, _isSim(targetId));
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
    if (_disposed) throw StateError('WSWatch has been disposed');
  }
}

final class _SessionEntry {
  _SessionEntry(this.id, this.session, this.isSimulated);
  final String id;
  final WSWatchSession session;
  final bool isSimulated;
  bool reserved = false;
  StreamSubscription<WSSessionState>? subscription;
  Future<void>? closing;
  Object? closeError;
  WSAttachedSession get snapshot => WSAttachedSession(
        deviceId: session.connection.target.deviceId,
        session: session,
        state: session.state,
        isSimulated: isSimulated,
        isClosing: closing != null,
        closeError: closeError,
      );
}
