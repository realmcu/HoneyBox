import 'dart:async';
import 'dart:typed_data';

import '../connection/ws_link.dart';
import '../debug/ws_debug_log.dart';
import '../measure/ws_measure_models.dart';
import '../wire/ws_health_monitor_codec.dart';
import '../wire/ws_settings_command.dart';
import '../settings/ws_setting_codecs.dart';
import '../settings/ws_settings_models.dart';
import '../wire/ws_l2_message.dart';
import '../wire/ws_binary.dart';

final class WSSettings {
  WSSettings(this._link, {Duration replyTimeout = const Duration(seconds: 5)})
      : _replyTimeout = replyTimeout {
    _incoming = _link.incoming.listen((message) {
      if (message.command != WSSettingsCommand.command ||
          message.version != WSSettingsCommand.version ||
          message.value.isEmpty ||
          message.value[0] != WSSettingsCommand.opcodeNotification) return;
      _events.add(WSSettingEvent(
        key: message.key,
        opcode: message.value[0],
        body: Uint8List.sublistView(message.value, 1),
      ));
    });
  }

  final WSLink _link;
  final Duration _replyTimeout;
  final _events = StreamController<WSSettingEvent>.broadcast(sync: true);
  late final StreamSubscription<WSL2Message> _incoming;

  Stream<WSSettingEvent> get events => _events.stream;

  Future<Uint8List> readRaw(int key, {Uint8List? arguments}) async {
    final reply = await _link.requestWhere(
      WSSettingsCommand.operate(key, WSSettingsCommand.opcodeRead, arguments),
      matches: (m) => WSSettingsCommand.isReadReplyForKey(m, key),
      timeout: _replyTimeout,
    );
    return Uint8List.fromList(reply.value.sublist(1));
  }

  Future<void> writeRaw(int key, int opcode, [Uint8List? body]) =>
      _link.send(WSSettingsCommand.operate(key, opcode, body));

  Future<T> read<T>(WSSettingCodec<T> codec, {Uint8List? arguments}) async =>
      codec.decode(await readRaw(codec.key, arguments: arguments));

  Future<void> set<T>(WSSettingCodec<T> codec, T value) =>
      writeRaw(codec.key, WSSettingsCommand.opcodeSet, codec.encode(value));

  Future<void> reset(int key) => writeRaw(key, WSSettingsCommand.opcodeReset);
  Future<void> add(int key, Uint8List body) =>
      writeRaw(key, WSSettingsCommand.opcodeAdd, body);
  Future<void> delete(int key, Uint8List body) =>
      writeRaw(key, WSSettingsCommand.opcodeDelete, body);
  Future<void> modify(int key, Uint8List body) =>
      writeRaw(key, WSSettingsCommand.opcodeModify, body);

  Future<void> setPhoneSystem(int system) =>
      _link.send(WSSettingsCommand.setPhoneSystem(system));

  Future<void> setTimeUnix(int wallSeconds) =>
      _link.send(WSSettingsCommand.setTimeUnix(wallSeconds));

  Future<int> readLanguage() async {
    final reply = await _link.requestWhere(
      WSSettingsCommand.readLanguage(),
      matches: WSSettingsCommand.isLanguageReadReply,
      timeout: _replyTimeout,
    );
    return WSSettingsCommand.decodeLanguageCode(reply);
  }

