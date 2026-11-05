import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/connection/jw_protocol.dart';
import 'package:jw_watch_sdk/src/settings/jw_settings_codec.dart';

void main() {
  test('public SDK errors provide a stable code and English msg', () {
    const error = JWException(
        JWErrorCode.businessReplyTimeout, 'JW business reply timed out');
    expect(error.code, JWErrorCode.businessReplyTimeout);
    expect(error.msg, 'JW business reply timed out');
  });

  test('Android V2 language codes are preserved', () {
    expect(JWLanguage.simplifiedChinese.code, 0x01);
    expect(JWLanguage.spanish.code, 0x57);
    expect(JWLanguage.fromCode(0x66), JWLanguage.vietnamese);
    expect(() => JWLanguage.fromCode(0xff), throwsFormatException);
  });

  test('hour and unit systems reject unsupported device values', () {
    expect(JWHourSystem.fromCode(0), JWHourSystem.h24);
    expect(JWUnitSystem.fromCode(1), JWUnitSystem.imperial);
    expect(() => JWHourSystem.fromCode(2), throwsFormatException);
    expect(() => JWUnitSystem.fromCode(2), throwsFormatException);
  });

  test('basic settings requests follow Android V2 command keys', () {
    expect(encodeJWRequest(JWProtocolCommands.readLanguage()),
        Uint8List.fromList([2, 0, 0x4f, 0, 0]));
    expect(encodeJWRequest(JWProtocolCommands.setHourSystem(1)),
        Uint8List.fromList([2, 0, 0x41, 0, 1, 1]));
    expect(encodeJWRequest(JWProtocolCommands.setUnitSystem(0)),
        Uint8List.fromList([2, 0, 0x44, 0, 1, 0]));
    expect(JWProtocolCommands.readScreenBrightness().replyTimeout,
        const Duration(seconds: 5));
  });

  test('time encoding follows the Android V2 packed four-byte format', () {
    final encoded = JWSettingsCodec.encodeTime(DateTime(2026, 11, 4, 18, 23, 59));
    expect(encoded, Uint8List.fromList([0x6a, 0xc9, 0x25, 0xfb]));
    expect(() => JWSettingsCodec.encodeTime(DateTime(2064)), throwsArgumentError);
    expect(() => JWSettingsCodec.encodeTime(DateTime(1999)), throwsArgumentError);
  });

  test('profile and daily-goal encoding follows Android V2 field packing', () {
    expect(
      JWSettingsCodec.encodeUserProfile(const JWUserProfile(
        isMale: true,
        age: 30,
        heightCentimeters: 170,
        weightKilograms: 65,
      )),
      Uint8List.fromList([0x9e, 0xaa, 0x10, 0x40]),
    );
    expect(JWSettingsCodec.encodeUint32(8000, 'steps'),
        Uint8List.fromList([0, 0, 0x1f, 0x40]));
    expect(JWSettingsCodec.encodeUint16(480, 'sleep'),
        Uint8List.fromList([0x01, 0xe0]));
  });

  test('profile accepts the V2 nine-bit half-centimetre height field', () {
    const profile = JWUserProfile(
      isMale: true,
      age: 30,
      heightCentimeters: 174,
      weightKilograms: 65,
    );
    expect(JWSettingsCodec.encodeUserProfile(profile),
        Uint8List.fromList([0x9e, 0xae, 0x10, 0x40]));
  });

  test('DND, sedentary reminder, and standard alarms round trip', () {
    const dnd = JWDoNotDisturb(
      enabled: true,
      schedule: JWTimeRange(
          startHour: 22, startMinute: 30, endHour: 7, endMinute: 15),
    );
    expect(JWSettingsCodec.decodeDoNotDisturb(JWSettingsCodec.encodeDoNotDisturb(dnd)), dnd);

    const sedentary = JWSedentaryReminder(
      enabled: true,
      thresholdMinutes: 60,
      notifyHour: 12,
      startHour: 9,
      endHour: 18,
      repeatDays: 0x1f,
    );
    expect(JWSettingsCodec.decodeSedentaryReminder(
        JWSettingsCodec.encodeSedentaryReminder(sedentary)), sedentary);

    final single = JWAlarm(
      id: 2,
      time: DateTime(2026, 11, 4, 7, 30),
      repeatDays: 0,
    );
    expect(
      JWSettingsCodec.decodeAlarms(JWSettingsCodec.encodeAlarms([single])),
      [single],
    );

    final repeating = JWAlarm(
      id: 0,
      time: DateTime(2026, 11, 6, 11, 17),
      repeatDays: 0x04,
    );
    final decodedRepeating =
        JWSettingsCodec.decodeAlarms(JWSettingsCodec.encodeAlarms([repeating])).single;
    expect(decodedRepeating.id, repeating.id);
    expect(decodedRepeating.repeatDays, repeating.repeatDays);
    expect(decodedRepeating.time.hour, 11);
    expect(decodedRepeating.time.minute, 17);
    expect(decodedRepeating.time.year, DateTime.now().year);
    expect(decodedRepeating.time.month, DateTime.now().month);
    expect(decodedRepeating.time.day, DateTime.now().day);

    final padded = Uint8List.fromList([
      ...JWSettingsCodec.encodeAlarms([single]),
      0,
      0,
      0,
      0,
      0,
    ]);
    expect(JWSettingsCodec.decodeAlarms(padded), [single]);

    final repeatHighBit = JWSettingsCodec.encodeAlarms([
      JWAlarm(
        id: 1,
        time: DateTime(2026, 11, 6, 8, 0),
        repeatDays: 0x04,
      ),
    ]);
    final withBit7 = Uint8List.fromList([...repeatHighBit]);
    withBit7[4] = withBit7[4] | 0x80;
    expect(
      JWSettingsCodec.decodeAlarms(withBit7).single.repeatDays,
      0x04,
    );

    final labeled = JWAlarm(
      id: 3,
      time: DateTime(2026, 11, 6, 11, 17),
      repeatDays: 0,
      enabled: true,
      label: '起床',
    );
    final labeledWrite = JWSettingsCodec.encodeAlarm2(labeled);
    final labeledRead = JWSettingsCodec.decodeAlarm2ReadChunk(
      Uint8List.fromList([...labeledWrite, 1, 1]),
    );
    expect(labeledRead.alarm, labeled);
  });
}
