import 'dart:async';
import 'dart:typed_data';

import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import '../ws_demo_controller.dart';
import '../ws_history_sync_state.dart';

typedef WSDemoLabEventSink = void Function(Map<String, Object?> event);

/// Machine-driven SDK checks that exercise the same controller used by the UI.
///
/// The lab deliberately has no widget interaction. Integration tests can run it
/// on an Android device while the SDK still talks to the in-process watch
/// simulator through the normal scan/connect/session APIs.
final class WSDemoLabRunner {
  WSDemoLabRunner({WSDemoController? controller, WSDemoLabEventSink? eventSink})
      : _controller = controller ?? WSDemoController(),
        _eventSink = eventSink ?? _ignoreEvent;

  static const availablePlanIds = <String>[
    'smoke',
    'settings',
    'binding',
    'notifications',
    'history-data',
    'measurement-sport',
    'multi-device',
  ];

  final WSDemoController _controller;
  final WSDemoLabEventSink _eventSink;
  bool _used = false;

  Future<WSDemoLabReport> run(String planId) async {
    if (_used) throw StateError('A WS demo lab runner can only run once.');
    _used = true;
    final plan = _plan(planId);
    final startedAt = DateTime.now();
    final results = <WSDemoLabStepResult>[];
    Object? runError;
    StackTrace? runStackTrace;

    _emit('run-start', {
      'planId': plan.id,
      'planName': plan.name,
      'stepCount': plan.steps.length,
    });

    try {
      for (final step in plan.steps) {
        final stepStartedAt = DateTime.now();
        _emit('step-start', {
          'planId': plan.id,
          'stepId': step.id,
          'timeoutMs': step.timeout.inMilliseconds,
        });
        try {
          final value = await step.run(_controller).timeout(step.timeout);
          final result = WSDemoLabStepResult.passed(
            stepId: step.id,
            duration: DateTime.now().difference(stepStartedAt),
            value: value,
          );
          results.add(result);
          _emit('step-end', {'planId': plan.id, ...result.toJson()});
        } catch (error, stackTrace) {
          runError = error;
          runStackTrace = stackTrace;
          final result = WSDemoLabStepResult.failed(
            stepId: step.id,
            duration: DateTime.now().difference(stepStartedAt),
            error: error,
          );
          results.add(result);
          _emit('step-end', {'planId': plan.id, ...result.toJson()});
          break;
        }
      }
    } finally {
      try {
        await _controller.shutdown();
      } catch (error, stackTrace) {
        runError ??= error;
        runStackTrace ??= stackTrace;
        results.add(
          WSDemoLabStepResult.failed(
            stepId: 'cleanup',
            duration: Duration.zero,
            error: error,
          ),
        );
      }
      _controller.dispose();
    }

    final report = WSDemoLabReport(
      planId: plan.id,
      startedAt: startedAt,
      duration: DateTime.now().difference(startedAt),
      steps: List.unmodifiable(results),
      error: runError,
      stackTrace: runStackTrace,
    );
    _emit('run-end', report.toJson());
    return report;
  }

  void _emit(String type, Map<String, Object?> data) {
    _eventSink({
      'schema': 'ws-demo-lab/v1',
      'type': type,
      'time': DateTime.now().toUtc().toIso8601String(),
      ...data,
    });
  }

  static void _ignoreEvent(Map<String, Object?> _) {}
}

final class WSDemoLabReport {
  const WSDemoLabReport({
    required this.planId,
    required this.startedAt,
    required this.duration,
    required this.steps,
    this.error,
    this.stackTrace,
  });

  final String planId;
  final DateTime startedAt;
  final Duration duration;
  final List<WSDemoLabStepResult> steps;
  final Object? error;
  final StackTrace? stackTrace;

  bool get passed => error == null && steps.every((step) => step.passed);

  Map<String, Object?> toJson() => {
        'planId': planId,
        'status': passed ? 'passed' : 'failed',
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'steps': [for (final step in steps) step.toJson()],
        if (error != null) 'error': _errorJson(error!),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      };
}

final class WSDemoLabStepResult {
  const WSDemoLabStepResult._({
    required this.stepId,
    required this.passed,
    required this.duration,
    this.value,
    this.error,
  });

  factory WSDemoLabStepResult.passed({
    required String stepId,
    required Duration duration,
    Map<String, Object?> value = const {},
  }) =>
      WSDemoLabStepResult._(
        stepId: stepId,
        passed: true,
        duration: duration,
        value: value,
      );

  factory WSDemoLabStepResult.failed({
    required String stepId,
    required Duration duration,
    required Object error,
  }) =>
      WSDemoLabStepResult._(
        stepId: stepId,
        passed: false,
        duration: duration,
        error: error,
      );

  final String stepId;
  final bool passed;
  final Duration duration;
  final Map<String, Object?>? value;
  final Object? error;

  Map<String, Object?> toJson() => {
        'stepId': stepId,
        'status': passed ? 'passed' : 'failed',
        'durationMs': duration.inMilliseconds,
        if (value != null) 'value': value,
        if (error != null) 'error': _errorJson(error!),
      };
}

final class _WSDemoLabPlan {
  const _WSDemoLabPlan({
    required this.id,
    required this.name,
    required this.steps,
  });

  final String id;
  final String name;
  final List<_WSDemoLabStep> steps;
}

