import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_demo_example/main.dart' as app;

void main() {
  testWidgets('main starts the demo app', (tester) async {
    app.main();
    await tester.pump();

    expect(find.byType(WSWatchDemoApp), findsOneWidget);
    expect(find.byType(WSWatchDemoHome), findsOneWidget);
  });
}
