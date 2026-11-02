import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  testWidgets('home shows SDK version and disconnected state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WSWatchDemoHome()));

    expect(find.widgetWithText(AppBar, 'WS Watch'), findsOneWidget);
    expect(find.text(wsWatchSdkVersion), findsOneWidget);
    expect(find.text(WSConnectionState.disconnected.name), findsOneWidget);
  });

  testWidgets('standalone app renders the home page', (tester) async {
    await tester.pumpWidget(const WSWatchDemoApp());

    expect(find.byType(WSWatchDemoHome), findsOneWidget);
  });
}
