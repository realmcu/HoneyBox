import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_demo_example/main.dart' as app;

Future<void> until(WidgetTester tester, Finder finder) async {
  await tester.pump();
  for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('standalone: M3 connect, raw sheet, M5 sync', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('M3 扫描与连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接 Simulator'));
    await until(tester, find.text('当前状态：ready'));
    await tester.tap(find.byKey(const Key('ws-debug-tools')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raw-sheet-title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('raw-send')));
    await until(tester, find.textContaining('成功 · 回应操作数据：'));
    await tester.enterText(
        find.byKey(const Key('raw-l2-request')), '02 00 03 00 02 00 07');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('raw-send')));
    await until(tester, find.textContaining('成功 · L1 ACK'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('M5 历史数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始单类型同步'));
    await until(tester, find.textContaining('结果：completed · 确认 acked'));
    await tester.binding.setSurfaceSize(null);
  });
}