  Future<void> setLanguage(int language) =>
      set(WSSettingCodecs.language, language);
  Future<WSDisplayFormat> readDisplayFormat() =>
      read(WSSettingCodecs.displayFormat);
  Future<void> setDisplayFormat(WSDisplayFormat value) =>
      set(WSSettingCodecs.displayFormat, value);
  Future<bool> readPowerSaving() => read(WSSettingCodecs.powerSaving);
  Future<void> setPowerSaving(bool value) =>
      set(WSSettingCodecs.powerSaving, value);
  Future<void> setUserProfile(WSUserProfile value) =>
      set(WSSettingCodecs.userProfile, value);
  Future<WSActivityGoals> readGoals() => read(WSSettingCodecs.goals);
  Future<void> setGoals(WSActivityGoals value) =>
      set(WSSettingCodecs.goals, value);
  Future<int> readWrist() => read(WSSettingCodecs.wrist);
  Future<void> setWrist(int value) => set(WSSettingCodecs.wrist, value);
  Future<void> setFemaleHealth(WSFemaleHealthSetting value) =>
      set(WSSettingCodecs.femaleHealth, value);
  Future<int> readBrightness() => read(WSSettingCodecs.brightness);
  Future<void> setBrightness(int value) =>
      set(WSSettingCodecs.brightness, value);
  Future<int> readScreenOnSeconds() => read(WSSettingCodecs.screenOnSeconds);
  Future<void> setScreenOnSeconds(int value) =>
      set(WSSettingCodecs.screenOnSeconds, value);
  Future<WSTimeWindowSetting> readRaiseToWake() =>
      read(WSSettingCodecs.raiseToWake);
  Future<void> setRaiseToWake(WSTimeWindowSetting value) =>
      set(WSSettingCodecs.raiseToWake, value);
  Future<WSTimeWindowSetting> readDoNotDisturb() =>
      read(WSSettingCodecs.doNotDisturb);
  Future<void> setDoNotDisturb(WSTimeWindowSetting value) =>
      set(WSSettingCodecs.doNotDisturb, value);
  Future<int> readHealthDisplayBits() => read(WSSettingCodecs.healthDisplay);
  Future<void> setHealthDisplayBits(int value) =>
      set(WSSettingCodecs.healthDisplay, value);
  Future<List<int>> readSupportedLanguages() =>
      read(WSSettingCodecs.supportedLanguages);
  Future<WSDeviceDetails> readDeviceDetails() =>
      read(WSSettingCodecs.deviceDetails);
  Future<void> controlDevice(int action) => writeRaw(
        WSSettingsCommand.keyDeviceControl,
        WSSettingsCommand.opcodeSet,
        Uint8List.fromList([action]),
      );

  Future<WSHealthAlarmSetting> readHealthAlarm(int key) =>
      read(WSSettingCodecs.healthAlarm(key));
  Future<void> setHealthAlarm(int key, WSHealthAlarmSetting value) =>
      set(WSSettingCodecs.healthAlarm(key), value);

  Future<WSHealthAlarmSetting> readHeartRateAlarm() =>
      readHealthAlarm(WSSettingsCommand.keyHeartRateAlarm);
  Future<void> setHeartRateAlarm(WSHealthAlarmSetting value) =>
      setHealthAlarm(WSSettingsCommand.keyHeartRateAlarm, value);
  Future<WSHealthAlarmSetting> readHrvAlarm() =>
      readHealthAlarm(WSSettingsCommand.keyHrvAlarm);
  Future<void> setHrvAlarm(WSHealthAlarmSetting value) =>
      setHealthAlarm(WSSettingsCommand.keyHrvAlarm, value);
  Future<WSHealthAlarmSetting> readBloodPressureAlarm() =>
      readHealthAlarm(WSSettingsCommand.keyBloodPressureAlarm);
  Future<void> setBloodPressureAlarm(WSHealthAlarmSetting value) =>
      setHealthAlarm(WSSettingsCommand.keyBloodPressureAlarm, value);
  Future<WSHealthAlarmSetting> readBloodGlucoseAlarm() =>
      readHealthAlarm(WSSettingsCommand.keyBloodGlucoseAlarm);
  Future<void> setBloodGlucoseAlarm(WSHealthAlarmSetting value) =>
      setHealthAlarm(WSSettingsCommand.keyBloodGlucoseAlarm, value);
  Future<WSHealthAlarmSetting> readSpO2Alarm() =>
      readHealthAlarm(WSSettingsCommand.keyBloodOxygenAlarm);
  Future<void> setSpO2Alarm(WSHealthAlarmSetting value) =>
      setHealthAlarm(WSSettingsCommand.keyBloodOxygenAlarm, value);
  Future<WSHealthAlarmSetting> readPressureAlarm() =>
      readHealthAlarm(WSSettingsCommand.keyPressureAlarm);
  Future<void> setPressureAlarm(WSHealthAlarmSetting value) =>
      setHealthAlarm(WSSettingsCommand.keyPressureAlarm, value);
  Future<WSHealthAlarmSetting> readTemperatureAlarm() =>
      readHealthAlarm(WSSettingsCommand.keyTemperatureAlarm);
  Future<void> setTemperatureAlarm(WSHealthAlarmSetting value) =>
      setHealthAlarm(WSSettingsCommand.keyTemperatureAlarm, value);

