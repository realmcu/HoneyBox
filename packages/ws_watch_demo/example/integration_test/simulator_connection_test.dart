import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'production simulator and native persistence connect and reconnect',
      (tester) async {
    await tester.runAsync(() async {
      final watch = WSWatch(config: const WSConfig(simulationEnabled: true));
      final readyChanges = watch.stateChanges
          .where((change) => change.current == WSConnectionState.ready)
          .take(2)
          .toList();
      try {
        await watch
            .connect(kWsWatchSimDeviceId)
            .timeout(const Duration(seconds: 25));
        expect(watch.state, WSConnectionState.ready);
        await watch.settings.setTime();
        await watch.settings.getDisplayFormat();
        await watch.disconnect();
        await watch
            .connect(kWsWatchSimDeviceId)
            .timeout(const Duration(seconds: 25));
        expect(watch.state, WSConnectionState.ready);
        expect(await readyChanges.timeout(const Duration(seconds: 5)),
            hasLength(2));
      } finally {
        await watch.dispose();
      }
    });
  });
}