final class _WSDemoLabStep {
  const _WSDemoLabStep(
    this.id,
    this.run, {
    this.timeout = const Duration(seconds: 15),
  });

  final String id;
  final Duration timeout;
  final Future<Map<String, Object?>> Function(WSDemoController controller) run;
}

_WSDemoLabPlan _plan(String id) => switch (id) {
      'smoke' => _smokePlan,
      'settings' => _settingsPlan,
      'binding' => _bindingPlan,
      'notifications' => _notificationsPlan,
      'history-data' => _historyDataPlan,
      'measurement-sport' => _measurementSportPlan,
      'multi-device' => _multiDevicePlan,
      _ => throw ArgumentError.value(
          id,
          'planId',
          'Expected one of: ${WSDemoLabRunner.availablePlanIds.join(', ')}',
        ),
    };

const _labUserId = '0123456789abcdef0123456789abcdef';
const _labSuperUserId = 'fedcba9876543210fedcba9876543210';

final _smokePlan = _WSDemoLabPlan(
  id: 'smoke',
  name: 'WS simulator SDK smoke',
  steps: [
    _WSDemoLabStep('initialize-and-scan', (controller) async {
      await controller.initialize();
      await _scanSimulator(controller);
      _check(
        controller.devices.any(
          (device) =>
              device.deviceMac == kWsWatchSimDeviceId && device.isSimulated,
        ),
        'Simulator was not returned by the public scan API.',
      );
      return {
        'transport': controller.transportMode.name,
        'deviceCount': controller.devices.length,
      };
    }),
    _WSDemoLabStep('connect-and-bind', (controller) async {
      final device = _device(controller, kWsWatchSimDeviceId);
      _check(await controller.connect(device), 'Simulator did not connect.');
      await controller.bindFirstTime(_labUserId, confirmed: true);
      _check(controller.state.isReady, 'Session did not reach ready.');
      return {
        'deviceId': controller.selectedDeviceId,
        'phase': controller.state.phase.name,
      };
    }),
    _WSDemoLabStep('read-device-profile', (controller) async {
      await controller.readDeviceInfo();
      await controller.readDeviceFeatures();
      final device = controller.state.device;
      final functions = controller.functionInfo;
      _check(device?.modelId == 1, 'Unexpected simulator model id.');
      _check(
        device?.serialNumber == 'WS2026000001',
        'Unexpected simulator serial number.',
      );
      _check(
        functions?.raw.length == 8,
        'Device capability payload was not exposed to the demo.',
      );
      return {
        'modelId': device?.modelId,
        'serialNumber': device?.serialNumber,
        'supportedFunctionCount': functions?.supported.length,
      };
    }),
    _WSDemoLabStep('read-live-values', (controller) async {
      final battery = await controller.readBattery();
      final today = await controller.fetchTodayActivitySummary();
      _check(battery == 75, 'Unexpected simulator battery value: $battery');
      _check(
        today?.steps == 0x146E,
        'Unexpected simulator today steps: ${today?.steps}',
      );
      _check(
        today?.distanceMeters == 0x0E42,
        'Unexpected simulator today distance: ${today?.distanceMeters}',
      );
      return {
        'batteryPercent': battery,
        'steps': today?.steps,
        'distanceMeters': today?.distanceMeters,
      };
    }),
    _WSDemoLabStep('heart-rate-setting-roundtrip', (controller) async {
      final original = await controller.readHeartRateAutoMeasure();
      final changed = WSAutoMeasureConfig(
        enabled: !original.enabled,
        intervalMinutes: original.intervalMinutes,
      );
      var restored = false;
      try {
        await controller.setHeartRateAutoMeasure(changed);
        final readBack = await controller.readHeartRateAutoMeasure();
        _check(
          _sameAutoMeasure(readBack, changed),
          'Heart-rate setting readback did not match the write.',
        );
        await controller.setHeartRateAutoMeasure(original);
        final restoredValue = await controller.readHeartRateAutoMeasure();
        _check(
          _sameAutoMeasure(restoredValue, original),
          'Heart-rate setting was not restored.',
        );
        restored = true;
        return {
          'changedEnabled': changed.enabled,
          'intervalMinutes': changed.intervalMinutes,
          'restored': true,
        };
      } finally {
        if (!restored) {
          await controller.setHeartRateAutoMeasure(original);
        }
      }
    }),
    _WSDemoLabStep('heart-rate-spot-measure', (controller) async {
      var started = false;
      try {
        await controller.startHeartRateMeasure();
        started = true;
      } finally {
        if (started) await controller.stopHeartRateMeasure();
      }
      return {'startStop': 'passed'};
    }),
    _WSDemoLabStep('history-sync', (controller) async {
      final session = controller.session;
      _check(session != null, 'Session disappeared before history sync.');
      final sync = controller.syncFor(session!);
      await sync.start(session);
      final state = sync.state;
      _check(
        state.phase == WsHistorySyncPhase.success,
        'History sync did not finish successfully.',
      );
      _check(
        state.receivedWire == state.totalWire,
        'History sync wire count is incomplete.',
      );
      return {'receivedWire': state.receivedWire, 'totalWire': state.totalWire};
    }, timeout: const Duration(seconds: 30)),
  ],
);

