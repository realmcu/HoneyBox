import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/jw_device_page.dart';
import 'package:honeybox/pages/watch/jw_observation_panel.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import 'package:honeybox/theme/app_theme.dart';
import 'package:flutter/rendering.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

void main() {
  Future<(FakeJwTransport, JwDeviceNotifier)> setup(WidgetTester tester,
      {int login = 0,
      bool corrupt = false,
      StateProvider<JwDeviceNotifier?>? connection}) async {
    final identity = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('jw_page_');
      try {
        return await JwIdentityStore(File('${dir.path}/id.json'))
            .loadOrCreate();
      } finally {
        await dir.delete(recursive: true);
      }
    }))!;
    final t = FakeJwTransport();
    installJwDeviceScript(t, loginResult: login);
    final n = JwDeviceNotifier(
        repository: JwDeviceRepository(
            session: JwSession(t),
            identityStore: _PageIdentityStore(identity, corrupt),
            transport: t));
    await n.initialize();
    addTearDown(t.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          jwDeviceProvider.overrideWith(
              (ref) => connection == null ? n : ref.watch(connection) ?? n)
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const JwDevicePage(deviceId: 'test', deviceName: 'S200'))));
    await tester.pumpAndSettle();
    return (t, n);
  }

  testWidgets(
      'delayed BLE reply keeps observation state through busy frame and repeated click',
      (tester) async {
    final (t, n) = await setup(tester);
    final original = t.onWrite!;
    JwFrame? held;
    var released = false;
    var alarmQueries = 0;
    t.onWrite = (bytes) {
      final frame = JwFrameDecoder().add(bytes).single;
      if (frame.ack) return;
      final m = JwCodec.decodeL2(frame.payload);
      final tag = '${m.command}/${m.fields.single.key}';
      if (tag == '2/3') {
        alarmQueries++;
        if (!released) {
          held = frame;
          return;
        }
      }
      final rep = <String, (int, int, List<int>)>{
        '2/3': (2, 4, []),
        '2/59': (5, 23, [15, 61, 107, 254]),
        '5/45': (5, 46, [3]),
        '5/92': (5, 93, [0, 0, 255]),
      }[tag];
      if (rep != null) {
        t.emitAck(frame.seq);
        t.emitMessage(rep.$1, rep.$2, Uint8List.fromList(rep.$3));
        return;
      }
      original(bytes);
    };
    final button = find.byKey(const Key('jw-remaining-observe'));
    await tester.scrollUntilVisible(button, 250);
    await tester.ensureVisible(button);
    final stateBefore = tester.state(find.byType(JwObservationPanel));
    await tester.tap(button);
    await tester.pump();
    expect(held, isNotNull);
    expect(n.state.operationInProgress, true);
    expect(tester.state(find.byType(JwObservationPanel)), same(stateBefore),
        reason:
            'Busy progress insertion must not dispose the async observation panel');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(alarmQueries, 1);
    released = true;
    t.emitAck(held!.seq);
    t.emitMessage(2, 4, Uint8List(0));
    await tester.pumpAndSettle();
    expect(find.text('支持运动：21种'), findsOneWidget);
    expect(find.text('闹钟：0个'), findsOneWidget);
    expect(find.text('运动状态：空闲'), findsOneWidget);
    expect(find.text('血氧测量：设备报告可用'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('observation pending disconnect ignores late reply',
      (tester) async {
    final (t, n) = await setup(tester);
    final script = _ObservationReplies(t, holdAlarm: true);
    final button = find.byKey(const Key('jw-remaining-observe'));
    await tester.scrollUntilVisible(button, 250);
    await tester.tap(button);
    await tester.pump();
    expect(script.pending, isNotNull);
    t.emitDisconnect();
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.text('支持运动：21种'), findsNothing);
    script.releaseAlarm();
    await tester.pumpAndSettle();
    expect(script.otherObservationQueries, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'closing observation while pending causes no disposed ref or later queries',
      (tester) async {
    final (t, n) = await setup(tester);
    final script = _ObservationReplies(t, holdAlarm: true);
    final button = find.byKey(const Key('jw-remaining-observe'));
    await tester.scrollUntilVisible(button, 250);
    await tester.tap(button);
    await tester.pump();
    expect(script.pending, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    script.releaseAlarm();
    await tester.pumpAndSettle();
    expect(script.otherObservationQueries, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'reconnect hides prior repository report before fresh observation',
      (tester) async {
    final connection = StateProvider<JwDeviceNotifier?>((ref) => null);
    final (t, n) = await setup(tester, connection: connection);
    _ObservationReplies(t);
    final button = find.byKey(const Key('jw-remaining-observe'));
    await tester.scrollUntilVisible(button, 250);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('支持运动：21种'), findsOneWidget);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(JwDevicePage)));
    t.emitDisconnect();
    await tester.pumpAndSettle();
    expect(find.text('支持运动：21种'), findsNothing);
    final nextTransport = FakeJwTransport();
    installJwDeviceScript(nextTransport);
    final next = JwDeviceNotifier(
        repository: JwDeviceRepository(
            session: JwSession(nextTransport),
            identityStore: n.repository!.identityStore,
            transport: nextTransport));
    await next.initialize();
    addTearDown(nextTransport.dispose);
    _ObservationReplies(nextTransport,
        alarmBytes: [0x69, 0x42, 0x70, 0x38, 0x7f], sportMask: [0, 0, 0, 2]);
    container.read(connection.notifier).state = next;
    await tester.pumpAndSettle();
    expect(find.text('支持运动：21种'), findsNothing,
        reason:
            'An old device/session report must not reappear after repository replacement');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('闹钟：1个'), findsOneWidget);
    expect(find.text('支持运动：1种'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('phone-width observation remains readable with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (transport, _) = await setup(tester);
    _ObservationReplies(transport);
    final button = find.byKey(const Key('jw-remaining-observe'));
    await tester.scrollUntilVisible(button, 200);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('支持运动：21种'), findsOneWidget);
    expect(find.text('血氧测量：设备报告可用'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'new observation panel calls SDK and clears device report after disconnect',
      (tester) async {
    final (t, n) = await setup(tester);
    final original = t.onWrite!;
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (f.ack) return;
      final m = JwCodec.decodeL2(f.payload);
      final reps = <String, (int, int, List<int>)>{
        '2/3': (2, 4, []),
        '2/59': (5, 23, [15, 61, 107, 254]),
        '5/45': (5, 46, [3]),
        '5/92': (5, 93, [0, 0, 255])
      };
      final rep = reps['${m.command}/${m.fields.single.key}'];
      if (rep != null) {
        t.emitAck(f.seq);
        t.emitMessage(rep.$1, rep.$2, Uint8List.fromList(rep.$3));
        return;
      }
      original(bytes);
    };
    final button = find.byKey(const Key('jw-remaining-observe'));
    await tester.scrollUntilVisible(button, 250);
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('支持运动：21种'), findsOneWidget);
    expect(find.text('闹钟：0个'), findsOneWidget);
    expect(find.text('运动状态：空闲'), findsOneWidget);
    t.emitDisconnect();
    await tester.pumpAndSettle();
    expect(find.text('支持运动：21种'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'refused login disables writes and first bind requires explicit confirmation',
      (tester) async {
    final (t, _) = await setup(tester, login: 1);
    expect(
        tester.widget<FilledButton>(find.byKey(const Key('jw-time'))).onPressed,
        isNull);
    await tester.tap(find.byKey(const Key('jw-bind')));
    await tester.pumpAndSettle();
    expect(find.textContaining('readiness'), findsOneWidget);
    expect(
        t.sent
            .where((f) => !f.ack)
            .map((f) => JwCodec.decodeL2(f.payload))
            .where((m) => m.command == 3 && m.fields.single.key == 1),
        isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jw-bind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认首次绑定'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<FilledButton>(find.byKey(const Key('jw-time'))).onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('disconnect text contrasts with the actual app bar background',
      (tester) async {
    await setup(tester);
    final text = tester.renderObject<RenderParagraph>(find.text('断开'));
    final fg = text.text.style!.color!.computeLuminance();
    final bg = AppTheme.lightTheme.colorScheme.primary.computeLuminance();
    final ratio =
        (fg > bg ? fg + 0.05 : bg + 0.05) / (fg > bg ? bg + 0.05 : fg + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'identity failure shows readable information and disables all writes',
      (tester) async {
    await setup(tester, corrupt: true);
    expect(find.textContaining('T005'), findsOneWidget);
    expect(find.text('本地标识不可用，仅可读取'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byKey(const Key('jw-time'))).onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('jw-bind')))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'real heart values and ACK-only time status are represented honestly',
      (tester) async {
    await setup(tester);
    await tester.tap(find.byKey(const Key('jw-time')));
    await tester.pumpAndSettle();
    expect(find.text('时间请求已送达，设备时钟待验证'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('等待有效心率样本'), 200);
    await tester.pumpAndSettle();
    expect(find.text('等待有效心率样本'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('jw-language-0')))
            .child,
        isA<Text>().having((t) => t.data, 'English wire value 0', 'English'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

// Persistence is exercised by store/repository tests; widgets inject its result
// so their fake clock never waits on Windows file locks.
class _PageIdentityStore extends JwIdentityStore {
  final JwIdentityRecord identity;
  final bool unavailable;
  _PageIdentityStore(this.identity, this.unavailable)
      : super(File('unused-widget-identity'));
  @override
  Future<JwIdentityRecord> loadOrCreate() async {
    if (unavailable) {
      throw const JwIdentityException('Local identity unavailable');
    }
    return identity;
  }
}

class _ObservationReplies {
  final FakeJwTransport transport;
  final List<int> alarmBytes, sportMask;
  bool holdAlarm;
  JwFrame? pending;
  int otherObservationQueries = 0;
  _ObservationReplies(this.transport,
      {this.holdAlarm = false,
      this.alarmBytes = const [],
      this.sportMask = const [15, 61, 107, 254]}) {
    final original = transport.onWrite!;
    transport.onWrite = (bytes) {
      final frame = JwFrameDecoder().add(bytes).single;
      if (frame.ack) return;
      final message = JwCodec.decodeL2(frame.payload);
      final tag = '${message.command}/${message.fields.single.key}';
      if (tag == '2/3' && holdAlarm) {
        pending = frame;
        return;
      }
      final reply = <String, (int, int, List<int>)>{
        '2/3': (2, 4, alarmBytes),
        '2/59': (5, 23, sportMask),
        '5/45': (5, 46, [3]),
        '5/92': (5, 93, [0, 0, 255])
      }[tag];
      if (reply != null) {
        if (tag != '2/3') otherObservationQueries++;
        transport.emitAck(frame.seq);
        transport.emitMessage(reply.$1, reply.$2, Uint8List.fromList(reply.$3));
        return;
      }
      original(bytes);
    };
  }
  void releaseAlarm() {
    holdAlarm = false;
    if (pending != null) {
      transport.emitAck(pending!.seq);
      transport.emitMessage(2, 4, Uint8List.fromList(alarmBytes));
      pending = null;
    }
  }
}
