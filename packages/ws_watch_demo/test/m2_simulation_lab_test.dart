import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';

void main() {
  testWidgets('M2 lab page opens and runs language round-trip', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: M2SimulationLabPage()));
    expect(find.widgetWithText(AppBar, 'M2 模拟实验室'), findsOneWidget);

    await tester.tap(find.text('打开实验室'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('设置语言'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('读取语言'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('读取语言：'), findsOneWidget);
  });
}
