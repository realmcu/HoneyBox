import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';

Future<void> drainM5(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
      'M5 UI syncs, dedups, queries disconnected and preserves shared ownership',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    final device = SimWatchState()
      ..confirmationDelay = Duration.zero
      ..historyDelay = Duration.zero;
    final watch = runZoned(
        () => WSWatch(config: const WSConfig(simulationEnabled: true)),
        zoneValues: {
          wsEnvironmentZoneKey: WSConnectionEnvironment(
              openStore: (_) async => store,
              openTransport: (_, c) =>
                  WSConnectionEnvironment.openSimulator(c, device))
        });
    await tester.pumpWidget(MaterialApp(home: M5HistoryPage(watch: watch)));
    await tester.tap(find.text('连接 Simulator'));
    await drainM5(tester);
    expect(find.text('当前状态：ready'), findsOneWidget);
    await tester.tap(find.text('开始单类型同步'));
    await drainM5(tester);
    expect(find.textContaining('结果：completed · 确认 acked'), findsOneWidget);
    expect(find.text('本地记录：2 条'), findsOneWidget);
    expect(find.textContaining('新增 2 / 重复 0'), findsOneWidget);
    await tester.tap(find.text('开始单类型同步'));
    await drainM5(tester);
    expect(find.textContaining('新增 0 / 重复 2'), findsOneWidget);
    await tester.tap(find.text('断开连接'));
    await drainM5(tester);
    await tester.tap(find.text('查询记录与日志'));
    await drainM5(tester);
    expect(find.text('本地记录：2 条'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await drainM5(tester);
    expect(watch.isDisposed, isFalse);
    var disposed = false;
    unawaited(watch
        .dispose()
        .then((_) => store.close())
        .then((_) => disposed = true));
    await drainM5(tester);
    expect(disposed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('home exposes M5 acceptance page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WSWatchDemoHome()));
    await tester.scrollUntilVisible(find.text('M5 历史数据'), 200);
    await tester.tap(find.text('M5 历史数据'));
    await tester.pumpAndSettle();
    expect(find.byType(M5HistoryPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await drainM5(tester);
    expect(tester.takeException(), isNull);
  });
}