  Future<WSBloodPressureUnit> readBloodPressureUnit() async => _enumValue(
      WSBloodPressureUnit.values,
      await read(WSSettingCodecs.bloodPressureUnit),
      'blood pressure unit');
  Future<void> setBloodPressureUnit(WSBloodPressureUnit value) =>
      set(WSSettingCodecs.bloodPressureUnit, value.index);
  Future<WSBloodGlucoseUnit> readBloodGlucoseUnit() async => _enumValue(
      WSBloodGlucoseUnit.values,
      await read(WSSettingCodecs.bloodGlucoseUnit),
      'blood glucose unit');
  Future<void> setBloodGlucoseUnit(WSBloodGlucoseUnit value) =>
      set(WSSettingCodecs.bloodGlucoseUnit, value.index);
  Future<WSTemperatureUnit> readTemperatureUnit() async => _enumValue(
      WSTemperatureUnit.values,
      await read(WSSettingCodecs.temperatureUnit),
      'temperature unit');
  Future<void> setTemperatureUnit(WSTemperatureUnit value) =>
      set(WSSettingCodecs.temperatureUnit, value.index);

  Future<WSIntervalReminderSetting> readIntervalReminder(int type) => readRaw(
        WSSettingsCommand.keyIntervalReminder,
        arguments: Uint8List.fromList([type]),
      ).then(WSSettingCodecs.decodeIntervalReminder);
  Future<void> setIntervalReminder(WSIntervalReminderSetting value) => writeRaw(
        WSSettingsCommand.keyIntervalReminder,
        WSSettingsCommand.opcodeSet,
        WSSettingCodecs.encodeIntervalReminder(value),
      );
  Future<Uint8List> readNotificationSwitches() =>
      read(WSSettingCodecs.notificationSwitches);
  Future<void> setNotificationSwitches(Uint8List bits) =>
      set(WSSettingCodecs.notificationSwitches, bits);
  Future<void> setWeather(WSWeatherSetting value) => writeRaw(
        WSSettingsCommand.keyWeather,
        WSSettingsCommand.opcodeSet,
        WSSettingCodecs.encodeWeather(value),
      );
  Future<void> clearWeather() => reset(WSSettingsCommand.keyWeather);

  Future<WSListPage<WSAlarmSetting>> readAlarms() async {
    final body = await readRaw(WSSettingsCommand.keyAlarms);
    return _decodeList(body, WSSettingCodecs.decodeAlarm);
  }

  Future<void> addAlarm(WSAlarmSetting value) =>
      add(WSSettingsCommand.keyAlarms, WSSettingCodecs.encodeAlarm(value));
  Future<void> modifyAlarm(WSAlarmSetting value) =>
      modify(WSSettingsCommand.keyAlarms, WSSettingCodecs.encodeAlarm(value));
  Future<void> deleteAlarm(WSAlarmSetting value) =>
      delete(WSSettingsCommand.keyAlarms, WSSettingCodecs.encodeAlarm(value));
  Future<void> clearAlarms() => reset(WSSettingsCommand.keyAlarms);

  Future<WSListPage<WSContactSetting>> readContacts([int startSlot = 0]) async {
    final body = await readRaw(
      WSSettingsCommand.keyContacts,
      arguments: Uint8List.fromList([startSlot]),
    );
    if (body.length < 3) throw const FormatException('contacts page too short');
    return _decodeList(body, WSSettingCodecs.decodeContact, paged: true);
  }

  Future<WSListPage<WSContactSetting>> readSosContacts() async => _decodeList(
      await readRaw(WSSettingsCommand.keySosContacts),
      WSSettingCodecs.decodeContact);
  Future<void> addContact(WSContactSetting value, {bool sos = false}) => add(
        sos ? WSSettingsCommand.keySosContacts : WSSettingsCommand.keyContacts,
        WSSettingCodecs.encodeContact(value),
      );
  Future<void> modifyContact(WSContactSetting value, {bool sos = false}) =>
      modify(
        sos ? WSSettingsCommand.keySosContacts : WSSettingsCommand.keyContacts,
        WSSettingCodecs.encodeContact(value),
      );
  Future<void> deleteContact(WSContactSetting value, {bool sos = false}) =>
      delete(
        sos ? WSSettingsCommand.keySosContacts : WSSettingsCommand.keyContacts,
        WSSettingCodecs.encodeContact(value),
      );
  Future<void> clearContacts({bool sos = false}) => reset(
      sos ? WSSettingsCommand.keySosContacts : WSSettingsCommand.keyContacts);

