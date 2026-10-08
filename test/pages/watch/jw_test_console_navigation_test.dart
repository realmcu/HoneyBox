import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/jw_test_console.dart';
import 'package:honeybox/pages/watch/jw_history_page.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

void main() {
  testWidgets(
      'cursor reset confirmation cancel emits zero TX and confirmed reset sends only all-type rewind',
      (tester) async {
    final (t, _) = await _setup(tester);
    await _category(tester, '历史数据');
    final reset = find.byKey(const Key('jw-console-history-reset'));
    await tester.ensureVisible(reset);
    final count = t.writes.length;
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.textContaining('只重置设备读取位置'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(t.writes.length, count);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置全部游标'));
    await tester.pumpAndSettle();
    final commands = t.writes
        .skip(count)
        .map((w) => JwFrameDecoder().add(w).single)
        .where((f) => !f.ack)
        .map((f) => JwCodec.decodeL2(f.payload))
        .toList();
    expect(commands.length, 1);
    expect(commands.single.command, 5);
    expect(commands.single.fields.single.key, 0xfa);
    expect(commands.single.fields.single.value, isEmpty);
    expect(find.byKey(const Key('jw-console-result-history-reset')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'device switch while old query is pending discards old result and operation state',
      (tester) async {
    final connection = StateProvider<JwDeviceNotifier?>((ref) => null);
    final (t, n) = await _setup(tester, connection: connection);
    final original = t.onWrite!;
    JwFrame? pending;
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (!f.ack && JwCodec.decodeL2(f.payload).fields.single.key == 0x4f) {
        pending = f;
        return;
      }
      original(bytes);
    };
    final query = find.byKey(const Key('jw-console-run-language-read'));
    await tester.ensureVisible(query);
    await tester.tap(query);
    await tester.pump();
    expect(pending, isNotNull);
    final nextT = FakeJwTransport();
    installJwDeviceScript(nextT, language: 2);
    final next = JwDeviceNotifier(
        repository: JwDeviceRepository(
            session: JwSession(nextT),
            identityStore: n.repository!.identityStore,
            transport: nextT));
    await next.initialize();
    addTearDown(nextT.dispose);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(JwSdkTestConsole)));
    container.read(connection.notifier).state = next;
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('jw-console-result-language-read')), findsNothing);
    final nextQuery = find.byKey(const Key('jw-console-run-language-read'));
    await tester.ensureVisible(nextQuery);
    expect(tester.widget<OutlinedButton>(nextQuery).onPressed, isNotNull);
    t.emitAck(pending!.seq);
    t.emitMessage(2, 0x50, Uint8List.fromList([0]));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('jw-console-result-language-read')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(nextQuery);
    await tester.pumpAndSettle();
    expect(find.textContaining('当前语言=2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'history browse uses switched repository platform key when serial is absent',
      (tester) async {
    final connection = StateProvider<JwDeviceNotifier?>((ref) => null);
    final (_, n) = await _setup(tester, connection: connection);
    final nextT = FakeJwTransport();
    installJwDeviceScript(nextT);
    nextT.readValues['2a25'] = Uint8List(0);
    final next = JwDeviceNotifier(
        repository: JwDeviceRepository(
            session: JwSession(nextT),
            identityStore: n.repository!.identityStore,
            transport: nextT,
            platformDeviceKey: 'device-B'));
    await next.initialize();
    addTearDown(nextT.dispose);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(JwSdkTestConsole)));
    container.read(connection.notifier).state = next;
    await tester.pumpAndSettle();
    await _category(tester, '历史数据');
    final browse = find.text('查看已保存记录');
    await tester.ensureVisible(browse);
    await tester.tap(browse);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<JwHistoryRecordsPage>(find.byType(JwHistoryRecordsPage))
            .deviceKey,
        'jw:device-B');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'profile controls and error remain reachable with small screen and keyboard inset',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final (t, _) = await _setup(tester, phoneScale: true);
    await _category(tester, '资料与目标');
    final height = find.byKey(const Key('jw-console-profile-height'));
    await tester.ensureVisible(height);
    await tester.tap(height);
    await tester.enterText(height, '256');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, true);
    final run = find.byKey(const Key('jw-console-run-profile'));
    await tester.ensureVisible(run);
    await tester.pumpAndSettle();
    final count = t.writes.length;
    await tester.tap(run);
    await tester.pumpAndSettle();
    expect(t.writes.length, count);
    final result = find.byKey(const Key('jw-console-result-profile'));
    await tester.ensureVisible(result);
    expect(result, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'profile invalid boundary submitted from form produces visible failure with zero TX',
      (tester) async {
    final (t, _) = await _setup(tester);
    await _category(tester, '资料与目标');
    await tester.enterText(
        find.byKey(const Key('jw-console-profile-age')), '40');
    await tester.enterText(
        find.byKey(const Key('jw-console-profile-height')), '256');
    await tester.enterText(
        find.byKey(const Key('jw-console-profile-weight')), '65');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final run = find.byKey(const Key('jw-console-run-profile'));
    await tester.ensureVisible(run);
    await tester.pumpAndSettle();
    final count = t.writes.length;
    await tester.tap(run);
    await tester.pumpAndSettle();
    expect(t.writes.length, count);
    expect(find.byKey(const Key('jw-console-result-profile')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

Future<void> _category(WidgetTester tester, String label) async {
  final category = find.byKey(const Key('jw-console-category'));
  await tester.ensureVisible(category);
  await tester.tap(category);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<(FakeJwTransport, JwDeviceNotifier)> _setup(WidgetTester tester,
    {StateProvider<JwDeviceNotifier?>? connection,
    bool phoneScale = false}) async {
  final identity = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('console_nav_');
    try {
      return await JwIdentityStore(File('${dir.path}/id')).loadOrCreate();
    } finally {
      await dir.delete(recursive: true);
    }
  }))!;
  final t = FakeJwTransport();
  installJwDeviceScript(t);
  final n = JwDeviceNotifier(
      repository: JwDeviceRepository(
          session: JwSession(t),
          identityStore: _Identity(identity),
          transport: t));
  await n.initialize();
  addTearDown(t.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        jwHistoryStoreProvider.overrideWith(
            (ref) async => throw StateError('Test history store unavailable')),
        jwDeviceProvider.overrideWith(
            (ref) => connection == null ? n : ref.watch(connection) ?? n)
      ],
      child: MaterialApp(
          builder: phoneScale
              ? (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!)
              : null,
          home: const JwSdkTestConsole(deviceId: 'test'))));
  await tester.pumpAndSettle();
  return (t, n);
}

class _Identity extends JwIdentityStore {
  final JwIdentityRecord record;
  _Identity(this.record) : super(File('unused'));
  @override
  Future<JwIdentityRecord> loadOrCreate() async => record;
}
