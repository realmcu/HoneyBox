import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ws_watch_demo/src/ws_demo_controller.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('two simulated watches bind and sync independently',
      (tester) async {
    final controller = WSDemoController();
    try {
      await controller.initialize();
      for (final id in [kWsWatchSimDeviceId, kWsWatchSimDeviceId2]) {
        expect(
            await controller.connect(WSScanDevice(
                deviceMac: id, name: id, rssi: 0, isSimulated: true)),
            isTrue);
        await controller.bindFirstTime('123456', confirmed: true);
      }
      final sessions = controller.attachedSessions;
      expect(sessions, hasLength(2));
      await Future.wait([
        for (final entry in sessions)
          controller.syncFor(entry.session).start(entry.session)
      ]);
      await controller.disconnectDevice(kWsWatchSimDeviceId);
      expect(controller.attachedSessions.single.state.isReady, isTrue);
    } finally {
      await controller.shutdown();
      controller.dispose();
    }
  });
}
