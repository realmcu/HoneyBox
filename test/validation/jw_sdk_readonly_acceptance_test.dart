import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_configuration.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/validation/jw_sdk_acceptance.dart';
import '../helpers/jw_fixture.dart';
import 'jw_sdk_acceptance_test.dart' show TestPort;

class ReadOnlyTestPort extends TestPort implements JwReadOnlyAcceptancePort {
  final tx = StreamController<JwFrame>.broadcast(sync: true);
  final methods = <String>[];
  int initialized = 0, prepared = 0;
  bool missingIdentity = false, rogueCleanup = false, dropWitness = false;
  String? fail, rogue;
  final raw = <String, String>{
    'language': '01',
    'battery': '46',
    'health': '0000000000000000',
    'wrist': '01',
    'dnd': '6c0180',
    'heatWindow': '000000',
    'highHrDiagnostic': '008c'
  };
  ReadOnlyTestPort() {
    state = state.copyWith(
        info: const JwDeviceInfo(
            deviceKey: 'SERIAL',
            firmware: 'T005',
            hardware: 'H001',
            battery: 70));
  }
  @override
  Stream<JwFrame> get outgoingFrames => tx.stream;
  @override
  Future<void> prepareReadOnlyIdentity(String expected) async {
    prepared++;
    if (missingIdentity || expected != 'd' * 64) {
      throw StateError('Existing identity unavailable or mismatch');
    }
  }

  void emit(int command, int key, {Uint8List? value}) {
    tx.add(JwFrameDecoder()
        .add(JwCodec.encode(
            seq: 1,
            payload: JwCodec.encodeL2(
                command, [JwField(key, value ?? Uint8List(0))])))
        .single);
  }

  @override
  Future<void> initialize() async {
    initialized++;
    emit(2, 0x36);
    emit(6, 0x3d);
    emit(2, 0x4f);
    emit(3, 3, value: Uint8List.fromList(('a' * 32).codeUnits));
  }

  void query(String name, int command, int key) {
    methods.add(name);
    if (!dropWitness) emit(command, key);
    if (name == 'wrist') {
      if (rogue == 'pair') emit(2, 0x28);
      if (rogue == 'set') emit(2, 0x2a, value: jwHex('00'));
      if (rogue == 'value') emit(2, 0x2b, value: jwHex('01'));
      if (rogue == 'bind') {
        emit(3, 1, value: Uint8List.fromList(('a' * 32).codeUnits));
      }
      if (rogue == 'cursor') emit(5, 0x08);
    }
    if (fail == name) {
      throw JwConfigurationException(
          stage: 'unsupported', cause: '$name unavailable');
    }
  }

  @override
  Future<int> queryLanguage() async {
    query('language', 2, 0x4f);
    return int.parse(raw['language']!, radix: 16);
  }

  @override
  Future<int> readBatteryLevel() async {
    methods.add('battery');
    if (fail == 'battery') throw StateError('GATT read failed');
    return int.parse(raw['battery']!, radix: 16);
  }

  @override
  Future<JwHealthStatus> readHealthStatus(
      {required JwConfigurationContract contract}) async {
    query('health', 5, 0x3a);
    return JwHealthStatus(jwHex(raw['health']!));
  }

  @override
  Future<JwTurnOverWristStatus> readTurnOverWrist(
      {required JwConfigurationContract contract}) async {
    query('wrist', 2, 0x2b);
    return JwTurnOverWristStatus(jwHex(raw['wrist']!));
  }

  @override
  Future<JwDisturbStatus> readDisturb(
      {required JwConfigurationContract contract}) async {
    query('dnd', 2, 0x48);
    return JwDisturbStatus(jwHex(raw['dnd']!));
  }

  @override
  Future<JwHeatStressReminderStatus> queryHeatStressReminder(
      {required JwConfigurationContract contract}) async {
    query('heatWindow', 2, 0x87);
    return JwHeatStressReminderStatus(jwHex(raw['heatWindow']!));
  }

  @override
  Future<JwHeartRateReminderDiagnostic> readHeartRateReminderDiagnostic(
      {required JwConfigurationContract contract}) async {
    query('highHrDiagnostic', 2, 0x76);
    return JwHeartRateReminderDiagnostic(jwHex(raw['highHrDiagnostic']!));
  }

  @override
  Future<void> close() async {
    if (rogueCleanup) emit(2, 0x28);
    await tx.close();
    await super.close();
  }
}

