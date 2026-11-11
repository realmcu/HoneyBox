/// Languages and protocol codes supported by Android V2 `DeviceLanguageUtils`.
enum WSLanguage {
  english(0x00),
  simplifiedChinese(0x01),
  traditionalChinese(0x02),
  polish(0x0d),
  german(0x12),
  russian(0x13),
  french(0x14),
  korean(0x1d),
  mongolian(0x35),
  portuguese(0x3e),
  japanese(0x41),
  swedish(0x42),
  thai(0x51),
  turkish(0x52),
  spanish(0x57),
  italian(0x60),
  vietnamese(0x66);

  const WSLanguage(this.code);
  final int code;

  static WSLanguage fromCode(int code) => WSLanguage.values.firstWhere(
      (value) => value.code == code,
      orElse: () => throw FormatException('Unsupported JW language: $code'));
}

enum WSHourSystem {
  h24(0x00),
  h12(0x01);

  const WSHourSystem(this.code);
  final int code;

  static WSHourSystem fromCode(int code) => switch (code) {
        0x00 => WSHourSystem.h24,
        0x01 => WSHourSystem.h12,
        _ => throw FormatException('Unsupported JW hour system: $code'),
      };
}

enum WSUnitSystem {
  metric(0x00),
  imperial(0x01);

  const WSUnitSystem(this.code);
  final int code;

  static WSUnitSystem fromCode(int code) => switch (code) {
        0x00 => WSUnitSystem.metric,
        0x01 => WSUnitSystem.imperial,
        _ => throw FormatException('Unsupported JW unit system: $code'),
      };
}

/// A setting that has been written and read back from the device.
final class WSVerifiedSetting<T> {
  const WSVerifiedSetting({required this.previous, required this.value});
  final T previous;
  final T value;
}

/// A setting command completed without a device value available for read-back
/// validation.
final class WSSettingSubmission {
  const WSSettingSubmission(this.name);
  final String name;
}

enum WSDateFormat {
  monthDay(0x00),
  dayMonth(0x01);

  const WSDateFormat(this.code);
  final int code;

  static WSDateFormat fromCode(int code) => switch (code) {
        0x00 => WSDateFormat.monthDay,
        0x01 => WSDateFormat.dayMonth,
        _ => throw FormatException('Unsupported JW date format: $code'),
      };
}

/// Body data sent with the protocol's write-only user profile command.
final class WSUserProfile {
  const WSUserProfile({
    required this.isMale,
    required this.age,
    required this.heightCentimeters,
    required this.weightKilograms,
  })  : assert(age >= 0 && age <= 127),
        // The V2 wire format allocates nine bits in half-centimetres:
        // 511 / 2 = 255.5 cm. The former 127.5 cm cap treated the first
        // packed byte as the complete value and rejected ordinary profiles.
        assert(heightCentimeters > 0 && heightCentimeters <= 255.5),
        assert(weightKilograms > 0 && weightKilograms <= 511.5);

  final bool isMale;
  final int age;
  final double heightCentimeters;
  final double weightKilograms;
}

/// The device's three write-only daily goals.
final class WSGoals {
  const WSGoals({
    required this.steps,
    required this.sleepMinutes,
    required this.calories,
  })  : assert(steps >= 0 && steps <= 0xffffffff),
        assert(sleepMinutes >= 0 && sleepMinutes <= 0xffff),
        assert(calories >= 0 && calories <= 0xffff);

  final int steps;
  final int sleepMinutes;
  final int calories;
}

/// A daily time range used by DND and reminder models.
final class WSTimeRange {
  const WSTimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  })  : assert(startHour >= 0 && startHour <= 23),
        assert(endHour >= 0 && endHour <= 23),
        assert(startMinute >= 0 && startMinute <= 59),
        assert(endMinute >= 0 && endMinute <= 59);

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  @override
  bool operator ==(Object other) =>
      other is WSTimeRange &&
      other.startHour == startHour &&
      other.startMinute == startMinute &&
      other.endHour == endHour &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startHour, startMinute, endHour, endMinute);
}

