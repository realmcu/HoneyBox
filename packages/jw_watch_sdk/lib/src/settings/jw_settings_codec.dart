import 'dart:convert';
import 'dart:typed_data';

import 'jw_settings_models.dart';

/// Wire encoding shared by the public settings API and its protocol tests.
/// This is an implementation detail and is intentionally not exported.
abstract final class JWSettingsCodec {
  static Uint8List encodeTime(DateTime time) {
    final local = time.toLocal();
    final year = local.year - 2000;
    if (year < 0 || year > 63) {
      throw ArgumentError.value(time, 'time', 'JW time year must be 2000–2063');
    }
    return Uint8List.fromList([
      (year << 2) | (local.month >> 2),
      (local.month << 6) | (local.day << 1) | (local.hour >> 4),
      (local.hour << 4) | (local.minute >> 2),
      (local.minute << 6) | local.second,
    ]);
  }

  static Uint8List encodeUserProfile(JWUserProfile value) {
    _range(value.age, 0, 127, 'age');
    // Android V2 casts these half-unit values to int, which truncates.
    final height = (value.heightCentimeters * 2).truncate();
    final weight = (value.weightKilograms * 2).truncate();
    _range(height, 1, 511, 'heightCentimeters');
    _range(weight, 1, 1023, 'weightKilograms');
    return Uint8List.fromList([
      (value.isMale ? 0x80 : 0) | value.age,
      height >> 1,
      (height << 7) | (weight >> 3),
      weight << 5,
    ]);
  }

  static Uint8List encodeUint16(int value, String name) {
    _range(value, 0, 0xffff, name);
    return Uint8List.fromList([value >> 8, value]);
  }

  static Uint8List encodeUint32(int value, String name) {
    _range(value, 0, 0xffffffff, name);
    return Uint8List.fromList([value >> 24, value >> 16, value >> 8, value]);
  }

  static Uint8List encodeDoNotDisturb(JWDoNotDisturb value) {
    final time = value.schedule;
    _time(time.startHour, time.startMinute, 'start');
    _time(time.endHour, time.endMinute, 'end');
    return Uint8List.fromList([
      (value.enabled ? 0x40 : 0) |
          (time.startHour << 1) |
          (time.startMinute >> 5),
      (time.startMinute << 3) | (time.endHour >> 2),
      (time.endHour << 6) | time.endMinute,
    ]);
  }

  static JWDoNotDisturb decodeDoNotDisturb(Uint8List value) {
    _length(value, 3, 'DND');
    final startHour = (value[0] >> 1) & 0x1f;
    final startMinute = ((value[0] & 1) << 5) | ((value[1] >> 3) & 0x1f);
    final endHour = ((value[1] & 7) << 2) | ((value[2] >> 6) & 3);
    final endMinute = value[2] & 0x3f;
    _time(startHour, startMinute, 'DND start');
    _time(endHour, endMinute, 'DND end');
    return JWDoNotDisturb(
      enabled: (value[0] & 0x40) != 0,
      schedule: JWTimeRange(
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      ),
    );
  }

  static Uint8List encodeSedentaryReminder(JWSedentaryReminder value) {
    _range(value.thresholdMinutes, 0, 0xffff, 'thresholdMinutes');
    _hour(value.notifyHour, 'notifyHour');
    _hour(value.startHour, 'startHour');
    _hour(value.endHour, 'endHour');
    _range(value.repeatDays, 0, 0x7f, 'repeatDays');
    return Uint8List.fromList([
      0,
      value.enabled ? 1 : 0,
      value.thresholdMinutes >> 8,
      value.thresholdMinutes,
      value.notifyHour,
      value.startHour,
      value.endHour,
      value.repeatDays,
    ]);
  }

