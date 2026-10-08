import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_configuration.dart';
import 'package:honeybox/services/jw/jw_protocol.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import '../../helpers/jw_fixture.dart';

void main() {
  final fixture = jsonDecode(
      File('test/fixtures/jw_configuration_vectors_v1.json')
          .readAsStringSync());
  JwMessage message(int cmd, int key, String raw) =>
      JwMessage(cmd, [JwField(key, jwHex(raw))]);
  JwConfigurationValue parse(Map row, String field) {
    final packet = (row['packets'] as List)
        .firstWhere((p) => p['role'] == 'beforeResponse');
    return JwConfigurationCodec.parse(
        JwConfigurationDomain.values.byName(row['domain']),
        message(packet['command'], packet['key'], row[field]),
        companion: row['domain'] == 'bloodPressureAuto'
            ? message(5, 0x27, row['companionBeforeRaw'])
            : null);
  }

  for (final pair in [
    (JwConfigurationDomain.screenLightTime, 0x4c, '0505', 10, '0a05'),
    (JwConfigurationDomain.screenBrightness, 0x55, '1e1e', 60, '3c1e'),
  ]) {
    test(
        'actual screen current/default read preserved with one-byte SET ${pair.$1.name}',
        () {
      final before =
          JwConfigurationCodec.parse(pair.$1, message(2, pair.$2, pair.$3));
      final target = JwConfigurationCodec.target(
          before, JwConfigurationChange.scalar(pair.$1, pair.$4));
      expect(target.raw, jwHex(pair.$5));
      expect(target.scalarValue, pair.$4);
      expect(JwConfigurationCodec.writeRequest(target).value, [pair.$4]);
      expect(
          JwConfigurationCodec.writeRequest(before).value, [before.raw.first]);
      expect(
          before.sameValue(JwConfigurationValue(
              pair.$1, Uint8List.fromList([before.raw[0], before.raw[1] + 1]))),
          false);
    });
    test('screen read rejects missing/default invalid bytes ${pair.$1.name}',
        () {
      for (final raw in [
        pair.$3.substring(0, 2),
        '${pair.$3}00',
        '${pair.$3.substring(0, 2)}00'
      ]) {
        expect(
            () => JwConfigurationCodec.parse(pair.$1, message(2, pair.$2, raw)),
            throwsA(isA<JwConfigurationException>()));
      }
    });
  }
  for (final row in fixture['domains']) {
    final domain = JwConfigurationDomain.values.byName(row['domain']);
    test('all eight read set response restore contracts ${domain.name}', () {
      final read = JwConfigurationCodec.readRequest(domain);
      final p = (row['packets'] as List).firstWhere((p) => p['role'] == 'read');
      expect(JwCodec.encodeL2(read.command, [JwField(read.key, read.value)]),
          jwHex(p['l2']));
      final before = parse(row, 'beforeRaw'), target = parse(row, 'targetRaw');
      for (final pair in [(target, 'set'), (before, 'restore')]) {
        final request = JwConfigurationCodec.writeRequest(pair.$1);
        final packet =
            (row['packets'] as List).firstWhere((p) => p['role'] == pair.$2);
        expect(
            JwCodec.encodeL2(
                request.command, [JwField(request.key, request.value)]),
            jwHex(packet['l2']));
        expect(request.responseKey,
            domain == JwConfigurationDomain.bloodPressureAuto ? 0x3f : null);
        expect(request.readOnly, isFalse);
      }
    });
  }
  test('monitor flags are not intervals', () {
    for (final row in fixture['domains']
        .where((r) => (r['domain'] as String).endsWith('Auto'))) {
      final v = parse(row, 'targetRaw');
      expect(v.enabled, true);
      expect(v.intervalMinutes, isNull);
    }
  });
  test('temperature preserves every non-unit bit', () {
    for (var n = 0; n < 8; n++) {
      final v = JwConfigurationCodec.parse(
          JwConfigurationDomain.temperatureConfig,
          message(5, 0x24, n.toRadixString(16).padLeft(8, '0')));
      final target = JwConfigurationCodec.target(
          v, JwConfigurationChange.temperature(celsius: !v.celsius!));
      expect(target.raw, jwHex((n ^ 4).toRadixString(16).padLeft(8, '0')));
      expect(target.displayEnabled, v.displayEnabled);
      expect(target.compensate, v.compensate);
    }
  });
  test('reserved bits are diagnostic and not writable', () {
    final v = JwConfigurationCodec.parse(
        JwConfigurationDomain.temperatureConfig, message(5, 0x24, '80000001'));
    expect(v.raw, jwHex('80000001'));
    expect(v.writable, false);
    expect(
        () => JwConfigurationCodec.target(
            v, JwConfigurationChange.temperature(celsius: false)),
        throwsA(isA<JwConfigurationException>()));
    for (final pair in [
      (JwConfigurationDomain.heartRateAuto, 0x12, '0001'),
      (JwConfigurationDomain.bloodOxygenAuto, 0x35, '0100'),
      (JwConfigurationDomain.bloodPressureAuto, 0x3f, '010a')
    ]) {
      final value = JwConfigurationCodec.parse(
          pair.$1, message(5, pair.$2, pair.$3),
          companion: pair.$1 == JwConfigurationDomain.bloodPressureAuto
              ? message(5, 0x27, '00000000')
              : null);
      expect(value.writable, false);
      expect(() => JwConfigurationCodec.writeRequest(value),
          throwsA(isA<JwConfigurationException>()));
    }
  });
  test('invalid domain input never truncates', () {
    for (final b in fixture['boundaries']) {
      JwConfigurationChange f() => JwConfigurationChange.scalar(
          JwConfigurationDomain.values.byName(b['domain']), b['value']);
      if (b['valid']) {
        expect(f, returnsNormally);
      } else {
        expect(f, throwsA(isA<JwConfigurationException>()));
      }
    }
    expect(
        () => JwConfigurationChange.scalar(
            JwConfigurationDomain.heartRateAuto, 1),
        throwsA(isA<JwConfigurationException>()));
    expect(
        () => JwConfigurationChange.monitor(
            JwConfigurationDomain.hourSystem, true),
        throwsA(isA<JwConfigurationException>()));
    expect(
        () => JwConfigurationChange.monitor(
            JwConfigurationDomain.heartRateAuto, true,
            bloodPressureDisplay: true),
        throwsA(isA<JwConfigurationException>()));
    expect(() => JwConfigurationChange.temperature(),
        throwsA(isA<JwConfigurationException>()));
  });
  test('read parser rejects wrong command key count and length', () {
    for (final m in [
      message(5, 0x43, '00'),
      message(2, 0x44, '00'),
      message(2, 0x43, ''),
      message(2, 0x43, '0000'),
      JwMessage(2, [JwField(0x43, jwHex('00')), JwField(0x43, jwHex('01'))])
    ]) {
      expect(
          () => JwConfigurationCodec.parse(JwConfigurationDomain.hourSystem, m),
          throwsA(isA<JwConfigurationException>()));
    }
    expect(
        () => JwConfigurationCodec.parse(
            JwConfigurationDomain.bloodPressureAuto, message(5, 0x3f, '0100')),
        throwsA(isA<JwConfigurationException>()));
  });
  test('BP companion display preserved or explicitly restored', () {
    for (final e in [0, 1]) {
      for (final d in [0, 1]) {
        final v = JwConfigurationCodec.parse(
            JwConfigurationDomain.bloodPressureAuto,
            message(5, 0x3f, e == 1 ? '0100' : '0000'),
            companion: message(5, 0x27, d == 1 ? '80000000' : '00000000'));
        final target = JwConfigurationCodec.target(
            v, JwConfigurationChange.monitor(v.domain, e == 0));
        expect(target.companionRaw, v.companionRaw);
        final restore = JwConfigurationCodec.target(
            target,
            JwConfigurationChange.monitor(v.domain, e == 1,
                bloodPressureDisplay: d == 1));
        expect(restore.sameValue(v), true);
        expect(JwConfigurationCodec.companionReadRequest(v.domain)!.key, 0x26);
        expect(JwConfigurationCodec.companionWriteRequest(v)!.value,
            v.companionRaw);
      }
    }
    final bad = JwConfigurationCodec.parse(
        JwConfigurationDomain.bloodPressureAuto, message(5, 0x3f, '0000'),
        companion: message(5, 0x27, '80000001'));
    expect(bad.writable, false);
  });
  test('raw values companion values and snapshot maps are immutable', () {
    final raw = jwHex('00');
    final v = JwConfigurationValue(JwConfigurationDomain.hourSystem, raw);
    raw[0] = 1;
    expect(v.scalarValue, 0);
    expect(() => v.raw[0] = 1, throwsUnsupportedError);
    final values = {
      for (final row in fixture['domains'])
        JwConfigurationDomain.values.byName(row['domain']):
            parse(row, 'beforeRaw')
    };
    final snap = JwConfigurationSnapshot(values);
    values.clear();
    expect(snap.values, hasLength(8));
    expect(() => snap.values.clear(), throwsUnsupportedError);
    expect(() => JwConfigurationSnapshot({}),
        throwsA(isA<JwConfigurationException>()));
  });
  test('preflight validates actual masks without claiming charge state', () {
    final ok = JwConfigurationPreflight(
        powerSaveRaw: jwHex('00000000'),
        healthStatusRaw: jwHex('000000000000002a'),
        battery: 70);
    expect(ok.eligible, true);
    for (final mask in [1, 4, 16, 64, 256, 512]) {
      final p = JwConfigurationPreflight(
          powerSaveRaw: jwHex('00000000'),
          healthStatusRaw: jwHex(mask.toRadixString(16).padLeft(16, '0')),
          battery: 70);
      expect(p.eligible, false);
    }
    expect(
        JwConfigurationPreflight(
                powerSaveRaw: jwHex('00000001'),
                healthStatusRaw: Uint8List(8),
                battery: 70)
            .eligible,
        false);
    for (final m in ['0000000000000400', '8000000000000000']) {
      expect(
          () => JwConfigurationPreflight(
              powerSaveRaw: Uint8List(4),
              healthStatusRaw: jwHex(m),
              battery: 70),
          throwsA(isA<JwConfigurationException>()));
    }
  });
}
