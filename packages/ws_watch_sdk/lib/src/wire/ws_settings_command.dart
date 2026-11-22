import 'dart:typed_data';

import 'ws_l2_message.dart';

/// Command `0x02` settings ([WS protocol 0x02-settings.rst]).
abstract final class WSSettingsCommand {
  static const int command = 0x02;
  static const int version = 0;

  static const int opcodeSet = 0x00;
  static const int opcodeRead = 0x01;
  static const int opcodeReadReply = 0x02;
  static const int opcodeNotification = 0x03;
  static const int opcodeReset = 0x04;
  static const int opcodeAdd = 0x05;
  static const int opcodeDelete = 0x06;
  static const int opcodeModify = 0x07;

  static const int keyTime = 0x01;
  static const int keyPhoneSystem = 0x02;
  static const int keyLanguage = 0x03;
  static const int keyDisplayFormat = 0x04;
  static const int keyPowerSaving = 0x05;
  static const int keyUserProfile = 0x10;
  static const int keyGoals = 0x11;
  static const int keyWrist = 0x12;
  static const int keyFemaleHealth = 0x13;
  static const int keyBrightness = 0x20;
  static const int keyScreenDuration = 0x21;
  static const int keyRaiseToWake = 0x22;
  static const int keyDoNotDisturb = 0x23;
  static const int keyWatchFace = 0x24;
  static const int keyHealthDisplay = 0x25;
  static const int keyDeviceInfo = 0x30;
  static const int keyCapabilities = 0x31;
  static const int keySupportedLanguages = 0x33;
  static const int keyDeviceControl = 0x34;
  static const int keyHeartRateAuto = 0x40;
  static const int keyHeartRateAlarm = 0x41;
  static const int keyHrvAuto = 0x44;
  static const int keyHrvAlarm = 0x45;
  static const int keyBloodPressureAuto = 0x48;
  static const int keyBloodPressureAlarm = 0x49;
  static const int keyBloodPressureUnit = 0x4A;
  static const int keyBloodGlucoseAuto = 0x4C;
  static const int keyBloodGlucoseAlarm = 0x4D;
  static const int keyBloodGlucoseUnit = 0x4E;
  static const int keyBloodOxygenAuto = 0x50;
  static const int keyBloodOxygenAlarm = 0x51;
  static const int keyPressureAuto = 0x54;
  static const int keyPressureAlarm = 0x55;
  static const int keyTemperatureAuto = 0x58;
  static const int keyTemperatureAlarm = 0x59;
  static const int keyTemperatureUnit = 0x5A;
  static const int keyHeatStressAuto = 0x5C;
  static const int keyAlarms = 0x60;
  static const int keyIntervalReminder = 0x61;
  static const int keyNotificationSwitches = 0x80;
  static const int keyWeather = 0x90;
  static const int keyContacts = 0x91;
  static const int keySosContacts = 0x92;

  static WSL2Message setPhoneSystem(int system) {
    if (system != 1 && system != 2) {
      throw ArgumentError.value(
          system, 'system', 'expected 1 (iOS) or 2 (Android)');
    }
    return WSL2Message(
      command: command,
      version: version,
      key: keyPhoneSystem,
      value: Uint8List.fromList([opcodeSet, system]),
    );
  }

  static WSL2Message setTimeUnix(int wallSeconds) {
    final data = ByteData(5);
    data.setUint8(0, opcodeSet);
    data.setUint32(1, wallSeconds);
    return WSL2Message(
      command: command,
      version: version,
      key: keyTime,
      value: data.buffer.asUint8List(),
    );
  }

  static WSL2Message readLanguage() => WSL2Message(
        command: command,
        version: version,
        key: keyLanguage,
        value: Uint8List.fromList([opcodeRead]),
      );

  static int decodeLanguageCode(WSL2Message reply) {
    if (reply.command != command ||
        reply.key != keyLanguage ||
        reply.value.length != 2 ||
        reply.value[0] != opcodeReadReply) {
      throw FormatException('unexpected language read reply');
    }
    return reply.value[1];
  }

  static bool isLanguageReadReply(WSL2Message message) =>
      message.command == command &&
      message.key == keyLanguage &&
      message.value.isNotEmpty &&
      message.value[0] == opcodeReadReply;

  static WSL2Message readKey(int key) => WSL2Message(
        command: command,
        version: version,
        key: key,
        value: Uint8List.fromList([opcodeRead]),
      );

  static WSL2Message setKey(int key, Uint8List body) => WSL2Message(
        command: command,
        version: version,
        key: key,
        value: Uint8List.fromList([opcodeSet, ...body]),
      );

  static WSL2Message operate(int key, int opcode, [Uint8List? body]) =>
      WSL2Message(
        command: command,
        version: version,
        key: key,
        value: Uint8List.fromList([opcode, ...?body]),
      );

  static bool isReadReplyForKey(WSL2Message message, int key) =>
      message.command == command &&
      message.key == key &&
      message.value.isNotEmpty &&
      message.value[0] == opcodeReadReply;
}