  static JWSedentaryReminder decodeSedentaryReminder(Uint8List value) {
    _length(value, 8, 'sedentary reminder');
    final threshold = (value[2] << 8) | value[3];
    _hour(value[4], 'notifyHour');
    _hour(value[5], 'startHour');
    _hour(value[6], 'endHour');
    if ((value[7] & 0x80) != 0) {
      throw const FormatException('Invalid JW sedentary reminder repeat days');
    }
    return JWSedentaryReminder(
      enabled: value[1] == 1,
      thresholdMinutes: threshold,
      notifyHour: value[4],
      startHour: value[5],
      endHour: value[6],
      repeatDays: value[7],
    );
  }

  static Uint8List encodeAlarms(List<JWAlarm> alarms) {
    if (alarms.length > 46) {
      throw ArgumentError.value(alarms, 'alarms', 'JW supports at most 46 alarms per request');
    }
    final result = <int>[];
    for (final alarm in alarms) {
      final wire = _alarmWireSchedule(alarm);
      _range(wire.year, 0, 63, 'alarm year');
      _range(alarm.id, 0, 7, 'alarm id');
      _range(alarm.repeatDays, 0, 0x7f, 'alarm repeatDays');
      result.addAll([
        (wire.year << 2) | (wire.month >> 2),
        (wire.month << 6) | (wire.day << 1) | (wire.hour >> 4),
        (wire.hour << 4) | (wire.minute >> 2),
        (wire.minute << 6) | (alarm.id << 3),
        alarm.repeatDays,
      ]);
    }
    return Uint8List.fromList(result);
  }

  /// Date fields written to the device for repeating alarms use today's
  /// calendar date, matching Android `DateUtil.getTodayDate()` packing.
  static ({int year, int month, int day, int hour, int minute})
      _alarmWireSchedule(JWAlarm alarm) {
    final time = alarm.time.toLocal();
    final date = alarm.repeatDays == 0 ? time : DateTime.now();
    return (
      year: date.year - 2000,
      month: date.month,
      day: date.day,
      hour: time.hour,
      minute: time.minute,
    );
  }

  static List<JWAlarm> decodeAlarms(Uint8List value) {
    if (value.isEmpty) return const [];
    if (value.length % 5 != 0) {
      throw const FormatException('Invalid JW alarm response length');
    }
    final alarms = <JWAlarm>[];
    for (var offset = 0; offset < value.length; offset += 5) {
      final a = value[offset];
      final b = value[offset + 1];
      final c = value[offset + 2];
      final d = value[offset + 3];
      // Firmware may set bit 7; Android masks with 0x7f in parseData.
      final repeatDays = value[offset + 4] & 0x7f;
      if (a == 0 && b == 0 && c == 0 && d == 0 && repeatDays == 0) {
        continue;
      }
      final year = 2000 + (a >> 2);
      final month = ((a & 3) << 2) | (b >> 6);
      final day = (b >> 1) & 0x1f;
      final hour = ((b & 1) << 4) | (c >> 4);
      final minute = ((c << 2) & 0x3f) | ((d >> 6) & 0x03);
      final id = (d >> 3) & 7;
      if (month < 1 || month > 12 || day < 1 || day > 31) {
        continue;
      }
      _time(hour, minute, 'alarm');
      try {
        final time = DateTime(year, month, day, hour, minute);
        if (time.month != month || time.day != day) {
          continue;
        }
        alarms.add(JWAlarm(
          id: id,
          time: time,
          repeatDays: repeatDays,
          enabled: true,
        ));
      } on ArgumentError {
        continue;
      }
    }
    return List.unmodifiable(alarms);
  }

