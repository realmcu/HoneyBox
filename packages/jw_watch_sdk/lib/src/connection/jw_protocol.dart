import 'dart:typed_data';

final class JWProtocolRequest {
  const JWProtocolRequest({
    required this.command,
    required this.key,
    required this.responseKey,
    this.responseCommand,
    this.value,
    this.replyTimeout = const Duration(seconds: 8),
    this.l2Version = 0,
  });

  final int command;
  final int key;
  final int? responseKey;
  final int? responseCommand;
  final Uint8List? value;
  final Duration replyTimeout;
  /// L2 header version byte; HL private protocol uses `0`.
  final int l2Version;
}

abstract final class JWProtocolCommands {
  static const _settingsProbeTimeout = Duration(seconds: 5);
  static JWProtocolRequest functions() =>
      const JWProtocolRequest(command: 2, key: 0x36, responseKey: 0x37);
  static JWProtocolRequest factorySwitch() =>
      const JWProtocolRequest(command: 6, key: 0x3d, responseKey: 0x3e);

  /// HL §5.FA data-sync reset: cmd `0x05`, key `0xFA`, empty value.
  ///
  /// Android `WristbandManager.setFullSync` / `ApplicationLayer.SettingFullSync`.
  /// Not factory `0x06/0xF7` (HISTORY address probe / `FACCmdRequestHistoryIndex`).
  static JWProtocolRequest resetHistorySyncMarkers() =>
      const JWProtocolRequest(command: 5, key: 0xfa, responseKey: null);

  /// HL §6.FC factory RESET: cmd `0x06`, key `0xFC`, empty value.
  ///
  /// Erases device-retained data; firmware typically powers off / reboots.
  /// Android `WristbandManager.sendResetRequest` / `FACCmdRequestReset`.
  static JWProtocolRequest clearDeviceData() =>
      const JWProtocolRequest(command: 6, key: 0xfc, responseKey: null);
  static JWProtocolRequest login(Uint8List identity) =>
      JWProtocolRequest(command: 3, key: 3, responseKey: 4, value: identity);
  static JWProtocolRequest bind(Uint8List identity) =>
      JWProtocolRequest(command: 3, key: 1, responseKey: 2, value: identity);
  static JWProtocolRequest unbind() =>
      const JWProtocolRequest(command: 3, key: 5, responseKey: null);

  /// HL §5.1 request data: cmd `0x05`, key `0x01`, empty value. Device replies
  /// with §5.7 START (`0x07`), payload keys, then §5.8 END (`0x08`).
  static JWProtocolRequest startHistorySync() =>
      const JWProtocolRequest(command: 5, key: 1, responseKey: null);

  /// Confirms a persisted 0x05 history round (key `0x1c`, Android V2).
  static JWProtocolRequest confirmHistorySync() =>
      const JWProtocolRequest(command: 5, key: 0x1c, responseKey: null);

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

  /// Heat-stress reminder window: set `0x86`, request `0x87`, response `0x88`.
  static JWProtocolRequest readHeatStressReminder() => const JWProtocolRequest(
      command: 2,
      key: 0x87,
      responseKey: 0x88,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setHeatStressReminder(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x86, responseKey: null, value: value);

  /// High heart-rate alarm: set `0x75`, request `0x76`, response `0x77`.
  static JWProtocolRequest readHighHeartRateReminder() =>
      const JWProtocolRequest(
          command: 2,
          key: 0x76,
          responseKey: 0x77,
          replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setHighHeartRateReminder(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x75, responseKey: null, value: value);
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

  /// Notify switches: request `0x28` → response `0x29`; bulk set `0x2D`.
  static JWProtocolRequest readNotifySettings() => const JWProtocolRequest(
      command: 2,
      key: 0x28,
      responseKey: 0x29,
      replyTimeout: _settingsProbeTimeout);
  static JWProtocolRequest setNotifySettings(Uint8List value) =>
      JWProtocolRequest(command: 2, key: 0x2d, responseKey: null, value: value);
  static JWProtocolRequest setNotifyChannel(int mode) =>
      _setting(0x25, mode);

  /// Incoming call alert (`cmd 0x04` / `key 0x01`).
  static JWProtocolRequest sendIncomingCall(Uint8List value) =>
      JWProtocolRequest(command: 4, key: 0x01, responseKey: null, value: value);

  /// App message alert (`cmd 0x04` / `key 0x04`).
  static JWProtocolRequest sendNotifyMessage(Uint8List value) =>
      JWProtocolRequest(command: 4, key: 0x04, responseKey: null, value: value);

  static JWProtocolRequest _setting(int key, int value) => JWProtocolRequest(
      command: 2,
      key: key,
      responseKey: null,
      value: Uint8List.fromList([value]));
}

Uint8List encodeJWRequest(JWProtocolRequest request) {
  final value = request.value ?? Uint8List(0);
  if (value.length > 231) throw ArgumentError('JW value exceeds L2 limit');
  if (request.l2Version != 0) {
    throw ArgumentError('JW HL L2 version must be 0');
  }
  return Uint8List.fromList([
    request.command,
    request.l2Version,
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
  if (bytes.length < 2) {
    throw const FormatException('Invalid JW L2 header');
  }
  final version = bytes[1];
  if (version != 0) {
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