final _settingsPlan = _connectedPlan(
  id: 'settings',
  name: 'WS 0x02 settings round trips',
  steps: [
    _WSDemoLabStep('display-language-and-units', (controller) async {
      final settings = _session(controller).settings;
      final originalDisplay = await settings.readDisplayFormat();
      final originalLanguage = await settings.readLanguage();
      final originalBpUnit = await settings.readBloodPressureUnit();
      final originalGlucoseUnit = await settings.readBloodGlucoseUnit();
      final originalTemperatureUnit = await settings.readTemperatureUnit();
      final changedDisplay = WSDisplayFormat(
        hour12: !originalDisplay.hour12,
        dayFirst: !originalDisplay.dayFirst,
        imperialDistance: !originalDisplay.imperialDistance,
        pounds: !originalDisplay.pounds,
      );
      try {
        await settings.setDisplayFormat(changedDisplay);
        await settings.setLanguage(originalLanguage == 0 ? 1 : 0);
        await settings.setBloodPressureUnit(
          originalBpUnit == WSBloodPressureUnit.mmHg
              ? WSBloodPressureUnit.kPa
              : WSBloodPressureUnit.mmHg,
        );
        await settings.setBloodGlucoseUnit(
          originalGlucoseUnit == WSBloodGlucoseUnit.mmolPerLiter
              ? WSBloodGlucoseUnit.mgPerDeciliter
              : WSBloodGlucoseUnit.mmolPerLiter,
        );
        await settings.setTemperatureUnit(
          originalTemperatureUnit == WSTemperatureUnit.celsius
              ? WSTemperatureUnit.fahrenheit
              : WSTemperatureUnit.celsius,
        );
        final display = await settings.readDisplayFormat();
        _check(
            _sameDisplay(display, changedDisplay), 'Display format mismatch.');
        _check(
          await settings.readLanguage() != originalLanguage,
          'Language was not changed.',
        );
        _check(
          await settings.readBloodPressureUnit() != originalBpUnit,
          'Blood-pressure unit was not changed.',
        );
        _check(
          await settings.readBloodGlucoseUnit() != originalGlucoseUnit,
          'Blood-glucose unit was not changed.',
        );
        _check(
          await settings.readTemperatureUnit() != originalTemperatureUnit,
          'Temperature unit was not changed.',
        );
      } finally {
        await settings.setDisplayFormat(originalDisplay);
        await settings.setLanguage(originalLanguage);
        await settings.setBloodPressureUnit(originalBpUnit);
        await settings.setBloodGlucoseUnit(originalGlucoseUnit);
        await settings.setTemperatureUnit(originalTemperatureUnit);
      }
      return {'roundTrips': 5, 'restored': true};
    }),
    _WSDemoLabStep('automatic-monitor-schedules', (controller) async {
      final measure = _session(controller).measure;
      final operations = <_ScheduleOperation>[
        _ScheduleOperation(
          'heartRate',
          measure.readHeartRateAutoMeasureSchedule,
          measure.setHeartRateAutoMeasureSchedule,
        ),
        _ScheduleOperation(
          'hrv',
          measure.readHrvAutoMeasure,
          measure.setHrvAutoMeasure,
        ),
        _ScheduleOperation(
          'bloodPressure',
          measure.readBloodPressureAutoMeasureSchedule,
          measure.setBloodPressureAutoMeasureSchedule,
        ),
        _ScheduleOperation(
          'bloodGlucose',
          measure.readBloodSugarAutoMeasureSchedule,
          measure.setBloodSugarAutoMeasureSchedule,
        ),
        _ScheduleOperation(
          'spo2',
          measure.readSpO2AutoMeasureSchedule,
          measure.setSpO2AutoMeasureSchedule,
        ),
        _ScheduleOperation(
          'pressure',
          measure.readPressureAutoMeasure,
          measure.setPressureAutoMeasureSchedule,
        ),
        _ScheduleOperation(
          'temperature',
          measure.readTemperatureAutoMeasureSchedule,
          measure.setTemperatureAutoMeasureSchedule,
        ),
        _ScheduleOperation(
          'heatStress',
          measure.readHeatStressAutoMeasure,
          measure.setHeatStressAutoMeasure,
        ),
      ];
      for (var i = 0; i < operations.length; i++) {
        await _roundTripSchedule(operations[i], i);
      }
      return {'scheduleCount': operations.length, 'restored': true};
    }, timeout: const Duration(seconds: 30)),
    _WSDemoLabStep('alarms-and-health-warnings', (controller) async {
      final settings = _session(controller).settings;
      final originalHeartRate = await settings.readHeartRateHighAlarm();
      final originalSpO2 = await settings.readSpO2LowAlarm();
      try {
        final heartRate = WSHeartRateHighAlarm(
          enabled: !originalHeartRate.enabled,
          thresholdBpm: originalHeartRate.thresholdBpm == 130 ? 120 : 130,
        );
        final spo2 = WSSpO2LowAlarm(
          enabled: !originalSpO2.enabled,
          thresholdPercent: originalSpO2.thresholdPercent == 88 ? 90 : 88,
        );
        await settings.setHeartRateHighAlarm(heartRate);
        await settings.setSpO2LowAlarm(spo2);
        final readHeartRate = await settings.readHeartRateHighAlarm();
        final readSpO2 = await settings.readSpO2LowAlarm();
        _check(
          readHeartRate.enabled == heartRate.enabled &&
              readHeartRate.thresholdBpm == heartRate.thresholdBpm,
          'Heart-rate warning mismatch.',
        );
        _check(
          readSpO2.enabled == spo2.enabled &&
              readSpO2.thresholdPercent == spo2.thresholdPercent,
          'SpO2 warning mismatch.',
        );
      } finally {
        await settings.setHeartRateHighAlarm(originalHeartRate);
        await settings.setSpO2LowAlarm(originalSpO2);
      }
      final genericAlarms = <_HealthAlarmOperation>[
        _HealthAlarmOperation(
          'hrv',
          settings.readHrvAlarm,
          settings.setHrvAlarm,
        ),
        _HealthAlarmOperation(
          'bloodPressure',
          settings.readBloodPressureAlarm,
          settings.setBloodPressureAlarm,
        ),
        _HealthAlarmOperation(
          'bloodGlucose',
          settings.readBloodGlucoseAlarm,
          settings.setBloodGlucoseAlarm,
        ),
        _HealthAlarmOperation(
          'pressure',
          settings.readPressureAlarm,
          settings.setPressureAlarm,
        ),
        _HealthAlarmOperation(
          'temperature',
          settings.readTemperatureAlarm,
          settings.setTemperatureAlarm,
        ),
      ];
      for (var i = 0; i < genericAlarms.length; i++) {
        await _roundTripHealthAlarm(genericAlarms[i], i);
      }
      return {
        'warningCount': 2 + genericAlarms.length,
        'restored': true,
      };
    }),
    _WSDemoLabStep('general-settings', (controller) async {
      final settings = _session(controller).settings;
      final originalPowerSaving = await settings.readPowerSaving();
      final originalGoals = await settings.readGoals();
      final originalWrist = await settings.readWrist();
      final originalBrightness = await settings.readBrightness();
      final originalScreenSeconds = await settings.readScreenOnSeconds();
      final originalRaise = await settings.readRaiseToWake();
      final originalDnd = await settings.readDoNotDisturb();
      final originalHealthBits = await settings.readHealthDisplayBits();
      final originalNotificationBits =
          await settings.readNotificationSwitches();
      try {
        await settings.setPowerSaving(!originalPowerSaving);
        await settings.setGoals(const WSActivityGoals(
          steps: 12000,
          caloriesKcal: 500,
          sleepMinutes: 480,
          distanceMeters: 8000,
          activeMinutes: 60,
        ));
        await settings.setWrist(originalWrist == 0 ? 1 : 0);
        await settings.setBrightness(originalBrightness == 65 ? 75 : 65);
        await settings.setScreenOnSeconds(
          originalScreenSeconds == 8 ? 10 : 8,
        );
        await settings.setRaiseToWake(const WSTimeWindowSetting(
          enabled: true,
          startHour: 6,
          startMinute: 30,
          endHour: 23,
          endMinute: 0,
        ));
        await settings.setDoNotDisturb(const WSTimeWindowSetting(
          enabled: true,
          startHour: 22,
          startMinute: 15,
          endHour: 7,
          endMinute: 45,
        ));
        await settings.setHealthDisplayBits(originalHealthBits ^ 0x01);
        final changedNotificationBits = Uint8List.fromList(
          originalNotificationBits,
        );
        changedNotificationBits[0] ^= 0x01;
        await settings.setNotificationSwitches(changedNotificationBits);
        await settings.setUserProfile(const WSUserProfile(
          gender: 1,
          birthYear: 1990,
          birthMonth: 6,
          birthDay: 15,
          heightTenthCm: 1750,
          weightTenthKg: 700,
        ));
        await settings.setFemaleHealth(const WSFemaleHealthSetting(
          enabled: true,
          cycleDays: 28,
          periodDays: 5,
          lastPeriodYear: 2026,
          lastPeriodMonth: 11,
          lastPeriodDay: 1,
          reminderBits: 3,
          reminderHour: 8,
          reminderMinute: 30,
        ));
        _check(
          await settings.readPowerSaving() == !originalPowerSaving,
          'Power saving mismatch.',
        );
        _check((await settings.readGoals()).steps == 12000, 'Goals mismatch.');
        _check(
          await settings.readBrightness() != originalBrightness,
          'Brightness mismatch.',
        );
        _check(
          (await settings.readRaiseToWake()).startMinute == 30,
          'Raise-to-wake mismatch.',
        );
        _check(
          (await settings.readDoNotDisturb()).endMinute == 45,
          'Do-not-disturb mismatch.',
        );
        _check(
          (await settings.readNotificationSwitches())[0] ==
              changedNotificationBits[0],
          'Notification switches mismatch.',
        );
      } finally {
        await settings.setPowerSaving(originalPowerSaving);
        await settings.setGoals(originalGoals);
        await settings.setWrist(originalWrist);
        await settings.setBrightness(originalBrightness);
        await settings.setScreenOnSeconds(originalScreenSeconds);
        await settings.setRaiseToWake(originalRaise);
        await settings.setDoNotDisturb(originalDnd);
        await settings.setHealthDisplayBits(originalHealthBits);
        await settings.setNotificationSwitches(originalNotificationBits);
      }
      return {'readWriteSettings': 9, 'writeOnlySettings': 2, 'restored': true};
    }),
    _WSDemoLabStep('reminders-weather-and-lists', (controller) async {
      final settings = _session(controller).settings;
      await settings.setIntervalReminder(const WSIntervalReminderSetting(
        type: 1,
        enabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 18,
        endMinute: 0,
        intervalMinutes: 60,
      ));
      final reminder = await settings.readIntervalReminder(1);
      _check(reminder.intervalMinutes == 60, 'Interval reminder mismatch.');
      await settings.setWeather(WSWeatherSetting(
        updatedAtSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        city: 'Shenzhen',
        type: 1,
        currentCelsius: 26,
        highCelsius: 30,
        lowCelsius: 22,
        humidityPercent: 70,
        uvIndex: 4,
        aqi: 35,
        forecast: const [
          WSWeatherDay(type: 2, highCelsius: 29, lowCelsius: 21),
        ],
      ));
      await settings.clearWeather();

      await settings.clearAlarms();
      const alarm = WSAlarmSetting(
        slot: 2,
        enabled: true,
        hour: 7,
        minute: 30,
        repeatBits: 0x1f,
        label: 'lab',
      );
      await settings.addAlarm(alarm);
      _check((await settings.readAlarms()).items.single.label == 'lab',
          'Alarm add failed.');
      await settings.modifyAlarm(const WSAlarmSetting(
        slot: 2,
        enabled: true,
        hour: 8,
        minute: 15,
        repeatBits: 0x7f,
        label: 'lab2',
      ));
      _check((await settings.readAlarms()).items.single.hour == 8,
          'Alarm modify failed.');
      await settings.deleteAlarm(alarm);
      _check(
          (await settings.readAlarms()).items.isEmpty, 'Alarm delete failed.');

      await settings.clearContacts();
      const contact = WSContactSetting(
        slot: 3,
        name: 'Lab',
        number: '13800138000',
      );
      await settings.addContact(contact);
      _check((await settings.readContacts()).items.single.name == 'Lab',
          'Contact add failed.');
      await settings.modifyContact(const WSContactSetting(
        slot: 3,
        name: 'Lab2',
        number: '13900139000',
      ));
      _check((await settings.readContacts()).items.single.name == 'Lab2',
          'Contact modify failed.');
      await settings.deleteContact(contact);
      _check(
        (await settings.readContacts()).items.isEmpty,
        'Contact delete failed.',
      );
      return {'alarmCrud': true, 'contactCrud': true, 'weatherSent': true};
    }),
  ],
);