  static Uint8List encodeAlarm2(JWAlarm alarm, {bool delete = false}) {
    final wire = delete
        ? (
            year: alarm.time.toLocal().year - 2000,
            month: 0,
            day: 0,
            hour: alarm.time.toLocal().hour,
            minute: alarm.time.toLocal().minute,
          )
        : _alarmWireSchedule(alarm);
    _range(wire.year, 0, 63, 'alarm2 year');
    _range(alarm.id, 0, 31, 'alarm2 id');
    _range(alarm.repeatDays, 0, 0x7f, 'alarm2 repeatDays');
    final contentBytes = utf8.encode(alarm.label);
    final contentLen = contentBytes.length > 15 ? 15 : contentBytes.length;
    final data = Uint8List(5 + contentLen);
    final repeat = delete ? 0 : alarm.repeatDays;
    data[0] = (alarm.enabled ? 0x80 : 0x00) |
        (alarm.id << 2) |
        (wire.year >> 4);
    data[1] = ((wire.year << 4) & 0xf0) | wire.month;
    data[2] = (wire.day << 3) | (wire.hour >> 2);
    data[3] = ((wire.hour << 6) & 0xc0) | wire.minute;
    data[4] = repeat << 1;
    if (contentLen > 0) {
      data.setRange(5, 5 + contentLen, contentBytes, 0);
    }
    return data;
  }

  static JWAlarm2ReadChunk decodeAlarm2ReadChunk(Uint8List data) {
    if (data.isEmpty) {
      return const JWAlarm2ReadChunk(alarm: null, curIndex: 0, count: 0);
    }
    if (data.length < 7) {
      throw const FormatException('Invalid JW alarm2 response length');
    }
    final enabled = (data[0] & 0x80) != 0;
    final id = (data[0] >> 2) & 0x1f;
    final year = 2000 + (((data[0] & 0x03) << 4) | ((data[1] & 0xf0) >> 4));
    final month = data[1] & 0x0f;
    final day = (data[2] >> 3) & 0x1f;
    final hour = ((data[2] & 0x07) << 2) | ((data[3] >> 6) & 0x03);
    final minute = data[3] & 0x3f;
    final repeatDays = (data[4] >> 1) & 0x7f;
    final contentEnd = data.length - 2;
    final contentLength = contentEnd > 5 ? contentEnd - 5 : 0;
    final label = contentLength > 0
        ? utf8.decode(data.sublist(5, 5 + contentLength), allowMalformed: true)
        : '';
    final curIndex = data[data.length - 2];
    final count = data[data.length - 1];
    _time(hour, minute, 'alarm2');
    JWAlarm? alarm;
    if (count > 0) {
      final schedule = repeatDays == 0
          ? DateTime(year, month, day, hour, minute)
          : DateTime(year, month, day, hour, minute);
      if (schedule.month != month || schedule.day != day) {
        throw const FormatException('Invalid JW alarm2 date');
      }
      alarm = JWAlarm(
        id: id,
        time: schedule,
        repeatDays: repeatDays,
        enabled: enabled,
        label: label,
      );
    }
    return JWAlarm2ReadChunk(alarm: alarm, curIndex: curIndex, count: count);
  }

  static List<JWAlarm> decodeAlarm2List(List<Uint8List> chunks) {
    if (chunks.isEmpty) return const [];
    final byId = <int, JWAlarm>{};
    for (final chunkBytes in chunks) {
      final chunk = decodeAlarm2ReadChunk(chunkBytes);
      if (chunk.count == 0) return const [];
      final alarm = chunk.alarm;
      if (alarm != null) {
        byId[alarm.id] = alarm;
      }
      if (chunk.curIndex == chunk.count) break;
    }
    final alarms = byId.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(alarms);
  }

  static void _length(Uint8List value, int length, String name) {
    if (value.length != length) {
      throw FormatException('Invalid JW $name response length');
    }
  }

  static void _time(int hour, int minute, String name) {
    _hour(hour, '$name hour');
    _range(minute, 0, 59, '$name minute');
  }

  static void _hour(int value, String name) => _range(value, 0, 23, name);

  static void _range(int value, int min, int max, String name) {
    if (value < min || value > max) {
      throw ArgumentError.value(value, name, 'must be between $min and $max');
    }
  }
}
