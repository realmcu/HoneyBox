import 'dart:convert';
import 'dart:typed_data';

import '../wire/ws_binary.dart';
import '../wire/ws_settings_command.dart';
import 'ws_settings_models.dart';

abstract final class WSSettingCodecs {
  static WSSettingCodec<int> uint8(int key) => WSSettingCodec(
        key: key,
        encode: (v) {
          WSBinary.requireRange(v, 0, 255, 'value');
          return Uint8List.fromList([v]);
        },
        decode: (v) {
          WSBinary.requireLength(v, 1, 'uint8 setting');
          return v[0];
        },
      );

  static WSSettingCodec<bool> boolean(int key) => WSSettingCodec(
        key: key,
        encode: (v) => Uint8List.fromList([v ? 1 : 0]),
        decode: (v) {
          WSBinary.requireLength(v, 1, 'boolean setting');
          return v[0] == 1;
        },
      );

  static WSSettingCodec<Uint8List> bytes(int key, {int? length}) =>
      WSSettingCodec(
        key: key,
        encode: (v) {
          if (length != null && v.length != length)
            throw ArgumentError('expected $length bytes');
          return Uint8List.fromList(v);
        },
        decode: (v) {
          if (length != null && v.length < length)
            throw FormatException('expected $length bytes');
          return Uint8List.fromList(v);
        },
      );

  static final language = uint8(WSSettingsCommand.keyLanguage);
  static final powerSaving = boolean(WSSettingsCommand.keyPowerSaving);
  static final wrist = uint8(WSSettingsCommand.keyWrist);
  static final brightness = uint8(WSSettingsCommand.keyBrightness);
  static final screenOnSeconds = uint8(WSSettingsCommand.keyScreenDuration);
  static final bloodPressureUnit =
      uint8(WSSettingsCommand.keyBloodPressureUnit);
  static final bloodGlucoseUnit = uint8(WSSettingsCommand.keyBloodGlucoseUnit);
  static final temperatureUnit = uint8(WSSettingsCommand.keyTemperatureUnit);
  static final capabilities =
      bytes(WSSettingsCommand.keyCapabilities, length: 16);
  static final notificationSwitches =
      bytes(WSSettingsCommand.keyNotificationSwitches, length: 16);

  static final displayFormat = WSSettingCodec<WSDisplayFormat>(
    key: WSSettingsCommand.keyDisplayFormat,
    encode: (v) => Uint8List.fromList([
      v.hour12 ? 1 : 0,
      v.dayFirst ? 1 : 0,
      v.imperialDistance ? 1 : 0,
      v.pounds ? 1 : 0,
    ]),
    decode: (v) {
      WSBinary.requireLength(v, 4, 'display format');
      return WSDisplayFormat(
        hour12: v[0] == 1,
        dayFirst: v[1] == 1,
        imperialDistance: v[2] == 1,
        pounds: v[3] == 1,
      );
    },
  );

  static final userProfile = WSSettingCodec<WSUserProfile>(
    key: WSSettingsCommand.keyUserProfile,
    encode: (v) => Uint8List.fromList([
      v.gender,
      ...WSBinary.u16(v.birthYear),
      v.birthMonth,
      v.birthDay,
      ...WSBinary.u16(v.heightTenthCm),
      ...WSBinary.u16(v.weightTenthKg),
    ]),
    decode: (v) {
      WSBinary.requireLength(v, 9, 'user profile');
      return WSUserProfile(
        gender: v[0],
        birthYear: WSBinary.readU16(v, 1),
        birthMonth: v[3],
        birthDay: v[4],
        heightTenthCm: WSBinary.readU16(v, 5),
        weightTenthKg: WSBinary.readU16(v, 7),
      );
    },
  );

  static final goals = WSSettingCodec<WSActivityGoals>(
    key: WSSettingsCommand.keyGoals,
    encode: (v) => Uint8List.fromList([
      ...WSBinary.u32(v.steps),
      ...WSBinary.u16(v.caloriesKcal),
      ...WSBinary.u16(v.sleepMinutes),
      ...WSBinary.u32(v.distanceMeters),
      ...WSBinary.u16(v.activeMinutes),
    ]),
    decode: (v) {
      WSBinary.requireLength(v, 14, 'goals');
      return WSActivityGoals(
        steps: WSBinary.readU32(v, 0),
        caloriesKcal: WSBinary.readU16(v, 4),
        sleepMinutes: WSBinary.readU16(v, 6),
        distanceMeters: WSBinary.readU32(v, 8),
        activeMinutes: WSBinary.readU16(v, 12),
      );
    },
  );

