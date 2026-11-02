import '../config.dart';
import '../debug/debug_api.dart';
import '../session/session.dart';
import '../simulation/sim_watch_device.dart';
import '../simulation/simulation_runtime.dart';

/// Prepared-session harness for M2 tests/tooling; not a public connect API.
/// M3 will own authentication, readiness and attaching watch.debug.
class WSPreparedSimulation {
  WSPreparedSimulation._(this._runtime, this.debug)
      : session = _runtime.session,
        device = _runtime.device;

  final WSSimulationRuntime _runtime;
  final WSSession session;
  final SimWatchDevice device;
  final WSDebugController debug;

  Future<void>? _disposing;

  static Future<WSPreparedSimulation> open({
    required WSConfig config,
    int mtu = 247,
  }) async {
    final runtime = await WSSimulationRuntime.open(config: config, mtu: mtu);
    final debug = WSDebugController()
      ..attach(runtime.session, allowRaw: () => !runtime.session.isClosed);
    return WSPreparedSimulation._(runtime, debug);
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    await debug.dispose();
    await _runtime.dispose();
  }
}
