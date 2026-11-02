import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';

void main() {
  testWidgets('M3 UI scans, binds, shows ready info and unbinds',
      (tester) async {
    final device = SimWatchState();
    final environment = WSConnectionEnvironment(
        openTransport: (_, config) =>
            WSConnectionEnvironment.openSimulator(config, device),
        openStore: (_) async => _Store());
    await runZoned(() async {
      await tester.pumpWidget(const MaterialApp(home: M3ConnectionPage()));
      await tester.tap(find.text('扫描设备'));
      await tester.pump();
      expect(find.text('WS Watch Simulator'), findsOneWidget);
      await tester.tap(find.text('WS Watch Simulator'));
      await tester.pump();
      expect(find.text('当前状态：awaitingConfirm'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('当前状态：ready'), findsOneWidget);
      expect(device.boundUserId, 'demo-test-user');
      await tester.scrollUntilVisible(find.text('设备信息'), 400,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('WS2026000001'), findsOneWidget);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.tap(find.text('解绑'));
      // Stream cancellation futures may cross Flutter's real/fake async zones.
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(device.boundUserId, isNull);
      await tester.scrollUntilVisible(find.byKey(const Key('m3-state')), -400,
          scrollable: find.byType(Scrollable).first);
      expect(tester.widget<Text>(find.byKey(const Key('m3-state'))).data,
          '当前状态：disconnected');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, zoneValues: {wsEnvironmentZoneKey: environment});
  });
}

class _Store implements WSDeviceStore {
  @override
  Future<void> rememberUserId(String deviceId, String userId) async {}
  @override
  Future<String> defaultUserId(String deviceId) async => 'demo-test-user';
  @override
  Future<void> saveReady(String deviceId, String userId, WSDeviceInfo info,
      WSCapabilities capabilities) async {}
  @override
  Future<void> close() async {}
}
