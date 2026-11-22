import 'dart:typed_data';

enum WSBloodPressureUnit { mmHg, kPa }

enum WSBloodGlucoseUnit { mmolPerLiter, mgPerDeciliter }

enum WSTemperatureUnit { celsius, fahrenheit }

final class WSDisplayFormat {
  const WSDisplayFormat({
    required this.hour12,
    required this.dayFirst,
    required this.imperialDistance,
    required this.pounds,
  });
  final bool hour12;
  final bool dayFirst;
  final bool imperialDistance;
  final bool pounds;
}

final class WSUserProfile {
  const WSUserProfile({
    required this.gender,
    required this.birthYear,
    required this.birthMonth,
    required this.birthDay,
    required this.heightTenthCm,
    required this.weightTenthKg,
  });
  final int gender;
  final int birthYear;
  final int birthMonth;
  final int birthDay;
  final int heightTenthCm;
  final int weightTenthKg;
}

final class WSActivityGoals {
  const WSActivityGoals({
    required this.steps,
    required this.caloriesKcal,
    required this.sleepMinutes,
    required this.distanceMeters,
    required this.activeMinutes,
  });
  final int steps;
  final int caloriesKcal;
  final int sleepMinutes;
  final int distanceMeters;
  final int activeMinutes;
}

final class WSFemaleHealthSetting {
  const WSFemaleHealthSetting({
    required this.enabled,
    required this.cycleDays,
    required this.periodDays,
    required this.lastPeriodYear,
    required this.lastPeriodMonth,
    required this.lastPeriodDay,
    required this.reminderBits,
    required this.reminderHour,
    required this.reminderMinute,
  });
  final bool enabled;
  final int cycleDays;
  final int periodDays;
  final int lastPeriodYear;
  final int lastPeriodMonth;
  final int lastPeriodDay;
  final int reminderBits;
  final int reminderHour;
  final int reminderMinute;
}

final class WSTimeWindowSetting {
  const WSTimeWindowSetting({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
}

final class WSHealthAlarmSetting {
  WSHealthAlarmSetting({
    required this.highEnabled,
    required Uint8List highThreshold,
    required this.lowEnabled,
    required Uint8List lowThreshold,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  })  : highThreshold = Uint8List.fromList(highThreshold),
        lowThreshold = Uint8List.fromList(lowThreshold) {
    if (highThreshold.length != 2 || lowThreshold.length != 2) {
      throw ArgumentError('alarm thresholds must each be exactly 2 bytes');
    }
  }
  final bool highEnabled;
  final Uint8List highThreshold;
  final bool lowEnabled;
  final Uint8List lowThreshold;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
}

final class WSAlarmSetting {
  const WSAlarmSetting({
    required this.slot,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.repeatBits,
    this.label = '',
  });
  final int slot;
  final bool enabled;
  final int hour;
  final int minute;
  final int repeatBits;
  final String label;
}

final class WSIntervalReminderSetting {
  const WSIntervalReminderSetting({
    required this.type,
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.intervalMinutes,
  });
  final int type;
  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;
}

final class WSContactSetting {
  const WSContactSetting(
      {required this.slot, required this.name, required this.number});
  final int slot;
  final String name;
  final String number;
}

final class WSWeatherDay {
  const WSWeatherDay(
      {required this.type,
      required this.highCelsius,
      required this.lowCelsius});
  final int type;
  final int highCelsius;
  final int lowCelsius;
}

final class WSWeatherSetting {
  const WSWeatherSetting({
    required this.updatedAtSeconds,
    required this.city,
    required this.type,
    required this.currentCelsius,
    required this.highCelsius,
    required this.lowCelsius,
    required this.humidityPercent,
    required this.uvIndex,
    required this.aqi,
    this.forecast = const [],
  });
  final int updatedAtSeconds;
  final String city;
  final int type;
  final int currentCelsius;
  final int highCelsius;
  final int lowCelsius;
  final int humidityPercent;
  final int uvIndex;
  final int aqi;
  final List<WSWeatherDay> forecast;
}

final class WSDeviceDetails {
  const WSDeviceDetails({
    required this.modelId,
    required this.firmwareMajor,
    required this.firmwareMinor,
    required this.firmwareRevision,
    required this.firmwareBuild,
    required this.protocolVersion,
    required this.hardwareVersion,
    required this.platform,
    required this.mac,
    required this.serialNumber,
  });
  final int modelId;
  final int firmwareMajor;
  final int firmwareMinor;
  final int firmwareRevision;
  final int firmwareBuild;
  final int protocolVersion;
  final int hardwareVersion;
  final int platform;
  final Uint8List mac;
  final String serialNumber;
}

final class WSSettingEvent {
  WSSettingEvent(
      {required this.key, required this.opcode, required Uint8List body})
      : body = Uint8List.fromList(body);
  final int key;
  final int opcode;
  final Uint8List body;
}

final class WSListPage<T> {
  const WSListPage({
    required this.capacity,
    required this.items,
    this.nextSlot,
  });
  final int capacity;
  final List<T> items;
  final int? nextSlot;
  bool get isLast => nextSlot == null || nextSlot == capacity;
}

final class WSSettingCodec<T> {
  const WSSettingCodec(
      {required this.key, required this.encode, required this.decode});
  final int key;
  final Uint8List Function(T value) encode;
  final T Function(Uint8List body) decode;
}