  static final femaleHealth = WSSettingCodec<WSFemaleHealthSetting>(
    key: WSSettingsCommand.keyFemaleHealth,
    encode: (v) => Uint8List.fromList([
      v.enabled ? 1 : 0,
      v.cycleDays,
      v.periodDays,
      ...WSBinary.u16(v.lastPeriodYear),
      v.lastPeriodMonth,
      v.lastPeriodDay,
      v.reminderBits,
      v.reminderHour,
      v.reminderMinute,
    ]),
    decode: (v) {
      WSBinary.requireLength(v, 10, 'female health');
      return WSFemaleHealthSetting(
        enabled: v[0] == 1,
        cycleDays: v[1],
        periodDays: v[2],
        lastPeriodYear: WSBinary.readU16(v, 3),
        lastPeriodMonth: v[5],
        lastPeriodDay: v[6],
        reminderBits: v[7],
        reminderHour: v[8],
        reminderMinute: v[9],
      );
    },
  );

  static WSSettingCodec<WSTimeWindowSetting> timeWindow(int key) =>
      WSSettingCodec(
        key: key,
        encode: (v) => Uint8List.fromList([
          v.enabled ? 1 : 0,
          v.startHour,
          v.startMinute,
          v.endHour,
          v.endMinute,
        ]),
        decode: (v) {
          WSBinary.requireLength(v, 5, 'time window');
          return WSTimeWindowSetting(
            enabled: v[0] == 1,
            startHour: v[1],
            startMinute: v[2],
            endHour: v[3],
            endMinute: v[4],
          );
        },
      );

  static final raiseToWake = timeWindow(WSSettingsCommand.keyRaiseToWake);
  static final doNotDisturb = timeWindow(WSSettingsCommand.keyDoNotDisturb);

  static final healthDisplay = WSSettingCodec<int>(
    key: WSSettingsCommand.keyHealthDisplay,
    encode: WSBinary.u32,
    decode: (v) {
      WSBinary.requireLength(v, 4, 'health display');
      return WSBinary.readU32(v, 0);
    },
  );

  static final supportedLanguages = WSSettingCodec<List<int>>(
    key: WSSettingsCommand.keySupportedLanguages,
    encode: (_) => throw UnsupportedError('supported languages is read-only'),
    decode: (v) {
      WSBinary.requireLength(v, 1, 'supported languages');
      if (v.length < 1 + v[0])
        throw const FormatException('truncated languages');
      return List.unmodifiable(v.sublist(1, 1 + v[0]));
    },
  );

  static final deviceDetails = WSSettingCodec<WSDeviceDetails>(
    key: WSSettingsCommand.keyDeviceInfo,
    encode: (_) => throw UnsupportedError('device info is read-only'),
    decode: (v) {
      WSBinary.requireLength(v, 17, 'device info');
      final serialLength = v[16];
      if (v.length < 17 + serialLength)
        throw const FormatException('truncated serial number');
      return WSDeviceDetails(
        modelId: WSBinary.readU16(v, 0),
        firmwareMajor: v[2],
        firmwareMinor: v[3],
        firmwareRevision: v[4],
        firmwareBuild: WSBinary.readU16(v, 5),
        protocolVersion: v[7],
        hardwareVersion: v[8],
        platform: v[9],
        mac: Uint8List.fromList(v.sublist(10, 16)),
        serialNumber: ascii.decode(v.sublist(17, 17 + serialLength)),
      );
    },
  );

  static Uint8List encodeHealthAlarm(WSHealthAlarmSetting v) =>
      Uint8List.fromList([
        v.highEnabled ? 1 : 0,
        ...v.highThreshold,
        v.lowEnabled ? 1 : 0,
        ...v.lowThreshold,
        v.startHour,
        v.startMinute,
        v.endHour,
        v.endMinute,
      ]);

