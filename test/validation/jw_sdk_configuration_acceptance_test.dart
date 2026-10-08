import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/services/jw/jw_configuration.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import 'package:honeybox/validation/jw_sdk_acceptance.dart';
import '../helpers/fake_jw_transport.dart';
import '../helpers/jw_configuration_script.dart';
import '../helpers/jw_device_script.dart';
import '../helpers/jw_fixture.dart';
import 'jw_sdk_acceptance_test.dart' show TestPort;

class ConfigurationPort extends TestPort
    implements JwConfigurationAcceptancePort {
  final Directory dir;
  JwDeviceRepository? repository;
  FakeJwTransport? transport;
  JwConfigurationScript? script;
  Map<JwConfigurationDomain, Uint8List>? physical;
  Uint8List display = Uint8List(4);
  bool failBpCompanionReadOnce = false, bpFailureIssued = false;
  bool failProbeAfterApply = false,
      wrongDevice = false,
      wrongIdentity = false,
      wrongCaps = false,
      powerSaveOnRestore = false,
      throwStateAfterClose = false;
  String functions = '4dd17dfce34ad83d';
  int writeCalls = 0;
  void Function(JwConfigurationChange)? afterSet, beforeSet;
  final writes = <JwConfigurationDomain>[];
  ConfigurationPort(this.dir);
  @override
  JwDeviceState get state {
    if (closed && throwStateAfterClose) {
      throw StateError('disposed provider read');
    }
    return repository?.state ?? super.state;
  }

  @override
  Future<void> connect(ScanDevice target) async {
    await super.connect(target);
    final t = FakeJwTransport();
    transport = t;
    installJwDeviceScript(t,
        functions:
            wrongCaps && connections > 1 ? '0000000000000000' : functions);
    if (wrongDevice && connections > 1) {
      t.readValues['2a25'] = Uint8List.fromList('OTHER'.codeUnits);
    }
    final s = JwConfigurationScript(t);
    script = s;
    if (physical != null) {
      s.values
        ..clear()
        ..addAll(physical!);
      s.bpDisplay = Uint8List.fromList(display);
    }
    physical = s.values;
    s.onRequest = (m) {
      if (failBpCompanionReadOnce &&
          !bpFailureIssued &&
          m.command == 5 &&
          m.fields.single.key == 0x3d) {
        bpFailureIssued = true;
        s.dropKey = 0x26;
      }
    };
    repository = JwDeviceRepository(
        session: JwSession(t,
            ackTimeout: const Duration(milliseconds: 100),
            replyTimeout: const Duration(milliseconds: 300)),
        identityStore: JwIdentityStore(File('${dir.path}/id.json')),
        transport: t);
  }

  @override
  Future<void> initialize() => repository!.initialize();
  @override
  Future<String> identityDigest() async =>
      wrongIdentity && connections > 1 ? 'e' * 64 : 'd' * 64;
  @override
  Future<JwConfigurationValue> readConfiguration(JwConfigurationDomain domain,
          {required JwConfigurationContract contract}) =>
      repository!.readConfiguration(domain, contract: contract);
  @override
  Future<JwConfigurationSnapshot> readConfigurationSnapshot(
          {required JwConfigurationContract contract}) =>
      repository!.readConfigurationSnapshot(contract: contract);
  @override
  Future<JwConfigurationPreflight> readConfigurationPreflight(
          {required JwConfigurationContract contract}) =>
      repository!.readConfigurationPreflight(contract: contract);
  @override
  Future<JwConfigurationWriteResult> setConfigurationVerified(
      JwConfigurationChange change,
      {required JwConfigurationContract contract,
      required JwConfigurationValue expectedCurrent}) async {
    beforeSet?.call(change);
    writes.add(change.domain);
    writeCalls++;
    final r = await repository!.setConfigurationVerified(change,
        contract: contract, expectedCurrent: expectedCurrent);
    display = script!.bpDisplay;
    afterSet?.call(change);
    if (writeCalls == 1 && powerSaveOnRestore) {
      script!.powerSave = jwHex('00000001');
    }
    if (writeCalls == 1 && failProbeAfterApply) {
      transport!.emitDisconnect();
      throw JwConfigurationException(
          domain: change.domain,
          stage: 'deliveryUnknown',
          cause: 'simulated disconnect after actual SDK write');
    }
    return r;
  }

  @override
  Future<JwConfigurationWriteResult> setTemperatureUnitVerified(bool celsius,
          {required JwConfigurationContract contract,
          required JwConfigurationValue expectedCurrent}) =>
      setConfigurationVerified(
          JwConfigurationChange.temperature(celsius: celsius),
          contract: contract,
          expectedCurrent: expectedCurrent);
  @override
  Future<void> disconnect() async {
    disconnects++;
    if (script != null) display = script!.bpDisplay;
    await repository?.dispose();
    await transport?.dispose();
    repository = null;
    transport = null;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class InitialBpPort extends ConfigurationPort {
  final bool initialEnabled;
  InitialBpPort(super.dir, this.initialEnabled);
  @override
  Future<void> connect(ScanDevice target) async {
    await super.connect(target);
    if (connections == 1) {
      script!.values[JwConfigurationDomain.bloodPressureAuto] =
          Uint8List.fromList([initialEnabled ? 1 : 0, 0]);
      script!.bpDisplay =
          Uint8List.fromList([initialEnabled ? 0 : 128, 0, 0, 0]);
    }
  }
}

void main() {
  late Directory dir;
  late ConfigurationPort port;
  late List<Map<String, Object?>> events;
  Map<String, Object?>? saved;
  bool cancel = false;
  Future<Map<String, Object?>> run(
          {String mode = 'configuration',
          Map<String, Object?>? baseline,
          Future<void> Function(Map<String, Object?>)? recorder,
          Future<void> Function(Map<String, Object?>)? saver}) =>
      AcceptanceRunner(
              port: port,
              config: AcceptanceConfig(
                  outputDirectory: dir.path,
                  address: '64:1A:B2:B8:00:3A',
                  mode: mode,
                  configurationBaselineFile:
                      mode == 'configuration-restart' ? 'baseline.json' : null,
                  expectedIdentitySha256:
                      mode == 'configuration-restart' ? 'd' * 64 : null),
              now: () => port.clock,
              delay: port.delay,
              isCancelled: () => cancel,
              configurationBaseline: baseline,
              saveConfigurationBaseline: saver ??
                  (b) async {
                    saved = b;
                    events.add({'type': 'baselineSaved'});
                  },
              record: recorder ??
                  (e) async {
                    events.add(e);
                  })
          .run();
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw_config_cli_');
    port = ConfigurationPort(dir);
    events = [];
    saved = null;
    cancel = false;
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
      'pre-write target conflict preserves the external value with zero restore SET',
      () async {
    port.beforeSet = (change) {
      if (port.writeCalls == 0) {
        port.script!.values[change.domain] = Uint8List.fromList([1]);
      }
    };
    final result = await run();
    expect(result['status'], 'fail');
    expect(port.physical![JwConfigurationDomain.hourSystem], [1]);
    expect(port.writeCalls, 1);
    final entry = (result['configurationDomains'] as List).first as Map;
    expect(entry['failureStage'], 'conflict');
    expect(entry['writeSubmitted'], false);
    expect(entry['restoreNotRequired'], true);
    expect(entry['restorePending'], false);
  });
  for (final enabled in [false, true]) {
    test(
        'BP restores display-only after known restoration intermediate $enabled',
        () async {
      port = InitialBpPort(dir, enabled);
      var mainSets = 0, displaySets = 0;
      port.beforeSet = (change) {
        if (change.domain == JwConfigurationDomain.bloodPressureAuto) {
          port.script!.onRequest = (m) {
            if (m.command == 5 && m.fields.single.key == 0x3d) {
              mainSets++;
              if (port.writeCalls == 16) port.script!.dropKey = 0x26;
            }
            if (m.command == 5 && m.fields.single.key == 0x25) displaySets++;
          };
        }
      };
      final result = await run();
      expect(result['status'], 'pass');
      expect(port.connections, 2);
      expect(port.physical![JwConfigurationDomain.bloodPressureAuto],
          [enabled ? 1 : 0, 0]);
      expect(port.display, [enabled ? 0 : 128, 0, 0, 0]);
      expect(mainSets, 2, reason: 'Recovery must never repeat the main SET');
      expect(displaySets, 1,
          reason:
              'Probe coupling already matches display; only recovery sends 25');
      final entry = (result['configurationDomains'] as List)
          .firstWhere((e) => e['domain'] == 'bloodPressureAuto') as Map;
      expect(entry['restoreCompanionCompleted'], true);
      expect(entry['restorePending'], false);
      expect(result['configurationRestored'], true);
    });
  }
  test(
      'baseline flush precedes first SET and each intent flush precedes its SET',
      () async {
    port.beforeSet = (change) {
      expect(saved, isNotNull);
      expect(
          events.any((e) =>
              e['type'] == 'configurationIntent' &&
              e['domain'] == change.domain.name),
          true);
    };
    final result = await run();
    expect(result['status'], 'pass');
    expect(result['schemaVersion'], 3);
    expect(events.indexWhere((e) => e['type'] == 'baselineSaved'),
        lessThan(events.indexWhere((e) => e['type'] == 'configurationIntent')));
    expect(port.writeCalls, 16);
  });
  test('all eight restored and checked after each probe', () async {
    final result = await run();
    expect(result['status'], 'pass');
    final domains = result['configurationDomains'] as List;
    expect(domains, hasLength(8));
    expect(
        domains
            .every((d) => d['probeVerified'] == true && d['restored'] == true),
        true);
    expect(
        port.writes.indexed
            .where((pair) => pair.$1.isEven)
            .map((pair) => pair.$2)
            .toList(),
        [
          JwConfigurationDomain.hourSystem,
          JwConfigurationDomain.distanceUnit,
          JwConfigurationDomain.screenLightTime,
          JwConfigurationDomain.screenBrightness,
          JwConfigurationDomain.temperatureConfig,
          JwConfigurationDomain.heartRateAuto,
          JwConfigurationDomain.bloodOxygenAuto,
          JwConfigurationDomain.bloodPressureAuto
        ]);
    expect(port.physical![JwConfigurationDomain.temperatureConfig],
        jwHex('00000001'));
    expect(result['configurationRestored'], true);
    expect(
        events.where((e) => e['type'] == 'configurationFullSnapshotVerified'),
        hasLength(8));
  });
  test('third value blocks restore', () async {
    port.afterSet = (change) {
      if (change.domain == JwConfigurationDomain.screenLightTime &&
          port.writeCalls == 5) {
        port.script!.values[change.domain] = jwHex('1405');
      }
    };
    final result = await run();
    expect(result['exitCode'], 1);
    expect(result['restorePending'], true);
    expect(port.writeCalls, 5);
    expect(
        port.physical![JwConfigurationDomain.screenLightTime], jwHex('1405'));
  });
  test('original current value skips restore SET', () async {
    port.afterSet = (c) {
      if (port.writeCalls == 1) port.script!.values[c.domain] = jwHex('00');
    };
    final result = await run();
    expect(result['status'], 'pass');
    expect(port.writeCalls, 15);
  });
  for (final kind in ['device', 'identity', 'caps']) {
    test('recovery refuses different $kind', () async {
      port.failProbeAfterApply = true;
      port.wrongDevice = kind == 'device';
      port.wrongIdentity = kind == 'identity';
      port.wrongCaps = kind == 'caps';
      final result = await run();
      expect(result['exitCode'], 1);
      expect(result['restorePending'], true);
      expect(port.writeCalls, 1);
      expect(port.connections, 2);
    });
  }
  test('partial delivery recovery reads before deciding', () async {
    port.failProbeAfterApply = true;
    final result = await run();
    expect(result['status'], 'fail');
    expect(result['restorePending'], false);
    expect(port.connections, 2);
    expect(port.writeCalls, 2);
    expect(port.physical![JwConfigurationDomain.hourSystem], jwHex('00'));
  });
  test('cancellation finishes current restore and stops new probes', () async {
    port.afterSet = (c) {
      if (port.writeCalls == 1) cancel = true;
    };
    final result = await run();
    expect(result['exitCode'], 2);
    expect(result['restorePending'], false);
    expect(port.writeCalls, 2);
    expect(port.physical![JwConfigurationDomain.hourSystem], jwHex('00'));
  });
  test('baseline flush failure causes zero write', () async {
    final result = await run(saver: (b) async {
      throw const FileSystemException('disk full');
    });
    expect(result['exitCode'], 1);
    expect(port.writeCalls, 0);
  });
  test('intent flush failure causes zero next write', () async {
    final result = await run(recorder: (e) async {
      if (e['type'] == 'configurationIntent') {
        throw const FileSystemException('intent disk full');
      }
      events.add(e);
    });
    expect(result['exitCode'], 1);
    expect(port.writeCalls, 0);
  });
  test(
      'logging failure after probe restores using already durable restore intent',
      () async {
    final result = await run(recorder: (e) async {
      if (e['type'] == 'configurationProbeVerified') {
        throw const FileSystemException('event disk full');
      }
      events.add(e);
    });
    expect(result['exitCode'], 1);
    expect(port.writeCalls, 2);
    expect(port.physical![JwConfigurationDomain.hourSystem], jwHex('00'));
    expect(result['restorePending'], false);
  });
  test(
      'restart is strictly readonly and checks all raw bytes; killed intent is not replayed',
      () async {
    await run();
    final envelope = saved!;
    final memory = {...port.physical!};
    final oldDisplay = port.display;
    port = ConfigurationPort(dir)
      ..physical = memory
      ..display = oldDisplay; // new process has independent SDK object
    final result = await run(mode: 'configuration-restart', baseline: envelope);
    expect(result['status'], 'pass');
    expect(result['configurationRestored'], true);
    expect(port.writeCalls, 0);
  });
  test('restart detects screen default-only mismatch without any SET',
      () async {
    await run();
    final envelope = saved!;
    final memory = port.physical!, oldDisplay = port.display;
    memory[JwConfigurationDomain.screenLightTime] = jwHex('0a06');
    port = ConfigurationPort(dir)
      ..physical = memory
      ..display = oldDisplay;
    final result = await run(mode: 'configuration-restart', baseline: envelope);
    expect(result['status'], 'fail');
    expect(port.writeCalls, 0);
    expect(
        port.physical![JwConfigurationDomain.screenLightTime], jwHex('0a06'));
  });
  test('restart eighth domain mismatch fails without writing', () async {
    await run();
    final envelope = saved!;
    port = ConfigurationPort(dir);
    port.physical = {
      for (final d in JwConfigurationDomain.values)
        d: switch (d) {
          JwConfigurationDomain.screenLightTime => jwHex('0a05'),
          JwConfigurationDomain.screenBrightness => jwHex('3c1e'),
          JwConfigurationDomain.temperatureConfig => jwHex('00000005'),
          _ => Uint8List(d.isMonitor ? 2 : 1)
        }
    };
    final result = await run(mode: 'configuration-restart', baseline: envelope);
    expect(result['exitCode'], 1);
    expect(port.writeCalls, 0);
  });
  test('unknown or missing eighth domain cannot pass', () async {
    port.functions =
        (BigInt.parse(port.functions, radix: 16) & ~(BigInt.one << 29))
            .toRadixString(16)
            .padLeft(16, '0');
    final result = await run(mode: 'configuration-read');
    expect(result['status'], 'unsupported');
    expect(result['configurationDomains'], hasLength(8));
    expect(port.writeCalls, 0);
  });
  test('power save during restore leaves pending', () async {
    port.powerSaveOnRestore = true;
    final result = await run();
    expect(result['exitCode'], 1);
    expect(result['restorePending'], true);
    expect(port.physical![JwConfigurationDomain.hourSystem], jwHex('01'));
  });
  test('invalid baseline SHA missing domain and future schema refused',
      () async {
    await run();
    final envelope = saved!;
    for (final bad in [
      {...envelope, 'baselineSha256': '0' * 64},
      {...envelope, 'schemaVersion': 4}
    ]) {
      port = ConfigurationPort(dir);
      final result = await run(mode: 'configuration-restart', baseline: bad);
      expect(result['exitCode'], 1);
      expect(port.writeCalls, 0);
    }
  });
  test('final report never reads a disposed production state', () async {
    port.throwStateAfterClose = true;
    final result = await run();
    expect(result['status'], 'pass');
    expect(result['configurationDeviceKey'], 'jw:TEST-SERIAL');
  });
  test('BP display repair restores journaled intermediate state', () async {
    port.failBpCompanionReadOnce = true;
    final result = await run();
    expect(result['status'], 'fail');
    expect(result['restorePending'], false);
    expect(port.connections, 2);
    expect(
        port.physical![JwConfigurationDomain.bloodPressureAuto], jwHex('0000'));
    expect(port.display, jwHex('00000000'));
  });
  test('BP unrelated main display combination is not overwritten', () async {
    port.afterSet = (c) {
      if (c.domain == JwConfigurationDomain.bloodPressureAuto &&
          port.writeCalls == 15) {
        port.script!.values[c.domain] = jwHex('0000');
        port.script!.bpDisplay = jwHex('80000000');
      }
    };
    final result = await run();
    expect(result['restorePending'], true);
    expect(port.writeCalls, 15);
    expect(port.display, jwHex('80000000'));
  });
  test('restart rejects missing eighth domain even with consistent SHA',
      () async {
    await run();
    final payload = Map<String, Object?>.from(saved!['baseline'] as Map);
    payload['configuration'] =
        Map<String, Object?>.from(payload['configuration'] as Map)
          ..remove('temperatureConfig');
    final bad = <String, Object?>{
      'schemaVersion': 3,
      'baseline': payload,
      'baselineSha256':
          sha256.convert(utf8.encode(jsonEncode(payload))).toString()
    };
    port = ConfigurationPort(dir);
    final result = await run(mode: 'configuration-restart', baseline: bad);
    expect(result['exitCode'], 1);
    expect(port.writeCalls, 0);
  });
  test('parse validates configuration restart arguments', () {
    expect(
        () => AcceptanceConfig(
            outputDirectory: 'unused',
            address: '64:1A:B2:B8:00:3A',
            mode: 'configuration-restart',
            expectedIdentitySha256: 'd' * 64),
        throwsArgumentError);
    final c = AcceptanceConfig.parse([
      '--address',
      '64:1A:B2:B8:00:3A',
      '--mode',
      'configuration-restart',
      '--expected-id-sha256',
      'd' * 64,
      '--configuration-baseline',
      'baseline.json'
    ]);
    expect(c.configurationBaselineFile, 'baseline.json');
  });
}
