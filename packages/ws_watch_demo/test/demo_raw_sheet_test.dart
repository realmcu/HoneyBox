import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_demo/src/debug/debug_scope.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';

Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  test('l2 hex parser round-trips read-language request', () {
    final req = l2HexToRawRequest('02 00 03 00 01 01');
    expect(req.cmd, 2);
    expect(req.key, 3);
    expect(req.settingOpcode, 1);
    expect(req.data, isEmpty);
  });

  testWidgets('raw sheet read/write language on ready watch', (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    final device = SimWatchState()..confirmationDelay = Duration.zero;
    final watch = runZoned(
        () => WSWatch(config: const WSConfig(simulationEnabled: true)),
        zoneValues: {
          wsEnvironmentZoneKey: WSConnectionEnvironment(
              openStore: (_) async => store,
              openTransport: (_, c) =>
                  WSConnectionEnvironment.openSimulator(c, device))
        });
    await tester.pumpWidget(MaterialApp(
        home: DemoDebugScope(
            watch: watch,
            child: Builder(builder: (context) {
              return Scaffold(
                  body: FilledButton(
                      onPressed: () => showDemoRawDebugSheet(context,
                          watch: watch,
                          capture: DemoDebugScope.of(context)),
                      child: const Text('open')));
            }))));
    await watch.connect(kWsWatchSimDeviceId);
    await drain(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raw-sheet-title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('raw-send')));
    await drain(tester);
    expect(find.textContaining('成功 · 回应操作数据：01'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('raw-l2-request')),
        '02 00 03 00 02 00 07');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('raw-send')));
    await drain(tester);
    expect(device.language, 7);
    await tester.pumpWidget(const SizedBox());
    await watch.dispose();
    await store.close();
    expect(tester.takeException(), isNull);
  });
}