  static WSHealthAlarmSetting decodeHealthAlarm(Uint8List v) {
    WSBinary.requireLength(v, 10, 'health alarm');
    return WSHealthAlarmSetting(
      highEnabled: v[0] == 1,
      highThreshold: Uint8List.sublistView(v, 1, 3),
      lowEnabled: v[3] == 1,
      lowThreshold: Uint8List.sublistView(v, 4, 6),
      startHour: v[6],
      startMinute: v[7],
      endHour: v[8],
      endMinute: v[9],
    );
  }

  static WSSettingCodec<WSHealthAlarmSetting> healthAlarm(int key) =>
      WSSettingCodec(
          key: key, encode: encodeHealthAlarm, decode: decodeHealthAlarm);

  static Uint8List encodeAlarm(WSAlarmSetting v) {
    final label = WSBinary.utf8Bytes(v.label, maxBytes: 32);
    return Uint8List.fromList([
      v.slot,
      v.enabled ? 1 : 0,
      v.hour,
      v.minute,
      v.repeatBits,
      label.length,
      ...label,
    ]);
  }

  static WSAlarmSetting decodeAlarm(Uint8List v) {
    WSBinary.requireLength(v, 6, 'alarm');
    final len = v[5];
    if (v.length < 6 + len)
      throw const FormatException('truncated alarm label');
    return WSAlarmSetting(
      slot: v[0],
      enabled: v[1] == 1,
      hour: v[2],
      minute: v[3],
      repeatBits: v[4],
      label: utf8.decode(v.sublist(6, 6 + len)),
    );
  }

  static Uint8List encodeIntervalReminder(WSIntervalReminderSetting v) =>
      Uint8List.fromList([
        v.type,
        v.enabled ? 1 : 0,
        v.startHour,
        v.startMinute,
        v.endHour,
        v.endMinute,
        ...WSBinary.u16(v.intervalMinutes),
      ]);

  static WSIntervalReminderSetting decodeIntervalReminder(Uint8List v) {
    WSBinary.requireLength(v, 8, 'interval reminder');
    return WSIntervalReminderSetting(
      type: v[0],
      enabled: v[1] == 1,
      startHour: v[2],
      startMinute: v[3],
      endHour: v[4],
      endMinute: v[5],
      intervalMinutes: WSBinary.readU16(v, 6),
    );
  }

  static Uint8List encodeContact(WSContactSetting v) {
    final name = WSBinary.utf8Bytes(v.name, maxBytes: 32);
    final number = ascii.encode(v.number);
    if (number.isEmpty ||
        number.length > 20 ||
        number.any((c) =>
            !(c >= 0x30 && c <= 0x39) && c != 0x2b && c != 0x2a && c != 0x23)) {
      throw ArgumentError.value(v.number, 'number', 'invalid contact number');
    }
    return Uint8List.fromList(
        [v.slot, name.length, ...name, number.length, ...number]);
  }

  static WSContactSetting decodeContact(Uint8List v) {
    WSBinary.requireLength(v, 3, 'contact');
    final nameLen = v[1];
    final numberLenOffset = 2 + nameLen;
    if (numberLenOffset >= v.length)
      throw const FormatException('truncated contact');
    final numberLen = v[numberLenOffset];
    if (numberLenOffset + 1 + numberLen > v.length)
      throw const FormatException('truncated contact number');
    return WSContactSetting(
      slot: v[0],
      name: utf8.decode(v.sublist(2, 2 + nameLen)),
      number: ascii.decode(
          v.sublist(numberLenOffset + 1, numberLenOffset + 1 + numberLen)),
    );
  }

  static Uint8List encodeWeather(WSWeatherSetting v) {
    final city = WSBinary.utf8Bytes(v.city, maxBytes: 32);
    final cityPadded = Uint8List(32)..setRange(0, city.length, city);
    return Uint8List.fromList([
      ...WSBinary.u32(v.updatedAtSeconds),
      ...cityPadded,
      8,
      v.type,
      v.currentCelsius & 0xff,
      v.highCelsius & 0xff,
      v.lowCelsius & 0xff,
      v.humidityPercent,
      v.uvIndex,
      ...WSBinary.u16(v.aqi),
      v.forecast.length,
      3,
      for (final day in v.forecast) ...[
        day.type,
        day.highCelsius & 0xff,
        day.lowCelsius & 0xff
      ],
    ]);
  }
}
