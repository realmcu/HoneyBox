import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/jw_device_page.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

void main() {
  testWidgets(
      'manual console exposes eight categories without sending commands on open at small phone size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('jw_console_');
      try {
        return await JwIdentityStore(File('${dir.path}/id.json'))
            .loadOrCreate();
      } finally {
        await dir.delete(recursive: true);
      }
    }))!;
    final transport = FakeJwTransport();
    installJwDeviceScript(transport);
    final notifier = JwDeviceNotifier(
        repository: JwDeviceRepository(
            session: JwSession(transport),
            identityStore: _Identity(identity),
            transport: transport));
    await notifier.initialize();
    addTearDown(transport.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [jwDeviceProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!),
            home: const JwDevicePage(deviceId: 'test', deviceName: 'S200'))));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('jw-test-console'));
    expect(button, findsOneWidget);
    await tester.scrollUntilVisible(button, 250);
    final baseline = transport.writes.length;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('SDK 手动测试'), findsOneWidget);
    expect(transport.writes.length, baseline);
    await tester.tap(find.byKey(const Key('jw-console-category')));
    await tester.pumpAndSettle();
    for (final label in [
      '设备与基础',
      '健康测量',
      '自动监测',
      '提醒与闹钟',
      '运动',
      '资料与目标',
      '辅助控制',
      '历史数据'
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

class _Identity extends JwIdentityStore {
  final JwIdentityRecord record;
  _Identity(this.record) : super(File('unused'));
  @override
  Future<JwIdentityRecord> loadOrCreate() async => record;
}