final _bindingPlan = _WSDemoLabPlan(
  id: 'binding',
  name: 'WS 0x03 binding lifecycle',
  steps: [
    _WSDemoLabStep('initialize-and-connect', (controller) async {
      await _initializeAndConnect(controller);
      return {'phase': controller.state.phase.name};
    }),
    _WSDemoLabStep('login-first-authenticate', (controller) async {
      await controller.login(_labUserId);
      _check(
        controller.state.phase == WSSessionPhase.loginRejected,
        'Unbound login should be rejected.',
      );
      final authenticated = await _session(controller).authenticate(
        _labUserId,
        bindIfNeeded: true,
        bindConfirmed: true,
      );
      _check(authenticated && controller.state.isReady,
          'Login-first authenticate did not bind.');
      return {'authenticated': authenticated, 'userId': _labUserId};
    }),
    _WSDemoLabStep('explicit-unbind', (controller) async {
      await _expectThrows(
        () => controller.unbind(confirmed: false),
        'Unbind without confirmation must fail.',
      );
      final oldSession = _session(controller);
      await controller.unbind(confirmed: true);
      _check(oldSession.isDisposed, 'Unbind did not dispose the session.');
      return {'guarded': true, 'disposed': true};
    }),
    _WSDemoLabStep('super-bind-after-unbind', (controller) async {
      final device = _device(controller, kWsWatchSimDeviceId);
      _check(
          await controller.connect(device), 'Reconnect after unbind failed.');
      await controller.login(_labUserId);
      _check(
        controller.state.phase == WSSessionPhase.loginRejected,
        'Unbound device unexpectedly accepted login.',
      );
      await _expectThrows(
        () => _session(controller).superBind(
          _labSuperUserId,
          'lab-super-key',
          confirmed: false,
        ),
        'Super bind without confirmation must fail.',
      );
      await _session(controller).superBind(
        _labSuperUserId,
        'lab-super-key',
        confirmed: true,
      );
      _check(controller.state.isReady, 'Super bind did not reach ready.');
      _check(
        _session(controller).authenticatedUserId == _labSuperUserId,
        'Super bind user was not retained.',
      );
      return {'superBound': true, 'userId': _labSuperUserId};
    }),
  ],
);