final class WSDoNotDisturb {
  const WSDoNotDisturb({required this.enabled, required this.schedule});
  final bool enabled;
  final WSTimeRange schedule;

  @override
  bool operator ==(Object other) =>
      other is WSDoNotDisturb &&
      other.enabled == enabled &&
      other.schedule == schedule;

  @override
  int get hashCode => Object.hash(enabled, schedule);
}

/// Heat-stress / 高温健康提醒 active window (`0x02/0x86`–`0x88`).
///
/// When [enabled] is true, heat-stress alerts fire only inside [schedule]
/// (may cross midnight). When false, firmware uses its all-day default.
final class WSHeatStressReminder {
  const WSHeatStressReminder({required this.enabled, required this.schedule});
  final bool enabled;
  final WSTimeRange schedule;

  @override
  bool operator ==(Object other) =>
      other is WSHeatStressReminder &&
      other.enabled == enabled &&
      other.schedule == schedule;

  @override
  int get hashCode => Object.hash(enabled, schedule);
}

/// High heart-rate alarm (`0x02/0x75`–`0x77`).
///
/// Firmware support is `rateReminder` and/or `highHrv` (App UKBridge OR).
/// [thresholdBpm] valid range matches Android: 40–220.
final class WSHighHeartRateReminder {
  const WSHighHeartRateReminder({
    required this.enabled,
    required this.thresholdBpm,
  }) : assert(thresholdBpm >= 40 && thresholdBpm <= 220);

  final bool enabled;
  final int thresholdBpm;

  @override
  bool operator ==(Object other) =>
      other is WSHighHeartRateReminder &&
      other.enabled == enabled &&
      other.thresholdBpm == thresholdBpm;

  @override
  int get hashCode => Object.hash(enabled, thresholdBpm);
}

/// Sedentary reminder representation used by Android V2's eight-byte packet.
final class WSSedentaryReminder {
  const WSSedentaryReminder({
    required this.enabled,
    required this.thresholdMinutes,
    required this.notifyHour,
    required this.startHour,
    required this.endHour,
    required this.repeatDays,
  })  : assert(thresholdMinutes >= 0 && thresholdMinutes <= 0xffff),
        assert(notifyHour >= 0 && notifyHour <= 23),
        assert(startHour >= 0 && startHour <= 23),
        assert(endHour >= 0 && endHour <= 23),
        assert(repeatDays >= 0 && repeatDays <= 0x7f);

  final bool enabled;
  final int thresholdMinutes;
  final int notifyHour;
  final int startHour;
  final int endHour;
  final int repeatDays;

  @override
  bool operator ==(Object other) =>
      other is WSSedentaryReminder &&
      other.enabled == enabled &&
      other.thresholdMinutes == thresholdMinutes &&
      other.notifyHour == notifyHour &&
      other.startHour == startHour &&
      other.endHour == endHour &&
      other.repeatDays == repeatDays;

  @override
  int get hashCode => Object.hash(
      enabled, thresholdMinutes, notifyHour, startHour, endHour, repeatDays);
}

/// One alarm record for JW standard (`0x02/0x03`) or labeled alarm2 (`0x65`–`0x67`).
///
/// [repeatDays] uses Monday bit 0 through Sunday bit 6. When zero, the date in
/// [time] is the one-shot schedule; when non-zero, only [repeatDays] controls
/// repetition (matching Android `ApplicationLayerAlarmPacket`).
final class WSAlarm {
  const WSAlarm({
    required this.id,
    required this.time,
    required this.repeatDays,
    this.enabled = true,
    this.label = '',
  })  : assert(id >= 0 && id <= 31),
        assert(repeatDays >= 0 && repeatDays <= 0x7f),
        assert(label.length <= 15);

  final int id;
  final DateTime time;
  final int repeatDays;
  final bool enabled;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is WSAlarm &&
      other.id == id &&
      other.time == time &&
      other.repeatDays == repeatDays &&
      other.enabled == enabled &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, time, repeatDays, enabled, label);
}

/// Parsed labeled-alarm2 read payload before the list is aggregated.
final class WSAlarm2ReadChunk {
  const WSAlarm2ReadChunk({
    required this.alarm,
    required this.curIndex,
    required this.count,
  });

