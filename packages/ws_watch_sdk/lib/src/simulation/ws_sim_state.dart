import 'dart:typed_data';

import '../measure/ws_measure_models.dart';
import '../wire/ws_health_monitor_codec.dart';
import '../wire/ws_measure_command.dart' show WSSpotMeasureLane;
import '../wire/ws_settings_command.dart';

/// Cross-connection simulator device state (W5.2).
final class WsSimWatchState {
  /// Stable sample timestamps keep repeated pulls idempotent.
  final DateTime historyTimestamp = DateTime.now();
  String? boundUserId;
  int language = 1;
  int phoneSystem = 2;

  final Map<int, Uint8List> settingBodies = {
    WSSettingsCommand.keyDisplayFormat: Uint8List.fromList([0, 0, 0, 0]),
    WSSettingsCommand.keyPowerSaving: Uint8List.fromList([0]),
    WSSettingsCommand.keyGoals: Uint8List(14),
    WSSettingsCommand.keyWrist: Uint8List.fromList([0]),
    WSSettingsCommand.keyBrightness: Uint8List.fromList([80]),
    WSSettingsCommand.keyScreenDuration: Uint8List.fromList([5]),
    WSSettingsCommand.keyRaiseToWake: Uint8List.fromList([1, 0, 0, 0, 0]),
    WSSettingsCommand.keyDoNotDisturb: Uint8List.fromList([0, 22, 0, 7, 0]),
    WSSettingsCommand.keyHealthDisplay: Uint8List.fromList([0, 0, 1, 0xF8]),
    WSSettingsCommand.keySupportedLanguages:
        Uint8List.fromList([3, 0, 1, 0x12]),
    WSSettingsCommand.keyBloodPressureUnit: Uint8List.fromList([0]),
    WSSettingsCommand.keyBloodGlucoseUnit: Uint8List.fromList([0]),
    WSSettingsCommand.keyNotificationSwitches: Uint8List(16)
      ..fillRange(0, 16, 0xff),
    WSSettingsCommand.keyHrvAlarm: Uint8List(10),
    WSSettingsCommand.keyBloodPressureAlarm: Uint8List(10),
    WSSettingsCommand.keyBloodGlucoseAlarm: Uint8List(10),
    WSSettingsCommand.keyPressureAlarm: Uint8List(10),
    WSSettingsCommand.keyTemperatureAlarm: Uint8List(10),
  };

  final Map<int, List<Uint8List>> settingLists = {
    WSSettingsCommand.keyAlarms: <Uint8List>[],
    WSSettingsCommand.keyContacts: <Uint8List>[],
    WSSettingsCommand.keySosContacts: <Uint8List>[],
  };

  Uint8List heartRateDataFrame = Uint8List.fromList([
    0x05,
    0x00,
    0x02,
    0x6A,
    0xCC,
    0x9A,
    0x88,
    0x48,
    0x6A,
    0xCC,
    0x9A,
    0xC4,
    0x4B,
  ]);

  bool historyBusy = false;

  int batteryPercent = 75;
  int batteryCharging = 0;

  WSSpotMeasureLane? activeSpotLane;
  int spotStartedAtUnix = 0;
  int? activeSportMode;
  int sportStartedAtUnix = 0;
  bool sportPaused = false;
  bool sportSubscribed = false;

  final Map<int, Uint8List> autoMonitorBodies = {
    WSHealthMonitorCodec.keyHeartRateAuto:
        _defaultAuto(enabled: false, minutes: 10),
    WSSettingsCommand.keyHrvAuto: _defaultAuto(enabled: false, minutes: 60),
    WSHealthMonitorCodec.keyBloodPressureAuto:
        _defaultAuto(enabled: false, minutes: 60),
    WSHealthMonitorCodec.keyBloodSugarAuto:
        _defaultAuto(enabled: false, minutes: 60),
    WSHealthMonitorCodec.keySpO2Auto: _defaultAuto(enabled: false, minutes: 60),
    WSHealthMonitorCodec.keyPressureAuto:
        _defaultAuto(enabled: false, minutes: 30),
    WSHealthMonitorCodec.keyTemperatureAuto:
        _defaultAuto(enabled: false, minutes: 30),
    WSHealthMonitorCodec.keyHeatStressAuto: _defaultAuto(
      enabled: false,
      minutes: 30,
      startHour: 8,
      startMinute: 0,
      endHour: 20,
      endMinute: 0,
    ),
  };

  Uint8List heartRateAlarmBody = Uint8List.fromList([
    0x00,
    0x00,
    0x78,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);

  Uint8List spo2AlarmBody = Uint8List.fromList([
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x5A,
    0x16,
    0x00,
    0x07,
    0x00,
  ]);

  bool temperatureUnitCelsius = true;

  Uint8List todayPayload = Uint8List.fromList([
    0x6A,
    0xCC,
    0x9A,
    0xA1,
    0x00,
    0x00,
    0x14,
    0x6E,
    0x00,
    0x00,
    0x0E,
    0x42,
    0x00,
    0x00,
    0x07,
    0x48,
    0x00,
    0x2A,
    0x48,
    0x6A,
    0xCC,
    0x9A,
    0x10,
  ]);

  Uint8List todayNotificationConfig = Uint8List.fromList([
    0x01,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
  ]);

  bool get spotBusy => activeSpotLane != null;

  static Uint8List _defaultAuto({
    required bool enabled,
    required int minutes,
    int startHour = 0,
    int startMinute = 0,
    int endHour = 0,
    int endMinute = 0,
  }) =>
      WSHealthMonitorCodec.encodeAutoMonitorBody(
        WSAutoMeasureSchedule(
          enabled: enabled,
          startHour: startHour,
          startMinute: startMinute,
          endHour: endHour,
          endMinute: endMinute,
          intervalMinutes: minutes,
        ),
      );
}