final _notificationsPlan = _connectedPlan(
  id: 'notifications',
  name: 'WS 0x04 notifications and reverse events',
  steps: [
    _WSDemoLabStep('app-to-watch-commands', (controller) async {
      final notifications = _session(controller).notifications;
      final batteryEvent =
          notifications.events.firstWhere((event) => event is WSBatteryEvent);
      final callEvent = notifications.events
          .firstWhere((event) => event is WSCallActionEvent);
      final musicControlEvent = notifications.events
          .firstWhere((event) => event is WSMusicControlEvent);
      final musicRequestEvent = notifications.events
          .firstWhere((event) => event is WSMusicStateRequestedEvent);
      final findWatchEvent = notifications.events
          .firstWhere((event) => event is WSFindWatchEndedEvent);
      final findPhoneEvent =
          notifications.events.firstWhere((event) => event is WSFindPhoneEvent);
      final cameraEvent = notifications.events
          .firstWhere((event) => event is WSCameraShutterEvent);

      final battery = await notifications.queryBattery();
      await notifications.pushIncomingCall(const WSIncomingCall(
        number: '13800138000',
        name: 'Lab Caller',
      ));
      await notifications.updateCallState(1);
      await notifications.pushMessage(WSAppNotification(
        id: 42,
        applicationType: 1,
        wallTimeSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Lab',
        content: 'WS notification test',
      ));
      await notifications.deleteMessage(42);
      await notifications.clearMessages();
      await notifications.updateMusicState(const WSMusicState(
        playbackState: 1,
        volumePercent: 60,
        song: 'Protocol Song',
        artist: 'WS Lab',
      ));
      await notifications.findWatch(true);
      await notifications.finishFindPhone(0);
      await notifications.setCameraOpen(true);
      await Future.wait([
        batteryEvent,
        callEvent,
        musicControlEvent,
        musicRequestEvent,
        findWatchEvent,
        findPhoneEvent,
        cameraEvent,
      ]).timeout(const Duration(seconds: 5));
      _check(battery.percent == 75, 'Notification battery query mismatch.');
      return {
        'batteryPercent': battery.percent,
        'sentCommandCount': 10,
        'reverseEventCount': 7,
      };
    }),
  ],
);