  final WSAlarm? alarm;
  final int curIndex;
  final int count;
}

/// Social / call notification channels (Android `WSNotifyType`).
///
/// [maskBit] indexes the 32-bit notify switch mask (`0x28`/`0x29`/`0x2D`).
/// [messageType] is the Android notify payload type for `cmd 0x04` / `key 0x04`
/// (null for [call], which uses incoming-call key `0x01`).
enum WSNotifyChannel {
  call(maskBit: 0, messageType: null, enableCode: 0x01, disableCode: 0x02),
  qq(maskBit: 1, messageType: 0x01, enableCode: 0x03, disableCode: 0x04),
  wechat(maskBit: 2, messageType: 0x02, enableCode: 0x05, disableCode: 0x06),
  sms(maskBit: 3, messageType: 0x04, enableCode: 0x07, disableCode: 0x08),
  line(maskBit: 4, messageType: 0x08, enableCode: 0x09, disableCode: 0x0a),
  twitter(maskBit: 5, messageType: 0x09, enableCode: 0x0b, disableCode: 0x0c),
  facebook(maskBit: 6, messageType: 0x0a, enableCode: 0x0e, disableCode: 0x0f),
  messenger(maskBit: 7, messageType: 0x0b, enableCode: 0x10, disableCode: 0x11),
  whatsapp(maskBit: 8, messageType: 0x0c, enableCode: 0x12, disableCode: 0x13),
  linkedin(maskBit: 9, messageType: 0x0d, enableCode: 0x14, disableCode: 0x15),
  instagram(
      maskBit: 10, messageType: 0x0e, enableCode: 0x16, disableCode: 0x17),
  skype(maskBit: 11, messageType: 0x0f, enableCode: 0x18, disableCode: 0x19),
  viber(maskBit: 12, messageType: 0x10, enableCode: 0x1a, disableCode: 0x1b),
  kakaotalk(
      maskBit: 13, messageType: 0x11, enableCode: 0x1c, disableCode: 0x1d),
  vkontakte(
      maskBit: 14, messageType: 0x12, enableCode: 0x1e, disableCode: 0x1f),
  tim(maskBit: 18, messageType: 0x03, enableCode: 0x26, disableCode: 0x27),
  gmail(maskBit: 19, messageType: 0x05, enableCode: 0x28, disableCode: 0x29),
  dingtalk(
      maskBit: 20, messageType: 0x06, enableCode: 0x2a, disableCode: 0x2b),
  workWechat(
      maskBit: 21, messageType: 0x07, enableCode: 0x2c, disableCode: 0x2d),
  other(maskBit: 31, messageType: 0x00, enableCode: 0x36, disableCode: 0x37);

  const WSNotifyChannel({
    required this.maskBit,
    required this.messageType,
    required this.enableCode,
    required this.disableCode,
  });

  final int maskBit;
  final int? messageType;
  final int enableCode;
  final int disableCode;
}

/// Full notify-switch table returned by `0x29` / written by `0x2D`.
final class WSNotifySettings {
  WSNotifySettings(Map<WSNotifyChannel, bool> enabled)
      : enabled = Map<WSNotifyChannel, bool>.unmodifiable({
          for (final channel in WSNotifyChannel.values)
            channel: enabled[channel] ?? false,
        });

  factory WSNotifySettings.all(bool value) => WSNotifySettings({
        for (final channel in WSNotifyChannel.values) channel: value,
      });

  final Map<WSNotifyChannel, bool> enabled;

  bool operator [](WSNotifyChannel channel) => enabled[channel]!;

  WSNotifySettings withChannel(WSNotifyChannel channel, bool value) =>
      WSNotifySettings({...enabled, channel: value});

  WSNotifySettings withAll(bool value) => WSNotifySettings.all(value);

  @override
  bool operator ==(Object other) {
    if (other is! WSNotifySettings) return false;
    for (final channel in WSNotifyChannel.values) {
      if (enabled[channel] != other.enabled[channel]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
        for (final channel in WSNotifyChannel.values) enabled[channel],
      ]);
}