  WSListPage<T> _decodeList<T>(
    Uint8List body,
    T Function(Uint8List) decode, {
    bool paged = false,
  }) {
    final header = paged ? 3 : 2;
    if (body.length < header)
      throw const FormatException('list reply too short');
    final capacity = body[0];
    final next = paged ? body[1] : null;
    final count = body[paged ? 2 : 1];
    var offset = header;
    final items = <T>[];
    for (var i = 0; i < count; i++) {
      if (offset >= body.length)
        throw const FormatException('truncated list item');
      final length = body[offset++];
      if (offset + length > body.length)
        throw const FormatException('list item overflow');
      items.add(decode(Uint8List.sublistView(body, offset, offset + length)));
      offset += length;
    }
    return WSListPage(
        capacity: capacity, items: List.unmodifiable(items), nextSlot: next);
  }

  Future<WSHeartRateHighAlarm> readHeartRateHighAlarm() async {
    WSWatchDebugLog.apiIn('WSSettings.readHeartRateHighAlarm');
    final reply = await _link.request(
      WSSettingsCommand.readKey(WSHealthMonitorCodec.keyHeartRateAlarm),
      replyKey: WSHealthMonitorCodec.keyHeartRateAlarm,
      timeout: _replyTimeout,
    );
    return WSHealthMonitorCodec.decodeHeartRateHighAlarm(
      WSHealthMonitorCodec.extractSettingBody(reply),
    );
  }

  Future<void> setHeartRateHighAlarm(WSHeartRateHighAlarm alarm) async {
    WSWatchDebugLog.apiIn('WSSettings.setHeartRateHighAlarm');
    final previous =
        await readHealthAlarm(WSHealthMonitorCodec.keyHeartRateAlarm);
    await setHealthAlarm(
      WSHealthMonitorCodec.keyHeartRateAlarm,
      WSHealthAlarmSetting(
        highEnabled: alarm.enabled,
        highThreshold: WSBinary.u16(alarm.thresholdBpm),
        lowEnabled: previous.lowEnabled,
        lowThreshold: previous.lowThreshold,
        startHour: previous.startHour,
        startMinute: previous.startMinute,
        endHour: previous.endHour,
        endMinute: previous.endMinute,
      ),
    );
  }

  Future<WSSpO2LowAlarm> readSpO2LowAlarm() async {
    WSWatchDebugLog.apiIn('WSSettings.readSpO2LowAlarm');
    final reply = await _link.request(
      WSSettingsCommand.readKey(WSHealthMonitorCodec.keySpO2Alarm),
      replyKey: WSHealthMonitorCodec.keySpO2Alarm,
      timeout: _replyTimeout,
    );
    return WSHealthMonitorCodec.decodeSpO2LowAlarm(
      WSHealthMonitorCodec.extractSettingBody(reply),
    );
  }

  Future<void> setSpO2LowAlarm(WSSpO2LowAlarm alarm) async {
    WSWatchDebugLog.apiIn('WSSettings.setSpO2LowAlarm');
    final previous = await readHealthAlarm(WSHealthMonitorCodec.keySpO2Alarm);
    await setHealthAlarm(
      WSHealthMonitorCodec.keySpO2Alarm,
      WSHealthAlarmSetting(
        highEnabled: previous.highEnabled,
        highThreshold: previous.highThreshold,
        lowEnabled: alarm.enabled,
        lowThreshold: WSBinary.u16(alarm.thresholdPercent),
        startHour: previous.startHour,
        startMinute: previous.startMinute,
        endHour: previous.endHour,
        endMinute: previous.endMinute,
      ),
    );
  }

  Future<void> dispose() async {
    await _incoming.cancel();
    await _events.close();
  }

  T _enumValue<T>(List<T> values, int index, String label) {
    if (index < 0 || index >= values.length) {
      throw FormatException('invalid $label: $index');
    }
    return values[index];
  }
}
