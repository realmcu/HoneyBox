import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';

void main() {
  testWidgets('shows four stable navigation destinations before connection',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    expect(find.byKey(const Key('jw.demo.tab.home')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.features')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.scenarios')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.device')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.session_status')), findsOneWidget);
  });

  testWidgets('keeps features in their own tab', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    await tester.tap(find.byKey(const Key('jw.demo.tab.features')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jw.demo.page.features')), findsOneWidget);
    expect(
        find.byKey(const Key('jw.demo.feature.measurements')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.feature.history')), findsOneWidget);
  });

  testWidgets('opens API guidance in a bottom sheet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    await tester.tap(find.byKey(const Key('jw.demo.tab.features')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jw.demo.feature.measurements')));
    await tester.pumpAndSettle();

    expect(find.text('公开 API 示例'), findsOneWidget);
    expect(find.textContaining('startHeartRate'), findsOneWidget);
  });
}
