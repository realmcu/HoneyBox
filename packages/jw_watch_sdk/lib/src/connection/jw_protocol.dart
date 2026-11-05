import 'dart:typed_data';

final class JWProtocolRequest {
  const JWProtocolRequest({
    required this.command,
    required this.key,
    required this.responseKey,
    this.responseCommand,
    this.value,
    this.replyTimeout = const Duration(seconds: 8),
  });

  final int command;
  final int key;
  final int? responseKey;
  final int? responseCommand;
  final Uint8List? value;
  final Duration replyTimeout;
}

abstract final class JWProtocolCommands {
  static const _settingsProbeTimeout = Duration(seconds: 5);
  static JWProtocolRequest functions() =>
      const JWProtocolRequest(command: 2, key: 0x36, responseKey: 0x37);
  static JWProtocolRequest factorySwitch() =>
      const JWProtocolRequest(command: 6, key: 0x3d, responseKey: 0x3e);
  static JWProtocolRequest login(Uint8List identity) =>
      JWProtocolRequest(command: 3, key: 3, responseKey: 4, value: identity);
  static JWProtocolRequest bind(Uint8List identity) =>
      JWProtocolRequest(command: 3, key: 1, responseKey: 2, value: identity);
  static JWProtocolRequest unbind() =>
      const JWProtocolRequest(command: 3, key: 5, responseKey: null);

  static JWProtocolRequest readLanguage() =>
      const JWProtocolRequest(command: 2, key: 0x4f, responseKey: 0x50);
  static JWProtocolRequest setLanguage(int value) => JWProtocolRequest(
      command: 2,
      key: 0x4e,
      responseKey: null,
      value: Uint8List.fromList([value]));

  static JWProtocolRequest readHourSystem() =>
      const JWProtocolRequest(command: 2, key: 0x42, responseKey: 0x43);
  static JWProtocolRequest setHourSystem(int value) => JWProtocolRequest(
      command: 2,
      key: 0x41,
      responseKey: null,
      value: Uint8List.fromList([value]));

  static JWProtocolRequest readUnitSystem() =>
      const JWProtocolRequest(command: 2, key: 0x45, responseKey: 0x46);
  static JWProtocolRequest setUnitSystem(int value) => JWProtocolRequest(
      command: 2,
      key: 0x44,
      responseKey: null,
      value: Uint8List.fromList([value]));

  static JWProtocolRequest setTime(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x01, responseKey: null, value: value);

  static JWProtocolRequest setUserProfile(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x10, responseKey: null, value: value);
  static JWProtocolRequest setStepGoal(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x05, responseKey: null, value: value);
  static JWProtocolRequest setSleepGoal(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x06, responseKey: null, value: value);
  static JWProtocolRequest setCalorieGoal(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x07, responseKey: null, value: value);

  static JWProtocolRequest readDateFormat() => const JWProtocolRequest(
      command: 2,
      key: 0x79,
      responseKey: 0x7a,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setDateFormat(int value) => _setting(0x78, value);
  static JWProtocolRequest readScreenLightDuration() => const JWProtocolRequest(
      command: 2,
      key: 0x4b,
      responseKey: 0x4c,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setScreenLightDuration(int value) =>
      _setting(0x4a, value);
  static JWProtocolRequest readScreenBrightness() => const JWProtocolRequest(
      command: 2,
      key: 0x54,
      responseKey: 0x55,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setScreenBrightness(int value) =>
      _setting(0x53, value);
  static JWProtocolRequest readHomePage() => const JWProtocolRequest(
      command: 2,
      key: 0x39,
      responseKey: 0x3a,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setHomePage(int value) => _setting(0x38, value);
  static JWProtocolRequest readTurnWristToWake() => const JWProtocolRequest(
      command: 2,
      key: 0x2b,
      responseKey: 0x2c,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setTurnWristToWake(bool value) =>
      _setting(0x2a, value ? 1 : 0);

  static JWProtocolRequest readDoNotDisturb() => const JWProtocolRequest(
      command: 2,
      key: 0x48,
      responseKey: 0x49,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setDoNotDisturb(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x47, responseKey: null, value: value);
  static JWProtocolRequest readSedentaryReminder() => const JWProtocolRequest(
      command: 2,
      key: 0x26,
      responseKey: 0x27,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setSedentaryReminder(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x21, responseKey: null, value: value);
  static JWProtocolRequest readAlarms() => const JWProtocolRequest(
      command: 2,
      key: 0x03,
      responseKey: 0x04,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setAlarms(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x02, responseKey: null, value: value);
  static JWProtocolRequest requestAlarms2() =>
      const JWProtocolRequest(command: 2, key: 0x66, responseKey: null);
  static JWProtocolRequest setAlarm2(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x65, responseKey: null, value: value);
  static const int alarms2ResponseKey = 0x67;

  static JWProtocolRequest _setting(int key, int value) => JWProtocolRequest(
      command: 2,
      key: key,
      responseKey: null,
      value: Uint8List.fromList([value]));
}

Uint8List encodeJWRequest(JWProtocolRequest request) {
  final value = request.value ?? Uint8List(0);
  if (value.length > 231) throw ArgumentError('JW value exceeds L2 limit');
  return Uint8List.fromList([
    request.command,
    0,
    request.key,
    value.length >> 8,
    value.length & 0xff,
    ...value,
  ]);
}

final class JWProtocolMessage {
  const JWProtocolMessage(this.command, this.key, this.value);
  final int command;
  final int key;
  final Uint8List value;
}

List<JWProtocolMessage> decodeJWMessages(Uint8List bytes) {
  if (bytes.length < 2 || bytes[1] != 0) {
    throw const FormatException('Invalid JW L2 header');
  }
  final result = <JWProtocolMessage>[];
  var offset = 2;
  while (offset < bytes.length) {
    if (offset + 3 > bytes.length) {
      throw const FormatException('Invalid JW L2 field header');
    }
    final key = bytes[offset];
    final length = ((bytes[offset + 1] & 1) << 8) | bytes[offset + 2];
    offset += 3;
    if (length > 231 || offset + length > bytes.length) {
      throw const FormatException('Invalid JW L2 field length');
    }
    result.add(JWProtocolMessage(bytes[0], key,
        Uint8List.fromList(bytes.sublist(offset, offset + length))));
    offset += length;
  }
  return result;
}
