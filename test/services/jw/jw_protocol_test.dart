import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_protocol.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import '../../helpers/jw_fixture.dart';

void main() {
  test('history capabilities use independent firmware bit positions', () {
    for (final bit in [24, 33, 36, 37, 48]) {
      final mask = (BigInt.one << bit).toRadixString(16).padLeft(16, '0');
      final c = JwCapabilities.fromWire(jwHex(mask), Uint8List(1));
      expect([c.bloodOxygen, c.bloodPressure, c.steps, c.sleep, c.exercise],
          [24, 33, 36, 37, 48].map((n) => n == bit).toList());
    }
  });

  test('query, login, control and readback contracts use actual keys', () {
    final r = JwCommands.functionList();
    expect(
        JwCodec.encode(
            seq: 1,
            payload: JwCodec.encodeL2(r.command, [JwField(r.key, r.value)])),
        jwHex('ab000005ce9900010200360000'));
    final factory = JwCommands.factorySwitch();
    expect(
        JwCodec.encode(
            seq: 2,
            payload: JwCodec.encodeL2(
                factory.command, [JwField(factory.key, factory.value)])),
        jwHex('ab000005cc19000206003d0000'));
    expect([
      JwCommands.factorySwitch().command,
      JwCommands.factorySwitch().key,
      JwCommands.factorySwitch().responseKey
    ], [
      6,
      0x3d,
      0x3e
    ]);
    expect([JwCommands.language().key, JwCommands.language().responseKey],
        [0x4f, 0x50]);
    expect(JwCommands.setLanguage(1).responseKey, isNull);
    expect(JwCommands.time(DateTime(2026)).responseKey, isNull);
    expect(JwCommands.heartRateStreaming(false).value, [0]);
    expect(JwCommands.login(Uint8List(32)).responseKey, 4);
    expect(JwCommands.bind(Uint8List(32)).responseKey, 2);
  });
  test('firmware readiness/metab bits and factory flags stay independent', () {
    final c = JwCapabilities.fromWire(jwHex('4dd17dfce34ad83d'), jwHex('03'));
    expect([
      c.readiness,
      c.metabDaily,
      c.hrv,
      c.pressureMonitor,
      c.heartRate,
      c.temperature,
      c.languages
    ], List.filled(7, true));
    expect(c.factoryStress, isFalse);
    expect(c.factorySwitchRaw, 3);
    expect(c.rawHex, '4dd17dfce34ad83d');
    final zero = JwCapabilities.fromWire(Uint8List(8), jwHex('04'));
    expect(zero.pressureMonitor, isFalse);
    expect(zero.factoryStress, isTrue);
    expect(() => JwCapabilities.fromWire(Uint8List(7), jwHex('03')),
        throwsFormatException);
  });
  test('packed local time has exact bytes at year and date boundaries', () {
    expect(JwProtocol.timeBytes(DateTime(2026, 10, 3, 19, 20, 30)),
        jwHex('6a87351e'));
    expect(JwProtocol.timeBytes(DateTime(2000, 1, 1)), jwHex('00420000'));
    expect(JwProtocol.timeBytes(DateTime(2063, 12, 31, 23, 59, 59)),
        jwHex('ff3f7efb'));
    expect(() => JwProtocol.timeBytes(DateTime(2064)), throwsRangeError);
    expect(() => JwProtocol.timeBytes(DateTime(1999)), throwsRangeError);
  });
  test('identifier length is bytes and settings cannot silently truncate', () {
    for (final n in [31, 33]) {
      expect(() => JwCommands.login(Uint8List(n)), throwsArgumentError);
      expect(() => JwCommands.bind(Uint8List(n)), throwsArgumentError);
    }
    expect(() => JwCommands.setLanguage(3), throwsRangeError);
  });
  test('4-byte and combined 8-byte heart records use the low byte for bpm', () {
    for (final e in [
      (0x0f, '3543000104881e48'),
      (0x28, '35430001aabbccdd04881e48')
    ]) {
      final sample =
          JwProtocol.heartRates(JwMessage(5, [JwField(e.$1, jwHex(e.$2))]))
              .single;
      expect(sample.bpm, 72);
      expect(sample.minute, 1160);
      expect(sample.second, 30);
      expect(sample.date, DateTime(2026, 10, 3));
      expect(sample.raw, isNotEmpty);
    }
  });
  test('zero samples remain absent while multiple valid records survive', () {
    final samples = JwProtocol.heartRates(
        JwMessage(5, [JwField(0x0f, jwHex('3543000204881e0004890049'))]));
    expect(samples.map((s) => s.bpm), [73]);
    expect(JwProtocol.heartRates(JwMessage(2, [JwField(0x0f, jwHex('00'))])),
        isEmpty);
    expect(JwProtocol.heartRates(JwMessage(5, [JwField(0xfe, jwHex('00'))])),
        isEmpty);
  });
  test(
      'truncated, wrong count and impossible record dates do not become values',
      () {
    for (final h in [
      '3543000104881e',
      '3543000204881e48',
      '3543000105a01e48',
      '3543000104883c48',
      '0000000104881e48'
    ]) {
      expect(
          () => JwProtocol.heartRates(JwMessage(5, [JwField(0x0f, jwHex(h))])),
          throwsFormatException);
    }
  });
  test('missing device fields are nullable instead of default health values',
      () {
    const info = JwDeviceInfo(deviceKey: 'jw:serial');
    expect(info.battery, isNull);
    expect(info.firmware, isNull);
  });
}