final _historyDataPlan = _connectedPlan(
  id: 'history-data',
  name: 'WS 0x05 data and history',
  steps: [
    _WSDemoLabStep('capabilities-today-and-sport-detail', (controller) async {
      final session = _session(controller);
      final capabilities = await session.history.queryDeviceDataCapabilities();
      _check(capabilities.displayWidth == 410, 'Capability width mismatch.');
      final originalConfig = await session.today.readNotificationConfig();
      _check(originalConfig.isSuccess, 'Today config read failed.');
      final changed = WSTodayNotificationConfig(
        enabled: !originalConfig.config.enabled,
        startHour: 7,
        startMinute: 15,
        endHour: 22,
        endMinute: 45,
        intervalMinutes: 5,
      );
      try {
        final result = await session.today.setNotificationConfig(changed);
        _check(result.isSuccess, 'Today config write failed.');
        final readBack = await session.today.readNotificationConfig();
        _check(
          _sameTodayConfig(readBack.config, changed),
          'Today config readback mismatch.',
        );
      } finally {
        await session.today.setNotificationConfig(originalConfig.config);
      }
      final detail = await session.history.fetchSportDetail(42);
      _check(detail.sportId == 42 && detail.points.isNotEmpty,
          'Sport detail framing failed.');
      return {
        'displayWidth': capabilities.displayWidth,
        'sportPointCount': detail.points.length,
        'todayConfigRestored': true,
      };
    }),
    _WSDemoLabStep('single-type-sync-and-storage', (controller) async {
      final history = _session(controller).history;
      final received = await history.syncHeartRate();
      final stored = await history.queryHeartRates();
      _check(received.isNotEmpty, 'Single-type heart-rate sync was empty.');
      _check(stored.isNotEmpty, 'Heart-rate sync was not persisted.');
      return {'received': received.length, 'stored': stored.length};
    }, timeout: const Duration(seconds: 30)),
    _WSDemoLabStep('full-sync-mutual-exclusion', (controller) async {
      final session = _session(controller);
      final sync = session.syncHealthData(const WSHistorySyncNoOpListener());
      await _expectThrows(
        () => session.history.fetchSportDetail(42),
        'Sport detail must be blocked during full sync.',
      );
      await _expectThrows(
        () => session.measure.startHeartRateSpot(),
        'Spot measurement must be blocked during full sync.',
      );
      await sync;
      _check(
          !session.isHealthSyncActive, 'Full sync active flag was not reset.');
      return {'mutualExclusion': true, 'syncFinished': true};
    }, timeout: const Duration(seconds: 30)),
  ],
);

