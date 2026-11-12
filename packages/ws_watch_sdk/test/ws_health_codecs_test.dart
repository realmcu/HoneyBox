import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/wire/ws_data_command.dart';
import 'package:ws_watch_sdk/src/wire/ws_l2_message.dart';
import 'package:ws_watch_sdk/src/history/ws_health_codecs.dart';
import 'package:ws_watch_sdk/src/history/ws_history_models.dart';

Uint8List _hex(String pairs) {
  final parts = pairs.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  return Uint8List.fromList(parts.map((h) => int.parse(h, radix: 16)).toList());
}

WSL2Message _l2(int key, String hex) {
  return WSL2Message(
    command: WSDataCommand.command,
    version: WSDataCommand.version,
    key: key,
    value: _hex(hex),
  );
}

void main() {
  test('decodes live sim epoch little-endian', () {
    final frame = _l2(
      WSDataCommand.keyDataHeartRate,
      '05 00 02 4B CF F3 6A 48 53 D6 F3 6A 4B',
    );
    final rows = WSHealthCodecs.decodeHeartRateDataFrame(frame);
    expect(rows[0].time, 0x6AF3CF4B);
    expect(rows[1].time, 0x6AF3D653);
  });

  test('decodes spec example activity frame 0x21', () {
    final frame = _l2(
      WSDataCommand.keyDataActivity,
      '12 00 02 6A CC 9A 88 04 B0 03 52 01 C8 62 0F 00 01 00 00 00 00 '
      '6A CC 9E 0C 01 2C 00 D2 00 70 00 0F 00 00 00 00 00 00',
    );
    final rows = WSHealthCodecs.decodeActivityDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].time.millisecondsSinceEpoch, 0x889ACC6A * 1000);
    expect(rows[0].steps, 0x04B0);
    expect(rows[0].distanceMeters, 0x0352);
    expect(rows[0].caloriesTenthKcal, 0x01C8);
    expect(rows[0].avgHeartBpm, 0x62);
    expect(rows[0].hasAvgHeartRate, isTrue);
    expect(rows[1].steps, 0x012C);
    expect(rows[1].hasAvgHeartRate, isFalse);
  });

  test('decodes spec example sleep frame 0x22', () {
    final frame = _l2(
      WSDataCommand.keyDataSleep,
      '08 00 02 6A CC 3F 20 01 00 00 00 6A CC 54 38 02 00 00 00',
    );
    final rows = WSHealthCodecs.decodeSleepDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].state, 0x01);
    expect(rows[1].state, 0x02);
    expect(rows[0].timeRewind, isFalse);
  });

  test('decodes spec example heart rate frame 0x23', () {
    final frame = _l2(
      WSDataCommand.keyDataHeartRate,
      '05 00 02 6A CC 9A 88 48 6A CC 9A C4 4B',
    );
    final rows = WSHealthCodecs.decodeHeartRateDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].bpm, 0x48);
    expect(rows[1].bpm, 0x4B);
    expect(rows[0].time, 0x889ACC6A);
  });

  test('decodes spec example blood pressure frame 0x24', () {
    final frame = _l2(
      WSDataCommand.keyDataBloodPressure,
      '06 00 02 6A CC 9A 88 78 50 6A CC CB C0 76 4E',
    );
    final rows = WSHealthCodecs.decodeBloodPressureDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].systolic, 0x78);
    expect(rows[0].diastolic, 0x50);
    expect(rows[1].systolic, 0x76);
    expect(rows[1].diastolic, 0x4E);
  });

  test('decodes spec example blood oxygen frame 0x25', () {
    final frame = _l2(
      WSDataCommand.keyDataBloodOxygen,
      '07 00 02 6A CC 9A 88 62 63 60 6A CC CB C0 61 FF FF',
    );
    final rows = WSHealthCodecs.decodeBloodOxygenDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].currentPercent, 0x62);
    expect(rows[0].highPercent, 0x63);
    expect(rows[0].lowPercent, 0x60);
    expect(rows[1].highPercent, isNull);
    expect(rows[1].lowPercent, isNull);
  });

  test('decodes spec example HRV frame 0x26', () {
    final frame = _l2(
      WSDataCommand.keyDataHrv,
      '06 00 02 6A CC 9A 88 00 2D 6A CC CB C0 00 34',
    );
    final rows = WSHealthCodecs.decodeHrvDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].sdnnMs, 0x2D);
    expect(rows[1].sdnnMs, 0x34);
  });

  test('decodes spec example pressure frame 0x27', () {
    final frame = _l2(
      WSDataCommand.keyDataPressure,
      '05 00 02 6A CC 9A 88 23 6A CC CB C0 3E',
    );
    final rows = WSHealthCodecs.decodePressureDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].value, 0x23);
    expect(rows[1].value, 0x3E);
  });

  test('decodes spec example temperature frame 0x28', () {
    final frame = _l2(
      WSDataCommand.keyDataTemperature,
      '0A 00 02 6A CC 9A 88 0E 44 0C EE 00 03 6A CC CB C0 80 00 0B B8 FF 00',
    );
    final rows = WSHealthCodecs.decodeTemperatureDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].bodyHundredthCelsius, 0x0E44);
    expect(rows[0].skinHundredthCelsius, 0x0CEE);
    expect(rows[0].heatStressRaw, 0x00);
    expect(rows[0].worn, isTrue);
    expect(rows[0].compensated, isTrue);
    expect(rows[1].bodyHundredthCelsius, isNull);
    expect(rows[1].skinHundredthCelsius, 0x0BB8);
    expect(rows[1].heatStressRaw, isNull);
  });

  test('decodes spec example blood glucose frame 0x29', () {
    final frame = _l2(
      WSDataCommand.keyDataBloodGlucose,
      '06 00 02 6A CC 9A 88 00 38 6A CC CB C0 00 48',
    );
    final rows = WSHealthCodecs.decodeBloodGlucoseDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].mmolLtenth, 0x38);
    expect(rows[1].mmolLtenth, 0x48);
  });

  test('decodes spec example sport frame 0x2A', () {
    final frame = _l2(
      WSDataCommand.keyDataSport,
      '1F 00 01 00 00 00 2A 6A CC 9A 88 6A CC A1 90 01 07 08 07 44 '
      '00 00 11 94 00 00 14 50 00 00 0C 80 91 01',
    );
    final rows = WSHealthCodecs.decodeSportDataFrame(frame);
    expect(rows.length, 1);
    expect(rows[0].sportId, 0x2A);
    expect(rows[0].startTime, 0x889ACC6A);
    expect(rows[0].endTime, 0x90A1CC6A);
    expect(rows[0].steps, 0x1194);
    expect(rows[0].distanceMeters, 0x1450);
    expect(rows[0].caloriesTenthKcal, 0x0C80);
    expect(rows[0].avgHeartBpm, 0x91);
    expect(rows[0].hasDetail, isTrue);
  });

  test('decodeByKey dispatches to typed lists', () {
    final frame = _l2(
      WSDataCommand.keyDataHeartRate,
      '05 00 02 6A CC 9A 88 48 6A CC 9A C4 4B',
    );
    final decoded =
        WSHealthCodecs.decodeByKey(WSDataCommand.keyDataHeartRate, frame);
    expect(decoded, isA<List<WSHeartRate>>());
  });

  test('decodes full L2 wire example for heart rate', () {
    final wire = _hex('05 10 23 00 0D 05 00 02 6A CC 9A 88 48 6A CC 9A C4 4B');
    final messages = WSL2Message.decodeAll(wire);
    expect(messages.length, 1);
    final rows = WSHealthCodecs.decodeHeartRateDataFrame(messages[0]);
    expect(rows[0].bpm, 0x48);
  });
}
