import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/jw_test_console_catalog.dart';
import 'package:honeybox/pages/watch/jw_test_console_controller.dart';
import 'package:honeybox/pages/watch/jw_test_console_forms.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

void main() {
  testWidgets(
      'fresh temperature read hydrates all fields so changing display preserves compensation and unit',
      (tester) async {
    final (t, c) = await _setup(tester);
    var temperature = 7;
    final original = t.onWrite!;
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (f.ack) return;
      final m = JwCodec.decodeL2(f.payload), k = m.fields.single.key;
      if (m.command == 5 && k == 0x23) {
        t.emitAck(f.seq);
        t.emitMessage(5, 0x24, Uint8List.fromList([0, 0, 0, temperature]));
      } else if (m.command == 5 && k == 0x22) {
        temperature = m.fields.single.value.last;
        t.emitAck(f.seq);
        t.emitMessage(5, 0x24, m.fields.single.value);
      } else if (m.command == 5 && k == 0x2a) {
        t.emitAck(f.seq);
        t.emitMessage(5, 0x2b, Uint8List(4));
      } else if (m.command == 5 && k == 0x3a) {
        t.emitAck(f.seq);
        t.emitMessage(5, 0x3b, Uint8List(8));
      } else {
        original(bytes);
      }
    };
    final draft = <String, String>{};
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
                animation: c,
                builder: (_, __) => ListView(children: [
                      JwConsoleOperationCard(
                          operation: jwConsoleOperation(
                              'config-temperatureConfig-set'),
                          controller: c,
                          draft: draft)
                    ])))));
    await c.run('config-temperatureConfig-read', {});
    await tester.pumpAndSettle();
    expect(draft['display'], '1');
    expect(draft['compensate'], '1');
    expect(draft['celsius'], '0');
    await tester.tap(find
        .byKey(const Key('jw-console-config-temperatureConfig-set-display')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const Key('jw-console-run-config-temperatureConfig-set')));
    await tester.tap(
        find.byKey(const Key('jw-console-run-config-temperatureConfig-set')));
    await tester.pumpAndSettle();
    expect(temperature, 6);
    expect(c.results['config-temperatureConfig-set']!.success, true);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'every parameter form remains usable at 320 by 720 with 1.3 text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (_, c) = await _setup(tester);
    for (final op in jwConsoleOperations.where((o) => o.fields.isNotEmpty)) {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(
                  size: Size(320, 720), textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                  body: ListView(children: [
                JwConsoleOperationCard(
                    key: ValueKey(op.id),
                    operation: op,
                    controller: c,
                    draft: Map<String, String>.of(const {}))
              ])))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(Key('jw-console-run-${op.id}')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: op.id);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'selecting 24-hour label submits SDK raw zero and independently reads it back',
      (tester) async {
    final (t, c) = await _setup(tester);
    final original = t.onWrite!;
    var hour = 1;
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (f.ack) return;
      final m = JwCodec.decodeL2(f.payload), k = m.fields.single.key;
      if (m.command == 2 && k == 0x42) {
        t.emitAck(f.seq);
        t.emitMessage(2, 0x43, Uint8List.fromList([hour]));
      } else if (m.command == 2 && k == 0x41) {
        hour = m.fields.single.value.single;
        t.emitAck(f.seq);
      } else if (m.command == 5 && k == 0x2a) {
        t.emitAck(f.seq);
        t.emitMessage(5, 0x2b, Uint8List(4));
      } else if (m.command == 5 && k == 0x3a) {
        t.emitAck(f.seq);
        t.emitMessage(5, 0x3b, Uint8List(8));
      } else {
        original(bytes);
      }
    };
    final draft = <String, String>{};
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
                animation: c,
                builder: (_, __) => ListView(children: [
                      JwConsoleOperationCard(
                          operation:
                              jwConsoleOperation('config-hourSystem-set'),
                          controller: c,
                          draft: draft)
                    ])))));
    await c.run('config-hourSystem-read', {});
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('jw-console-config-hourSystem-set-value')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 小时').last);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('jw-console-run-config-hourSystem-set')));
    await tester.pumpAndSettle();
    expect(hour, 0);
    expect(c.results['config-hourSystem-set']!.success, true);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<(FakeJwTransport, JwTestConsoleController)> _setup(
    WidgetTester tester) async {
  final identity = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('console_forms_');
    try {
      return await JwIdentityStore(File('${dir.path}/id')).loadOrCreate();
    } finally {
      await dir.delete(recursive: true);
    }
  }))!;
  final t = FakeJwTransport();
  installJwDeviceScript(t);
  final repository = JwDeviceRepository(
      session: JwSession(t), identityStore: _Identity(identity), transport: t);
  await repository.initialize();
  final c = JwTestConsoleController(repository);
  addTearDown(() async {
    c.dispose();
    await repository.dispose();
    await t.dispose();
  });
  return (t, c);
}

class _Identity extends JwIdentityStore {
  final JwIdentityRecord record;
  _Identity(this.record) : super(File('unused'));
  @override
  Future<JwIdentityRecord> loadOrCreate() async => record;
}
