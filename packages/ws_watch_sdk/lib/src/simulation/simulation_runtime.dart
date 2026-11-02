import '../config.dart';
import '../link/link.dart';
import '../protocol/cmd_02_settings.dart';
import '../session/session.dart';
import 'sim_watch_device.dart';
import 'sim_watch_session.dart';

/// In-memory transport + session for M2 tests and the simulation lab UI.
class WSSimulationRuntime {
  WSSimulationRuntime._(
    this.host,
    this.peer,
    this.session,
    this.device,
  );

  final SimWatchSession host;
  final SimWatchSession peer;
  final WSSession session;
  final SimWatchDevice device;

  static int _linkGeneration = 0;

  static Future<WSSimulationRuntime> open({
    required WSConfig config,
    int mtu = 247,
  }) async {
    if (!config.simulationEnabled) {
      throw StateError('simulation is disabled');
    }
    config.link.validate();
    config.session.validate();
    final (host, peer) = SimWatchSession.pair(mtu: mtu);
    try {
      await host.prepare();
      await peer.prepare();
      final device = SimWatchDevice(peer, linkConfig: config.link);
      final link = WSLink(
        host,
        config: config.link,
        generation: ++_linkGeneration,
      );
      final session = WSSession(
        link,
        WSSettingsProtocol.registry(),
        config: config.session,
      );
      return WSSimulationRuntime._(host, peer, session, device);
    } catch (error) {
      await host.dispose();
      await peer.dispose();
      rethrow;
    }
  }

  Future<void> dispose() async {
    await session.dispose();
    await device.dispose();
    await host.dispose();
    await peer.dispose();
  }
}