final _measurementSportPlan = _connectedPlan(
  id: 'measurement-sport',
  name: 'WS 0x11 spot measurement and sport',
  steps: [
    _WSDemoLabStep('all-spot-measurement-lanes', (controller) async {
      final measure = _session(controller).measure;
      final initial = await measure.querySpotStatus();
      _check(!initial.active, 'Spot measurement should initially be idle.');
      final cases = <_SpotOperation>[
        _SpotOperation('heartRate', WSSpotMeasureLanes.heartRate,
            measure.startHeartRateSpot),
        _SpotOperation('bloodPressure', WSSpotMeasureLanes.bloodPressure,
            measure.startBloodPressureSpotMeasure),
        _SpotOperation('bloodOxygen', WSSpotMeasureLanes.bloodOxygen,
            measure.startSpO2SpotMeasure),
        _SpotOperation(
            'hrv', WSSpotMeasureLanes.hrv, measure.startHrvSpotMeasure),
        _SpotOperation('pressure', WSSpotMeasureLanes.pressure,
            measure.startPressureSpotMeasure),
        _SpotOperation('temperature', WSSpotMeasureLanes.temperature,
            measure.startTemperatureSpotMeasure),
        _SpotOperation('bloodGlucose', WSSpotMeasureLanes.bloodGlucose,
            measure.startBloodGlucoseSpotMeasure),
        _SpotOperation(
          'continuousHeartRate',
          WSSpotMeasureLanes.continuousHeartRate,
          measure.startContinuousHeartRate,
        ),
      ];
      for (final operation in cases) {
        final realtime = measure.events
            .where((event) =>
                event is WSSpotRealtimeEvent && event.lane == operation.lane)
            .cast<WSSpotRealtimeEvent>()
            .first;
        final result = measure.events
            .where((event) =>
                event is WSSpotResultEvent && event.lane == operation.lane)
            .cast<WSSpotResultEvent>()
            .first;
        await operation.start();
        final active = await measure.querySpotStatus();
        _check(
          active.active && active.dataTypeCode == operation.lane.dataTypeCode,
          '${operation.name} status was not active.',
        );
        final values = await Future.wait([realtime, result])
            .timeout(const Duration(seconds: 5));
        final resultEvent = values[1] as WSSpotResultEvent;
        _check(resultEvent.result == 0, '${operation.name} did not succeed.');
        if (operation.lane != WSSpotMeasureLanes.continuousHeartRate) {
          _check(
            resultEvent.record != null,
            '${operation.name} result record was not decoded.',
          );
        }
      }
      _check(!(await measure.querySpotStatus()).active,
          'Spot measurement did not return to idle.');
      return {'laneCount': cases.length, 'allDecoded': true};
    }, timeout: const Duration(seconds: 30)),
    _WSDemoLabStep('sport-lifecycle-and-events', (controller) async {
      final measure = _session(controller).measure;
      final modes = await measure.querySportModes();
      _check(modes.isNotEmpty, 'No sport modes returned.');
      final realtime = measure.events
          .where((event) => event is WSSportRealtimeEvent)
          .cast<WSSportRealtimeEvent>()
          .first;
      final ended = measure.events
          .where((event) => event is WSSportEndedEvent)
          .cast<WSSportEndedEvent>()
          .first;
      await measure.subscribeSportRealtime();
      _check(await measure.startSport(modes.first) == 0, 'Sport start failed.');
      _check((await measure.querySportState()).hasActiveSport,
          'Sport state was not active.');
      await measure.controlSport(1);
      _check((await measure.querySportState()).snapshot?.state == 2,
          'Sport did not pause.');
      await measure.controlSport(2);
      _check((await measure.querySportState()).snapshot?.state == 1,
          'Sport did not resume.');
      final realtimeEvent = await realtime.timeout(const Duration(seconds: 5));
      _check(realtimeEvent.snapshot.mode == modes.first,
          'Sport realtime mode mismatch.');
      await measure.controlSport(0);
      final endEvent = await ended.timeout(const Duration(seconds: 5));
      _check(endEvent.result == 0, 'Sport end result failed.');
      _check(!(await measure.querySportState()).hasActiveSport,
          'Sport remained active after ending.');
      await measure.unsubscribeSportRealtime();
      return {
        'modeCount': modes.length,
        'pausedResumed': true,
        'realtimeReceived': true,
        'endReceived': true,
      };
    }),
  ],
);

final _multiDevicePlan = _WSDemoLabPlan(
  id: 'multi-device',
  name: 'WS simulator multi-device isolation',
  steps: [
    _WSDemoLabStep('initialize-and-scan', (controller) async {
      await controller.initialize();
      await _scanSimulator(controller);
      for (final id in [kWsWatchSimDeviceId, kWsWatchSimDeviceId2]) {
        _device(controller, id);
      }
      return {'deviceCount': controller.devices.length};
    }),
    _WSDemoLabStep('connect-two-watches', (controller) async {
      for (final id in [kWsWatchSimDeviceId, kWsWatchSimDeviceId2]) {
        _check(
          await controller.connect(_device(controller, id)),
          'Failed to connect $id.',
        );
        await controller.bindFirstTime(_labUserId, confirmed: true);
      }
      _check(
        controller.attachedSessions.length == 2,
        'Expected two attached simulator sessions.',
      );
      return {'sessionCount': controller.attachedSessions.length};
    }),
    _WSDemoLabStep('parallel-history-sync', (controller) async {
      final sessions = controller.attachedSessions;
      await Future.wait([
        for (final entry in sessions)
          controller.syncFor(entry.session).start(entry.session),
      ]);
      for (final entry in sessions) {
        _check(
          controller.syncFor(entry.session).state.phase ==
              WsHistorySyncPhase.success,
          'History sync failed for ${entry.deviceId}.',
        );
      }
      return {'syncedSessionCount': sessions.length};
    }, timeout: const Duration(seconds: 30)),
    _WSDemoLabStep('disconnect-isolation', (controller) async {
      await controller.disconnectDevice(kWsWatchSimDeviceId);
      final remaining = controller.attachedSessions;
      _check(remaining.length == 1, 'Disconnect removed the wrong sessions.');
      _check(
        remaining.single.deviceId == kWsWatchSimDeviceId2,
        'The second simulator session did not remain attached.',
      );
      _check(
        remaining.single.state.isReady,
        'The second simulator session was disrupted.',
      );
      controller.selectDevice(kWsWatchSimDeviceId2);
      final battery = await controller.readBattery();
      _check(battery == 55, 'Unexpected second simulator battery: $battery');
      return {
        'remainingDeviceId': remaining.single.deviceId,
        'batteryPercent': battery,
      };
    }),
  ],
);

_WSDemoLabPlan _connectedPlan({
  required String id,
  required String name,
  required List<_WSDemoLabStep> steps,
}) =>
    _WSDemoLabPlan(
      id: id,
      name: name,
      steps: [
        _WSDemoLabStep('initialize-connect-and-bind', (controller) async {
          await _initializeAndConnect(controller);
          await controller.bindFirstTime(_labUserId, confirmed: true);
          _check(controller.state.isReady, 'Session did not reach ready.');
          return {
            'deviceId': controller.selectedDeviceId,
            'phase': controller.state.phase.name,
          };
        }),
        ...steps,
      ],
    );

