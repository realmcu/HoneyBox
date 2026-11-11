import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ws_watch_demo/ws_demo_controller.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sim connect bind sync smoke', (tester) async {
    final controller = WSDemoController();
    addTearDown(controller.disposeAll);

    await controller.connectSim();
    expect(controller.phase, WSSessionPhase.ready);

    await controller.syncHealth();
    expect(controller.heartRateCount, 2);
    expect(controller.activityCount, 2);
    await controller.readLanguage();
    expect(controller.languageCode, isNotNull);
  });
}
