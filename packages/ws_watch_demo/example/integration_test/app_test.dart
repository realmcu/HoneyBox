import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_demo_example/main.dart' as app;
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo app launches on the host platform', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.byType(WSWatchDemoHome), findsOneWidget);
    expect(find.text(wsWatchSdkVersion), findsOneWidget);
  });
}