Future<void> _initializeAndConnect(WSDemoController controller) async {
  await controller.initialize();
  await _scanSimulator(controller);
  final device = _device(controller, kWsWatchSimDeviceId);
  _check(await controller.connect(device), 'Simulator did not connect.');
}

WSWatchSession _session(WSDemoController controller) {
  final session = controller.session;
  if (session == null) throw StateError('Lab session is unavailable.');
  return session;
}

final class _ScheduleOperation {
  const _ScheduleOperation(this.name, this.read, this.write);

  final String name;
  final Future<WSAutoMeasureSchedule> Function() read;
  final Future<void> Function(WSAutoMeasureSchedule value) write;
}

Future<void> _roundTripSchedule(_ScheduleOperation operation, int index) async {
  final original = await operation.read();
  final changed = WSAutoMeasureSchedule(
    enabled: !original.enabled,
    startHour: 6 + (index % 3),
    startMinute: 5 + index,
    endHour: 20 + (index % 3),
    endMinute: 40 + index,
    intervalMinutes: 10 + index,
  );
  try {
    await operation.write(changed);
    final readBack = await operation.read();
    _check(
      _sameSchedule(readBack, changed),
      '${operation.name} automatic schedule mismatch.',
    );
  } finally {
    await operation.write(original);
  }
}

final class _SpotOperation {
  const _SpotOperation(this.name, this.lane, this.start);

  final String name;
  final WSSpotMeasureLane lane;
  final Future<void> Function() start;
}

final class _HealthAlarmOperation {
  const _HealthAlarmOperation(this.name, this.read, this.write);

  final String name;
  final Future<WSHealthAlarmSetting> Function() read;
  final Future<void> Function(WSHealthAlarmSetting value) write;
}

Future<void> _roundTripHealthAlarm(
  _HealthAlarmOperation operation,
  int index,
) async {
  final original = await operation.read();
  final changed = WSHealthAlarmSetting(
    highEnabled: !original.highEnabled,
    highThreshold: Uint8List.fromList([0, 100 + index]),
    lowEnabled: !original.lowEnabled,
    lowThreshold: Uint8List.fromList([0, 40 + index]),
    startHour: 7,
    startMinute: 15 + index,
    endHour: 22,
    endMinute: 30 + index,
  );
  try {
    await operation.write(changed);
    final readBack = await operation.read();
    _check(
      _sameHealthAlarm(readBack, changed),
      '${operation.name} health alarm mismatch.',
    );
  } finally {
    await operation.write(original);
  }
}

Future<void> _expectThrows(
  Future<void> Function() operation,
  String message,
) async {
  try {
    await operation();
  } catch (_) {
    return;
  }
  throw StateError(message);
}

WSScanDevice _device(WSDemoController controller, String id) {
  return controller.devices.firstWhere(
    (device) => device.deviceMac == id,
    orElse: () => throw StateError('Scan did not return $id.'),
  );
}

Future<void> _scanSimulator(WSDemoController controller) async {
  await controller.startScan();
  // Scan result streams are asynchronous. Stopping publishes the controller's
  // latest internal snapshot immediately, without relying on a rendered frame.
  await Future<void>.delayed(Duration.zero);
  await controller.stopScan();
}

bool _sameAutoMeasure(WSAutoMeasureConfig left, WSAutoMeasureConfig right) =>
    left.enabled == right.enabled &&
    left.intervalMinutes == right.intervalMinutes;

bool _sameDisplay(WSDisplayFormat left, WSDisplayFormat right) =>
    left.hour12 == right.hour12 &&
    left.dayFirst == right.dayFirst &&
    left.imperialDistance == right.imperialDistance &&
    left.pounds == right.pounds;

bool _sameSchedule(
  WSAutoMeasureSchedule left,
  WSAutoMeasureSchedule right,
) =>
    left.enabled == right.enabled &&
    left.startHour == right.startHour &&
    left.startMinute == right.startMinute &&
    left.endHour == right.endHour &&
    left.endMinute == right.endMinute &&
    left.intervalMinutes == right.intervalMinutes;

bool _sameTodayConfig(
  WSTodayNotificationConfig left,
  WSTodayNotificationConfig right,
) =>
    left.enabled == right.enabled &&
    left.startHour == right.startHour &&
    left.startMinute == right.startMinute &&
    left.endHour == right.endHour &&
    left.endMinute == right.endMinute &&
    left.intervalMinutes == right.intervalMinutes;

bool _sameHealthAlarm(
  WSHealthAlarmSetting left,
  WSHealthAlarmSetting right,
) =>
    left.highEnabled == right.highEnabled &&
    _sameBytes(left.highThreshold, right.highThreshold) &&
    left.lowEnabled == right.lowEnabled &&
    _sameBytes(left.lowThreshold, right.lowThreshold) &&
    left.startHour == right.startHour &&
    left.startMinute == right.startMinute &&
    left.endHour == right.endHour &&
    left.endMinute == right.endMinute;

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Map<String, Object?> _errorJson(Object error) => {
      'type': error.runtimeType.toString(),
      'message': error.toString(),
      if (error is WSException) 'code': error.code.name,
    };
