import 'package:watch_transport_simulation/watch_transport_simulation.dart';
import '../config.dart';
import 'sim_watch_device.dart';
import 'sim_watch_session.dart';

/// WS registers device behavior; the generic transport has no WS default.
class WSSimulatedConnection {
  WSSimulatedConnection._();
  late final SimWatchSession host;
  SimWatchSession? _peer;
  SimWatchDevice? _device;

  SimWatchSession get peer =>
      _peer ?? (throw StateError('Simulator is not attached'));
  SimWatchDevice get device =>
      _device ?? (throw StateError('Simulator is not attached'));

  static WSSimulatedConnection create({
    required WSConfig config,
    SimWatchState? state,
    int mtu = 247,
  }) {
    RangeError.checkValueInInterval(mtu, 23, 517, 'mtu');
    final result = WSSimulatedConnection._();
    final transport = WatchSimulationTransport();
    final definition = WatchSimulationDevice(
        id: kWsWatchSimDeviceId,
        name: 'WS Watch Simulator',
        maxWriteLength: mtu - 3,
        connectTimeout: config.connectTimeouts.discovering,
        attach: (wire) {
          final peer = SimWatchSession(wire);
          final device =
              SimWatchDevice(peer, linkConfig: config.link, state: state);
          result._peer = peer;
          result._device = device;
          return WatchSimulationDeviceSession(dispose: device.dispose);
        });
    transport.register(definition);
    result.host =
        SimWatchSession(transport.createConnection(definition.target));
    return result;
  }
}
