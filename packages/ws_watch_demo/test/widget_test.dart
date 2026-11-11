import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';

void main() {
  testWidgets('WS demo home renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WSWatchLabAppRoot()),
    );
    expect(find.text('WS SDK Demo'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
  });
}
