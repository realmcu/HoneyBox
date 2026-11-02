import 'dart:async';
import '../config.dart';
import '../errors.dart';
import 'connection_state.dart';
import '../simulation/sim_watch_device.dart';
import '../simulation/sim_watch_session.dart';
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
    if (id != kWsWatchSimDeviceId || !config.simulationEnabled) {
      throw const WSConnectException(
          WSConnectionState.connecting,
          WSConnectFailure.transportUnavailable,
          'M3 supports the explicitly enabled simulator; BLE UART connection is scheduled for M7');
    }
    return openSimulator(config, simulatedDevice);
  });
  static WSConnectionEnvironment get current =>
      Zone.current[wsEnvironmentZoneKey] as WSConnectionEnvironment? ??
      defaults;
  static Duration defaultReconnectDelay(int attempt) =>
      Duration(seconds: attempt >= 5 ? 60 : 2 << attempt);
  static Future<WSManagedTransport> openSimulator(
      WSConfig config, SimWatchState state,
      {int mtu = 247}) async {
    final (host, peer) = SimWatchSession.pair(mtu: mtu);
    await peer.prepare();
    final device = SimWatchDevice(peer, linkConfig: config.link, state: state);
    return WSManagedTransport(host, release: () async {
      await device.dispose();
      await peer.dispose();
    });
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
