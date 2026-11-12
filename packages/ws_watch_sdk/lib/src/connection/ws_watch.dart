import 'dart:async';

import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

import '../ble/ws_ble_profile.dart';
import '../config/ws_config.dart';
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
    WatchBleTransport? bleTransport,
    WatchSimulationTransport? simulationTransport,
    WSHistoryStore? historyStore,
  })  : config = config,
        _historyDatabasePath = config.historyDatabasePath,
        _injectedHistoryStore = historyStore,
        _scanner = scanner ?? WatchBleScanner(),
        _bleTransport = bleTransport ??
            WatchBleTransport(config: WatchBleConfig(profile: wsBleProfile())),
        _simulationTransport = simulationTransport ?? WatchSimulationTransport(),
        _simState = WsSimWatchState() {
    if (config.simulationEnabled) {
      _simulationTransport.register(
        wsSimWatchDevice(state: _simState),
      );
    }
    _subscriptions.add(_scanner.results.listen((advertisements) {
      if (_devices.isClosed) return;
      if (config.simulationExclusive) return;
      final list = <WSScanDevice>[
        if (config.simulationEnabled)
          const WSScanDevice(
            deviceMac: kWsWatchSimDeviceId,
            name: 'WS Watch Simulator',
            rssi: 0,
            isSimulated: true,
          ),
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

  final WSConfig config;
  final String? _historyDatabasePath;
  final WSHistoryStore? _injectedHistoryStore;
  final WatchBleScanner _scanner;
  final WatchBleTransport _bleTransport;
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

  Future<void> initialize() async {
    _checkNotDisposed();
    if (_initialized) {
      throw StateError('WSWatch has already been initialized.');
    }
    _historyStore = _injectedHistoryStore ??
        await WSHistoryStore.open(databasePath: _historyDatabasePath);
    _initialized = true;
  }

  WSHistoryStore get historyStore {
    _checkNotDisposed();
    final store = _historyStore;
    if (!_initialized || store == null) {
      throw StateError('WSWatch must be initialized before using historyStore.');
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
      _devices.add([
        const WSScanDevice(
          deviceMac: kWsWatchSimDeviceId,
          name: 'WS Watch Simulator',
          rssi: 0,
          isSimulated: true,
        ),
      ]);
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

  /// Opens a session to a device id from [scanResults]. Transport backend is
  /// implied by [config.transportMode] and the id (simulator uses
  /// [kWsWatchSimDeviceId]); callers do not pass transport at connect time.
  WSWatchSession createSession(String deviceMac) {
    _checkNotDisposed();
    if (!_initialized) {
      throw StateError('WSWatch must be initialized before createSession.');
    }
    final sim = deviceMac == kWsWatchSimDeviceId;
    final transport = sim ? _simulationTransport : _bleTransport;
    return WSWatchSession(
      connection: transport.createConnection(
        WatchDeviceTarget(
          transportId: sim ? 'simulation' : 'ble',
          deviceId: deviceMac,
        ),
      ),
      historyStore: historyStore,
      config: config.session,
      linkConfig: config.link,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _scanner.dispose();
    if (_injectedHistoryStore == null) {
      await _historyStore?.dispose();
    }
    _historyStore = null;
    _initialized = false;
    await _devices.close();
    await _errors.close();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('WSWatch has been disposed');
  }
}
