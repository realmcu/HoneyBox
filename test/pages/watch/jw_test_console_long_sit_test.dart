import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/jw_test_console_catalog.dart';
import 'package:honeybox/pages/watch/jw_test_console_controller.dart';
import 'package:honeybox/pages/watch/jw_test_console_forms.dart';
import 'package:honeybox/pages/watch/jw_test_console_values.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_remaining_models.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

const _dormantRaw = [42, 0, 255, 250, 60, 255, 254, 99];
const _dormantForm = {
  'enabled': '0',
  'startMinute': '255',
  'endMinute': '250',
  'interval': '60',
  'startHour': '255',
  'endHour': '254',
};

Map<String, String> _formWith(Map<String, String> changes) =>
    {..._dormantForm, ...changes};

void main() {
  test('disabled unchanged legacy dormant fields keep every raw byte', () {
    final before = JwLongSitSettings(_dormantRaw);
    final after = const JwConsoleParameters(_dormantForm).longSit(before);
    expect(after.raw, _dormantRaw);
    expect(after.enabled, false);
    expect(after.hasValidSchedule, false);
  });
  test(
      'disabled edits validate only changed schedule fields and preserve other dormant bytes',
      () {
    final before = JwLongSitSettings(_dormantRaw);
    final after =
        JwConsoleParameters(_formWith({'startMinute': '30'})).longSit(before);
    expect(after.raw, [42, 0, 30, 250, 60, 255, 254, 99]);
    for (final entry in {
      'startMinute': '254',
      'endMinute': '251',
      'startHour': '254',
      'endHour': '253'
    }.entries) {
      expect(
          () => JwConsoleParameters({..._dormantForm, entry.key: entry.value})
              .longSit(before),
          throwsFormatException,
          reason: entry.key);
    }
  });
  test(
      'enabling requires every schedule field valid and preserves unknown bytes after repair',
      () {
    final before = JwLongSitSettings(_dormantRaw);
    expect(
        () => JwConsoleParameters(_formWith({'enabled': '1'})).longSit(before),
        throwsFormatException);
    final after = JwConsoleParameters(_formWith({
      'enabled': '1',
      'startMinute': '15',
      'endMinute': '30',
      'startHour': '8',
      'endHour': '20'
    })).longSit(before);
    expect(after.raw, [42, 1, 15, 30, 60, 8, 20, 99]);
  });
  test(
      'disabled dormant preservation never bypasses interval bounds or malformed fields',
      () {
    final before = JwLongSitSettings(_dormantRaw);
    for (final interval in ['-1', '256', 'NaN', '']) {
      expect(
          () => JwConsoleParameters({..._dormantForm, 'interval': interval})
              .longSit(before),
          throwsFormatException);
    }
    for (final invalid in ['NaN', '', '-1', '256']) {
      expect(
          () => JwConsoleParameters({..._dormantForm, 'startMinute': invalid})
              .longSit(before),
          throwsFormatException);
    }
  });

  testWidgets(
      'legacy dormant form can submit off without normalizing bytes and independently reads back',
      (tester) async {
    final (transport, controller, script) = await _setup(tester);
    final draft = <String, String>{};
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
                animation: controller,
                builder: (_, __) => ListView(children: [
                      JwConsoleOperationCard(
                          operation: jwConsoleOperation('longSit-set'),
                          controller: controller,
                          draft: draft)
                    ])))));
    await controller.run('longSit-read', {});
    await tester.pumpAndSettle();
    expect(draft, _dormantForm);
    final run = find.byKey(const Key('jw-console-run-longSit-set'));
    await tester.ensureVisible(run);
    await tester.pumpAndSettle();
    await tester.tap(run);
    await tester.pumpAndSettle();
    expect(controller.results['longSit-set']!.success, true);
    expect(script.submitted, [_dormantRaw]);
    expect(script.queryCount, 3,
        reason:
            'initial read, independent conflict read, and independent readback');
    expect(controller.results['longSit-set']!.message, contains('读回值'));
    expect(find.textContaining('关闭时保留未修改的休眠时分原字节'), findsOneWidget);
    expect(
        transport.sent
            .where((f) => !f.ack)
            .map((f) => JwCodec.decodeL2(f.payload))
            .where((m) => m.command == 2 && m.fields.single.key == 0x21)
            .single
            .fields
            .single
            .value,
        _dormantRaw);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'invalid edited dormant field and unchanged invalid enabling send zero BLE while valid repaired enabling is verified',
      (tester) async {
    final (transport, controller, script) = await _setup(tester);
    await controller.run('longSit-read', {});
    final baseline = transport.writes.length;
    await controller
        .run('longSit-set', {..._dormantForm, 'startMinute': '254'});
    expect(controller.results['longSit-set']!.success, false);
    await controller.run('longSit-set', {..._dormantForm, 'enabled': '1'});
    expect(controller.results['longSit-set']!.success, false);
    expect(transport.writes.length, baseline);
    expect(script.submitted, isEmpty);
    await controller.run('longSit-set', {
      ..._dormantForm,
      'enabled': '1',
      'startMinute': '15',
      'endMinute': '30',
      'startHour': '8',
      'endHour': '20'
    });
    expect(controller.results['longSit-set']!.success, true);
    expect(script.submitted, [
      [42, 1, 15, 30, 60, 8, 20, 99]
    ]);
    expect(controller.results['longSit-set']!.message, contains('独立读回一致'));
  });
}

Future<(FakeJwTransport, JwTestConsoleController, _LongSitScript)> _setup(
    WidgetTester tester) async {
  final identity = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('console_long_sit_');
    try {
      return await JwIdentityStore(File('${dir.path}/id')).loadOrCreate();
    } finally {
      await dir.delete(recursive: true);
    }
  }))!;
  final transport = FakeJwTransport();
  installJwDeviceScript(transport);
  final repository = JwDeviceRepository(
      session: JwSession(transport),
      identityStore: _Identity(identity),
      transport: transport);
  await repository.initialize();
  final controller = JwTestConsoleController(repository);
  final script = _LongSitScript(transport);
  addTearDown(() async {
    controller.dispose();
    await repository.dispose();
    await transport.dispose();
  });
  return (transport, controller, script);
}

class _LongSitScript {
  List<int> saved = List.of(_dormantRaw);
  final submitted = <List<int>>[];
  int queryCount = 0;
  _LongSitScript(FakeJwTransport transport) {
    final original = transport.onWrite!;
    transport.onWrite = (bytes) {
      final frame = JwFrameDecoder().add(bytes).single;
      if (frame.ack) return;
      final message = JwCodec.decodeL2(frame.payload),
          field = message.fields.single;
      if (message.command == 2 && field.key == 0x26) {
        queryCount++;
        transport.emitAck(frame.seq);
        transport.emitMessage(2, 0x27, Uint8List.fromList(saved));
      } else if (message.command == 2 && field.key == 0x48) {
        transport.emitAck(frame.seq);
        transport.emitMessage(2, 0x49, Uint8List(3));
      } else if (message.command == 2 && field.key == 0x21) {
        saved = field.value.toList();
        submitted.add(List.of(saved));
        transport.emitAck(frame.seq);
      } else {
        original(bytes);
      }
    };
  }
}

class _Identity extends JwIdentityStore {
  final JwIdentityRecord record;
  _Identity(this.record) : super(File('unused'));
  @override
  Future<JwIdentityRecord> loadOrCreate() async => record;
}
