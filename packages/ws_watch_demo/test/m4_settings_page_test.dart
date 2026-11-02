import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';

Future<void> drain(WidgetTester tester) async {
  // Stream cancellation futures can cross the real/fake async zone boundary.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  testWidgets(
      'M4 UI writes time/language/full format and preserves fields with convenience setters',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final device = SimWatchState();
    final watch = runZoned(
        () => WSWatch(config: const WSConfig(simulationEnabled: true)),
        zoneValues: {
          wsEnvironmentZoneKey: WSConnectionEnvironment(
              openTransport: (_, c) =>
                  WSConnectionEnvironment.openSimulator(c, device),
              openStore: (_) async => _Store())
        });
    await tester.pumpWidget(MaterialApp(home: M4SettingsPage(watch: watch)));
    expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '读取语言'))
            .onPressed,
        isNull);
    await tester.tap(find.text('连接 Simulator'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await drain(tester);
    expect(find.text('当前状态：ready'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<WSLanguage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英文 (0x00)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入语言'));
    await drain(tester);
    expect(device.language, 0);
    await tester.tap(find.text('读取语言'));
    await drain(tester);
    expect(find.textContaining('最近语言观测：英文'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2026-02-30 16:52:00');
    await tester.tap(find.text('写入指定时间'));
    await drain(tester);
    expect(find.textContaining('invalid wall-clock calendar fields'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), '2026-10-10 16:52:00');
    await tester.tap(find.text('写入指定时间'));
    await drain(tester);
    expect(device.timeBytes, [0x6a, 0xca, 0x6d, 0x30]);
    expect(find.textContaining('最近时间通知：2026-10-10 16:52:00'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<WSHourSystem>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 小时制 (0x01)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入完整格式'));
    await drain(tester);
    expect(device.displayFormat, [1, 0, 0, 0]);
    device.displayFormat = Uint8List.fromList([0, 0xfe, 0, 0xfd]);
    await tester.tap(find.text('读取显示格式'));
    await drain(tester);
    expect(find.text('本次完整写入 4B：00 fe 00 fd'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<WSHourSystem>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 小时制 (0x01)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅改时制'));
    await drain(tester);
    expect(device.displayFormat, [1, 0xfe, 0, 0xfd]);
    await tester.tap(find.byType(DropdownButton<WSDistanceUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英制 (0x01)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('并发修改时制与距离'));
    await drain(tester);
    expect(device.displayFormat, [1, 0xfe, 1, 0xfd]);
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
    expect(watch.isDisposed,
        isFalse); // Shared M3 session remains owned by its caller.
    var disposed = false;
    unawaited(watch.dispose().then((_) => disposed = true));
    await drain(tester);
    expect(disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home exposes the M4 acceptance entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WSWatchDemoHome()));
    expect(find.text('M4 设置'), findsOneWidget);
    await tester.tap(find.text('M4 设置'));
    await tester.pumpAndSettle();
    expect(find.byType(M4SettingsPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });
}

class _Store implements WSDeviceStore {
  @override
  Future<String> defaultUserId(String id) async => 'm4-ui';
  @override
  Future<void> rememberUserId(String id, String user) async {}
  @override
  Future<void> saveReady(
      String id, String user, WSDeviceInfo info, WSCapabilities caps) async {}
  @override
  Future<void> close() async {}
}
