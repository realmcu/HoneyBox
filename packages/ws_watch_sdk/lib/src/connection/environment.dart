import 'dart:async';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import '../transport/byte_transport_adapter.dart';
import '../config.dart';
import '../errors.dart';
import 'connection_state.dart';
import '../simulation/sim_watch_device.dart';
import '../simulation/sim_watch_session.dart';
import '../simulation/simulation_transport.dart';
import '../storage/device_store.dart';
import '../transport/connection.dart';

/// Internal dependency boundary, overridable through a zone in tests only.
final wsEnvironmentZoneKey = Object();

class WSConnectionEnvironment {
  WSConnectionEnvironment(
      {required this.openTransport,
      this.openStore = WSDriftDeviceStore.open,
      this.reconnectDelay = defaultReconnectDelay,
      DateTime Function()? now})
      : now = now ?? DateTime.now;
  final Future<WSManagedTransport> Function(String deviceId, WSConfig config)
      openTransport;
  final Future<WSDeviceStore> Function(String? path) openStore;
  final Duration Function(int attempt) reconnectDelay;
  final DateTime Function() now;
  static final simulatedDevice = SimWatchState();
  static final defaults =
      WSConnectionEnvironment(openTransport: (id, config) async {
    if (id == kWsWatchSimDeviceId) {
      if (!config.simulationEnabled) {
        throw const WSConnectException(WSConnectionState.connecting,
            WSConnectFailure.transportUnavailable, 'Simulation is disabled');
      }
      return openSimulator(config, simulatedDevice);
    }
    final ble = WatchBleTransport(
        config: WatchBleConfig(
            profile: WatchBleProfile(
                service: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
                tx: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
                rx: '6e400003-b5a3-f393-e0a9-e50e24dcca9e'),
            connectTimeout: config.connectTimeouts.discovering));
    return WSManagedTransport(WSByteTransportAdapter(ble.createConnection(
        WatchDeviceTarget(transportId: 'ble', deviceId: id))));
  });
  static WSConnectionEnvironment get current =>
      Zone.current[wsEnvironmentZoneKey] as WSConnectionEnvironment? ??
      defaults;
  static Duration defaultReconnectDelay(int attempt) =>
      Duration(seconds: attempt >= 5 ? 60 : 2 << attempt);
  static Future<WSManagedTransport> openSimulator(
      WSConfig config, SimWatchState state,
      {int mtu = 247}) async {
    final simulation =
        WSSimulatedConnection.create(config: config, state: state, mtu: mtu);
    return WSManagedTransport(simulation.host);
  }
}

class WSManagedTransport {
  WSManagedTransport(this.connection, {Future<void> Function()? release})
      : _release = release;
  final WSTransportConnection connection;
  final Future<void> Function()? _release;
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    try {
      await connection.dispose();
    } finally {
      await _release?.call();
    }
  }
}
