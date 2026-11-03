import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';
import '../transport/byte_transport_adapter.dart';

const kWsWatchSimDeviceId = 'ws-watch-sim';

/// WS compatibility adapter; the memory wire lives in its own package.
class SimWatchSession extends WSByteTransportAdapter {
  SimWatchSession(WatchSimulationConnection super.connection);

  WatchSimulationConnection get _wire =>
      connection as WatchSimulationConnection;

  static (SimWatchSession, SimWatchSession) pair({int mtu = 247}) {
    // This legacy WS test helper retains its BLE-shaped option.
    RangeError.checkValueInInterval(mtu, 23, 517, 'mtu');
    final (host, peer) = WatchSimulationConnection.pair(
        target: WatchDeviceTarget(
            transportId: 'simulation', deviceId: kWsWatchSimDeviceId),
        maxWriteLength: mtu - 3);
    return (SimWatchSession(host), SimWatchSession(peer));
  }

  Future<void> Function(Uint8List)? get interceptWrite => _wire.interceptWrite;
  set interceptWrite(Future<void> Function(Uint8List)? hook) =>
      _wire.interceptWrite = hook;

  void deliver(Uint8List bytes) => _wire.deliver(bytes);
}