void main() {
  AcceptanceConfig config({String mode = 'read-only'}) =>
      AcceptanceConfig.parse([
        '--address',
        '64:1A:B2:B8:00:3A',
        '--mode',
        mode,
        '--expected-id-sha256',
        'd' * 64,
        if (mode == 'read-only-restart') ...[
          '--read-only-baseline',
          'baseline.json'
        ]
      ]);
  Future<Map<String, Object?>> run(ReadOnlyTestPort p,
      {String mode = 'read-only',
      Map<String, Object?>? baseline,
      Future<void> Function(Map<String, Object?>)? recorder}) async {
    final runner = Function.apply(AcceptanceRunner.new, [], {
      #port: p,
      #config: config(mode: mode),
      #record: recorder ?? ((Map<String, Object?> e) async {}),
      #now: () => p.clock,
      #delay: p.delay,
      if (baseline != null) #readOnlyBaseline: baseline
    }) as AcceptanceRunner;
    return runner.run();
  }

  test('readonly mode requires existing identity digest and restart baseline',
      () {
    expect(
        () => AcceptanceConfig.parse(
            ['--address', '64:1A:B2:B8:00:3A', '--mode', 'read-only']),
        throwsArgumentError);
    expect(config().mode, 'read-only');
    expect(config(mode: 'read-only-restart').mode, 'read-only-restart');
  });
  test('seven reads audit outbound attempts and never invoke legacy setters',
      () async {
    final p = ReadOnlyTestPort();
    final events = <Map<String, Object?>>[];
    final r = await run(p, recorder: (e) async {
      events.add(e);
    });
    expect(r['status'], 'pass');
    expect(r['exitCode'], 0);
    expect(p.methods, [
      'language',
      'battery',
      'health',
      'wrist',
      'dnd',
      'heatWindow',
      'highHrDiagnostic'
    ]);
    expect(p.languages, isEmpty);
    expect(p.hearts, isEmpty);
    expect(p.times, isEmpty);
    expect((r['readOnlyWireAudit'] as Map)['status'], 'pass');
    expect(r['readOnlyResults'], hasLength(7));
    expect(events.where((e) => e['type'] == 'wireAttempt'), isNotEmpty);
    expect(events.toString(), isNot(contains('a' * 32)));
  });
  for (final name in ['language', 'battery']) {
    test('$name scalar cannot wrap an invalid integer into a passing byte',
        () async {
      final p = ReadOnlyTestPort()..raw[name] = '100';
      final r = await run(p);
      expect(r['exitCode'], 1);
      expect(p.methods.last, name);
    });
  }
  test('missing existing identity fails before initialize or query', () async {
    final p = ReadOnlyTestPort()..missingIdentity = true;
    final r = await run(p);
    expect(r['exitCode'], 1);
    expect(p.initialized, 0);
    expect(p.methods, isEmpty);
  });
  for (final name in [
    'language',
    'battery',
    'health',
    'wrist',
    'dnd',
    'heatWindow',
    'highHrDiagnostic'
  ]) {
    test('$name query failure cannot skip to pass', () async {
      final p = ReadOnlyTestPort()..fail = name;
      final r = await run(p);
      expect(r['exitCode'], 1);
      expect(r['status'], isNot('pass'));
      expect(p.methods.last, name);
    });
  }
  for (final rogue in ['pair', 'set', 'value', 'bind', 'cursor']) {
    test('outbound $rogue fails white list and stops next query', () async {
      final p = ReadOnlyTestPort()..rogue = rogue;
      final r = await run(p);
      expect(r['exitCode'], 1);
      expect((r['readOnlyWireAudit'] as Map)['status'], 'fail');
      expect(p.methods.last, 'wrist');
    });
  }
  test(
      'cleanup outbound violation cannot be hidden by earlier successful reads',
      () async {
    final p = ReadOnlyTestPort()..rogueCleanup = true;
    final r = await run(p);
    expect(r['exitCode'], 1);
    expect((r['readOnlyWireAudit'] as Map)['status'], 'fail');
  });
  test('typed return without outbound query witnesses cannot pass', () async {
    final p = ReadOnlyTestPort()..dropWitness = true;
    final r = await run(p);
    expect(r['exitCode'], 1);
  });
  test('independent restart permits dynamic changes but checks static intent',
      () async {
    final first = await run(ReadOnlyTestPort());
    final next = ReadOnlyTestPort()
      ..raw['battery'] = '45'
      ..raw['health'] = '0000000000000002'
      ..raw['dnd'] = 'ec0180';
    final r = await run(next, mode: 'read-only-restart', baseline: first);
    expect(r['exitCode'], 0);
    expect(r['readOnlyStaticRetained'], true);
    final changed = ReadOnlyTestPort()..raw['wrist'] = '00';
    final fail = await run(changed, mode: 'read-only-restart', baseline: first);
    expect(fail['exitCode'], 1);
    expect(fail['error'], contains('static'));
    expect(changed.languages, isEmpty);
  });
  test('restart rejects incomplete baseline before initialization', () async {
    final first = await run(ReadOnlyTestPort());
    (first['readOnlyResults'] as List).removeLast();
    final p = ReadOnlyTestPort();
    final r = await run(p, mode: 'read-only-restart', baseline: first);
    expect(r['exitCode'], 1);
    expect(p.initialized, 0);
  });
  test('restart rejects changed device attribution', () async {
    final first = await run(ReadOnlyTestPort());
    final p = ReadOnlyTestPort();
    p.state = p.state.copyWith(
        info: const JwDeviceInfo(
            deviceKey: 'OTHER', firmware: 'T005', hardware: 'H001'));
    final r = await run(p, mode: 'read-only-restart', baseline: first);
    expect(r['exitCode'], 1);
    expect(p.methods, isEmpty);
  });
  test('failed audit log flush returns failure', () async {
    final r = await run(ReadOnlyTestPort(), recorder: (e) async {
      if (e['type'] == 'wireAttempt') throw StateError('disk full');
    });
    expect(r['exitCode'], 1);
  });
}
