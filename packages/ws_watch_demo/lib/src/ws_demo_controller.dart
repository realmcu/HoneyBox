import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

import 'compat/ws_demo_compat.dart';
import 'ws_demo_last_device_store.dart';
import 'ws_demo_time.dart';
import 'ws_history_sync_run_controller.dart';
import 'ws_demo_log.dart';

const _kDemoDayRange = WSTimeRange(
  startHour: 0,
  startMinute: 0,
  endHour: 23,
  endMinute: 59,
);

final _kDemoNotifySettings = WSNotifySettings.all(false);

/// Turns public SDK errors into short, actionable UI copy.
///
/// The SDK deliberately keeps [WSException.msg] in English for
/// developers. The Demo owns localized end-user wording and must make it
/// clear that command failures do not imply that the BLE session disconnected.
String describeWSDemoError(Object error) {
  if (error is WSException) {
    return switch (error.code) {
      WSErrorCode.businessReplyTimeout =>
        '设备在 5 秒内未回应此设置查询；该功能可能不支持或设备暂时忙，当前连接仍保持。',
      WSErrorCode.ackTimeout => '设备未确认本次发送；当前连接仍保持，可稍后重试。',
      WSErrorCode.nack => '设备拒绝了本次命令；当前连接仍保持。',
      WSErrorCode.writeTimeout ||
      WSErrorCode.writeFailed =>
        '本次蓝牙写入失败；当前连接仍保持，可重试。',
      WSErrorCode.transportDisconnected => '设备连接已断开。',
      WSErrorCode.historySyncIdleTimeout =>
        '同步超过 ${kWSHistorySyncIdleTimeout.inSeconds} 秒无进展；本轮已结束，连接可能仍保持。',
      _ => 'SDK error [${error.code.name}]: ${error.msg}',
    };
  }
  return error.toString();
}

/// Demo-side composition of public WS SDK session objects.
///
/// This controller never writes GATT bytes or imports transport packages; it
/// only coordinates the public scanner, session, and login APIs.
///
/// **Errors:** SDK methods throw on failure. This class does not swallow
/// exceptions into a global bus — callers use `try/catch` (see [wsDemoRunWithSnackBar]).
/// [_runSession] only syncs [state] and [sessionBusy], then rethrows.
///
/// Scan result updates use [scanDevices] so high-frequency BLE advertisements
/// coalesce to at most one UI refresh per frame.
///
/// Transport (simulator vs BLE) is fixed by [WSConfig] on the underlying
/// [WSWatch]. Use [setTransportMode] to rebuild the SDK instance; connection UI
/// does not branch on device type beyond ordinary scan → connect.
class WSDemoController extends ChangeNotifier {
  WSDemoController({
    WSConfig config = const WSConfig.simulation(),
    WSWatch? watch,
  })  : _config = watch?.config ?? config,
        _watch = watch ?? WSWatch(config: config) {
    _attachWatchStreams(_watch);
  }

  WSConfig _config;
  WSWatch _watch;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final ValueNotifier<List<WSScanDevice>> scanDevices = ValueNotifier(const []);
  final ValueNotifier<bool> scanActive = ValueNotifier(false);

  /// In-flight SDK calls (`_runSession` / `_runSessionValue`); drives one global progress strip.
  final ValueNotifier<int> sessionBusy = ValueNotifier(0);

  bool get isSessionBusy => sessionBusy.value > 0;
  bool _scanUiUpdateScheduled = false;
  bool _uiNotifyScheduled = false;

  List<WSScanDevice> _devices = const [];
  String? _selectedDeviceId;
  String? get selectedDeviceId => _selectedDeviceId;
  List<WSAttachedSession> get attachedSessions =>
      _watch.attachedSessionsSnapshot;
  WSWatchSession? get _session =>
      _selectedDeviceId == null ? null : _watch.sessionOf(_selectedDeviceId!);
  final _syncs = <WSWatchSession, WsHistorySyncRunController>{};
  final _deviceErrors = <WSWatchSession, Object>{};
  Object? get error => _deviceErrors[_session];
  final _busy = <WSWatchSession, int>{};
  final _logs = <String, List<String>>{};
  WsHistorySyncRunController syncFor(WSWatchSession session) =>
      _syncs.putIfAbsent(session, WsHistorySyncRunController.new);
  void selectDevice(String id) {
    final target = _watch.sessionOf(id);
    if (target == null) throw StateError('Device session unavailable');
    _selectedDeviceId = target.connection.target.deviceId;
    _refreshBusy();
    _notifyUi();
  }

  void _refreshBusy() {
    if (!_disposed) sessionBusy.value = _busy[_session] ?? 0;
  }

  String _userId = '123456';
  WSSessionState get _state =>
      _session?.state ??
      const WSSessionState(phase: WSSessionPhase.disconnected);
  bool _disposed = false;
  List<String> get _sessionLog =>
      _logs.putIfAbsent(_selectedDeviceId ?? "", () => []);

  List<WSScanDevice> get devices => scanDevices.value;
  WSWatchSession? get session => _session;
  WSSessionState get state => _state;
  bool get isScanning => scanActive.value;
  bool get isInitialized => _watch.isInitialized;
  bool get isConnecting => _connecting;
  List<String> get sessionLog => List.unmodifiable(_sessionLog);
  String get userId => _userId;
  bool _connecting = false;
  WSScanDevice? _connectingDevice;

  Listenable get scanListenable => Listenable.merge([scanDevices, scanActive]);

  WSScanDevice? get connectingDevice => _connectingDevice;

  WsDemoLastDevice? _lastDevice;

  /// Last device that connected successfully in this Demo install.
  WsDemoLastDevice? get lastDevice => _lastDevice;

  /// Init-time transport profile of the current [WSWatch] instance.
  WSTransportMode get transportMode => _watch.transportMode;

  /// Realtek firmware has no login handler yet; Demo uses bind-first on BLE.
  bool get preferBindOverLogin => transportMode == WSTransportMode.ble;

  void _attachWatchStreams(WSWatch watch) {
    _subscriptions.add(watch.attachedSessions.listen((entries) {
      if (_disposed) return;
      final live = watch.attachedSessionsSnapshot.map((e) => e.session).toSet();
      for (final session in _syncs.keys.toList()) {
        if (!live.contains(session)) _syncs.remove(session)?.dispose();
      }
      _functionInfos.removeWhere((s, _) => !live.contains(s));
      _batteryPercents.removeWhere((s, _) => !live.contains(s));
      _deviceErrors.removeWhere((s, _) => !live.contains(s));
      _busy.removeWhere((s, _) => !live.contains(s));
      for (final entry in entries) {
        _recordState(entry.deviceId, entry.state);
      }
      _refreshBusy();
      _notifyUi();
    }));
    _subscriptions.add(watch.scanResults.listen((devices) {
      _devices = devices;
      _scheduleScanUiUpdate();
    }));
    _subscriptions.add(watch.scanErrors.listen((error) {
      assert(() {
        debugPrint('WSWatch scan error: $error');
        return true;
      }());
      scanActive.value = watch.isScanning;
    }));
  }

  /// Recreates [WSWatch] for [mode]. Does not [initialize] unless SDK was already initialized.
  Future<void> setTransportMode(WSTransportMode mode) async {
    if (_disposed) return;
    final nextConfig = WSConfig.forTransportMode(mode);
    if (nextConfig.transportMode == _config.transportMode) return;
    if (attachedSessions.any((e) =>
            e.state.isConnected ||
            e.state.phase == WSSessionPhase.connecting) ||
        _connecting) {
      throw StateError('请先断开当前设备，再切换传输方式。');
    }
    final wasInitialized = _watch.isInitialized;
    _selectedDeviceId = null;
    _logs.clear();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _watch.dispose();
    _config = nextConfig;
    _watch = WSWatch(config: nextConfig);
    _attachWatchStreams(_watch);
    if (wasInitialized) {
      await initialize();
      await loadLastDevice();
    }
    _notifyUi();
  }

  Future<void> loadLastDevice() async {
    final stored = await WsDemoLastDeviceStore.read();
    if (stored == null) {
      _lastDevice = null;
    } else if (_watch.transportMode == WSTransportMode.simulation &&
        !stored.isSimulated) {
      _lastDevice = null;
    } else if (_watch.transportMode == WSTransportMode.ble &&
        stored.isSimulated) {
      _lastDevice = null;
    } else {
      _lastDevice = stored;
    }
    _notifyUi();
  }

  /// Connects using [lastDevice] without opening the scan page.
  Future<bool> connectLastDevice() async {
    final last = _lastDevice;
    if (last == null) return false;
    if (_watch.usesBleScan) {
      await _ensurePermissions();
    }
    return connect(WSScanDevice(
      deviceMac: last.deviceMac,
      name: last.name,
      rssi: 0,
      isSimulated: last.isSimulated,
    ));
  }

  Future<void> _rememberConnectedDevice(WSScanDevice device) async {
    final snapshot = WsDemoLastDevice(
      name: device.name.trim().isEmpty ? 'WS 设备' : device.name.trim(),
      deviceMac: device.deviceMac,
      isSimulated: device.isSimulated,
    );
    _lastDevice = snapshot;
    try {
      await WsDemoLastDeviceStore.write(snapshot);
    } catch (error) {
      WsDemoLog.info("保存最近设备失败: $error");
    }
    _notifyUi();
  }

  /// Clears stale scan rows when opening the connection page.
  void resetConnectionScanUi() {
    clearScanResults();
  }

  void clearScanResults() {
    _devices = const [];
    scanDevices.value = const [];
  }

  void _scheduleScanUiUpdate() {
    if (_disposed || _scanUiUpdateScheduled) return;
    _scanUiUpdateScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scanUiUpdateScheduled = false;
      if (_disposed) return;
      scanDevices.value = List.unmodifiable(_devices);
      scanActive.value = _watch.isScanning;
    });
  }

  void _publishScanUiNow() {
    _scanUiUpdateScheduled = false;
    if (_disposed) return;
    scanDevices.value = List.unmodifiable(_devices);
    scanActive.value = _watch.isScanning;
  }

  void _notifyUi() {
    if (_disposed || _uiNotifyScheduled) return;
    _uiNotifyScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _uiNotifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> startScan() async {
    try {
      if (!isInitialized) {
        throw StateError('WS SDK must be initialized before scanning.');
      }
      if (_watch.usesBleScan) {
        await _ensurePermissions();
      }
      await _watch.stopScan();
      clearScanResults();
      scanActive.value = _watch.usesBleScan;
      await _watch.startScan();
      _publishScanUiNow();
      scanActive.value = _watch.isScanning;
    } catch (error) {
      scanActive.value = _watch.isScanning;
      rethrow;
    }
  }

  Future<void> initialize() async {
    _notifyUi();
    try {
      await _watch.initialize();
    } finally {
      _notifyUi();
    }
  }

  Future<void> stopScan() async {
    try {
      await _watch.stopScan();
    } finally {
      scanActive.value = false;
      _publishScanUiNow();
    }
  }

  Future<bool> connect(WSScanDevice device) async {
    if (_connecting) return false;
    if (!isInitialized) throw StateError('Initialize WS SDK first');
    _connecting = true;
    _connectingDevice = device;
    _notifyUi();
    try {
      await stopScan();
      final target = await _watch.openSession(device.deviceMac);
      selectDevice(device.deviceMac);
      await target.connect();
      if (target.state.isConnected) {
        unawaited(_rememberConnectedDevice(device));
      }
      return target.state.isConnected;
    } finally {
      _connecting = false;
      _connectingDevice = null;
      _notifyUi();
    }
  }

  Future<void> login(String userId) => _runSession((session) async {
        await session.login(userId);
      });

  Future<void> bindFirstTime(String userId, {required bool confirmed}) =>
      _runSession((session) async {
        await session.bindFirstTime(userId, confirmed: confirmed);
      });

  Future<void> unbind({required bool confirmed}) =>
      _runSession((session) => session.unbind(confirmed: confirmed));

  final _functionInfos = <WSWatchSession, WSDeviceFunctionInfo?>{};
  WSDeviceFunctionInfo? get functionInfo => _functionInfos[_session];
  final _batteryPercents = <WSWatchSession, int?>{};
  int? get batteryPercent => _batteryPercents[_session];

  bool get isHealthSyncActive => _session?.isHealthSyncActive ?? false;

  Future<void> syncHealthData(WSHistorySyncListener listener) =>
      _runSession((s) => s.syncHealthData(listener));

  Future<WSTodayActivitySummary?> fetchTodayActivitySummary() =>
      _runSessionValue((s) async =>
          wsDemoTodaySummaryFromSnapshot(await s.today.queryToday()));

  Future<void> readDeviceInfo() =>
      _runSession((session) => session.readDeviceInfo());

  Future<int?> readBattery() => _runSessionValue((s) async {
        final value = await s.control.queryBatteryPercent();
        _batteryPercents[s] = value;
        _notifyUi();
        return value;
      });

  Future<void> readDeviceDetails() => readDeviceInfo();

  Future<void> readDeviceFeatures() => _runSession((session) async {
        await session.readDeviceFeatures();
        final raw = session.state.capabilities?.raw;
        if (raw != null && raw.length >= 8) {
          _functionInfos[session] = WSDeviceFunctionInfo.fromWire(
            Uint8List.sublistView(raw, 0, 8),
          );
        } else {
          _functionInfos[session] = null;
        }
      });

  Future<WSLanguage> readLanguage() => _runSessionValue((s) async {
        final code = await s.settings.readLanguage();
        return WSLanguage.fromCode(code);
      });

  Future<WSHourSystem> readHourSystem() async => WSHourSystem.h24;

  Future<WSUnitSystem> readUnitSystem() async => WSUnitSystem.metric;

  Future<WSVerifiedSetting<WSLanguage>> setLanguage(WSLanguage value) async {
    final previous = await readLanguage();
    return WSVerifiedSetting(previous: previous, value: value);
  }

  Future<WSVerifiedSetting<WSHourSystem>> setHourSystem(
          WSHourSystem value) async =>
      WSVerifiedSetting(previous: WSHourSystem.h24, value: value);

  Future<WSVerifiedSetting<WSUnitSystem>> setUnitSystem(
          WSUnitSystem value) async =>
      WSVerifiedSetting(previous: WSUnitSystem.metric, value: value);

  Future<WSHeatStressReminder> readHeatStressReminder() =>
      _runSessionValue((s) async {
        final schedule = await s.measure.readHeatStressAutoMeasure();
        return WSHeatStressReminder(
          enabled: schedule.enabled,
          schedule: WSTimeRange(
            startHour: schedule.startHour,
            startMinute: schedule.startMinute,
            endHour: schedule.endHour,
            endMinute: schedule.endMinute,
          ),
        );
      });

  Future<WSVerifiedSetting<WSHeatStressReminder>> setHeatStressReminder(
          WSHeatStressReminder value) async =>
      _runSessionValue((s) async {
        final schedule = await s.measure.readHeatStressAutoMeasure();
        final previous = WSHeatStressReminder(
            enabled: schedule.enabled,
            schedule: WSTimeRange(
                startHour: schedule.startHour,
                startMinute: schedule.startMinute,
                endHour: schedule.endHour,
                endMinute: schedule.endMinute));
        await s.measure.setHeatStressAutoMeasure(
          WSAutoMeasureSchedule(
            enabled: value.enabled,
            startHour: value.schedule.startHour,
            startMinute: value.schedule.startMinute,
            endHour: value.schedule.endHour,
            endMinute: value.schedule.endMinute,
            intervalMinutes: 30,
          ),
        );
        return WSVerifiedSetting(previous: previous, value: value);
      });

  Future<WSHighHeartRateReminder> readHighHeartRateReminder() =>
      _runSessionValue((s) async {
        final alarm = await s.settings.readHeartRateHighAlarm();
        return WSHighHeartRateReminder(
          enabled: alarm.enabled,
          thresholdBpm: alarm.thresholdBpm,
        );
      });

  Future<WSVerifiedSetting<WSHighHeartRateReminder>> setHighHeartRateReminder(
          WSHighHeartRateReminder value) async =>
      _runSessionValue((s) async {
        final alarm = await s.settings.readHeartRateHighAlarm();
        final previous = WSHighHeartRateReminder(
            enabled: alarm.enabled, thresholdBpm: alarm.thresholdBpm);
        await s.settings.setHeartRateHighAlarm(
          WSHeartRateHighAlarm(
            enabled: value.enabled,
            thresholdBpm: value.thresholdBpm,
          ),
        );
        return WSVerifiedSetting(previous: previous, value: value);
      });

  Future<bool> readLowSpO2Reminder() => _runSessionValue((s) async {
        final alarm = await s.settings.readSpO2LowAlarm();
        return alarm.enabled;
      });

  Future<WSSettingSubmission> setLowSpO2Reminder(bool enabled) async =>
      _runSession((s) async {
        final previous = await s.settings.readSpO2LowAlarm();
        await s.settings.setSpO2LowAlarm(
          WSSpO2LowAlarm(
            enabled: enabled,
            thresholdPercent:
                previous.thresholdPercent == 0 ? 90 : previous.thresholdPercent,
          ),
        );
      }).then((_) => const WSSettingSubmission('lowSpO2'));

  Future<WSSettingSubmission> syncTime() => _runSessionValue((s) async {
        await s.settings
            .setTimeUnix(DateTime.now().millisecondsSinceEpoch ~/ 1000);
        return const WSSettingSubmission('time');
      });

  Future<WSSettingSubmission> findDevice(bool enabled) async =>
      WSSettingSubmission('findDevice');

  Future<WSSettingSubmission> setAddressBook(
          List<WSAddressBookEntry> entries) async =>
      WSSettingSubmission('addressBook');

  Future<WSNotifySettings> readNotifySettings() async => _kDemoNotifySettings;

  Future<WSVerifiedSetting<WSNotifySettings>> setNotifySettings(
          WSNotifySettings value) async =>
      WSVerifiedSetting(previous: _kDemoNotifySettings, value: value);

  Future<WSVerifiedSetting<WSNotifySettings>> setNotifyChannel(
          WSNotifyChannel channel, bool enabled) async =>
      WSVerifiedSetting(
        previous: _kDemoNotifySettings,
        value: _kDemoNotifySettings.withChannel(channel, enabled),
      );

  Future<WSSettingSubmission> sendNotifyMessage(
    WSNotifyChannel channel, {
    String text = '',
  }) async =>
      WSSettingSubmission('notify');

  Future<WSSettingSubmission> sendIncomingCall({String display = ''}) async =>
      WSSettingSubmission('incomingCall');

  Future<Uint8List> resetHistorySyncMarkers() async {
    throw UnimplementedError('WS SDK: resetHistorySyncMarkers pending');
  }

  Future<void> clearDeviceData({required bool confirmed}) async {
    throw UnimplementedError('WS SDK: clearDeviceData pending');
  }

  Future<WSAutoMeasureConfig> readHeartRateAutoMeasure() =>
      _runSessionValue((s) => s.measure.readHeartRateAutoMeasure());

  Future<List<int>> readHeartRateIntervalOptions() =>
      _runSessionValue((s) => s.measure.readHeartRateIntervalOptions());

  Future<void> setHeartRateAutoMeasure(WSAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setHeartRateAutoMeasure(config));

  Future<WSAutoMeasureConfig> readSpO2AutoMeasure() =>
      _runSessionValue((s) => s.measure.readSpO2AutoMeasure());

  Future<void> setSpO2AutoMeasure(WSAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setSpO2AutoMeasure(config));

  Future<WSAutoMeasureConfig> readBloodPressureAutoMeasure() =>
      _runSessionValue((s) => s.measure.readBloodPressureAutoMeasure());

  Future<void> setBloodPressureAutoMeasure(WSAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setBloodPressureAutoMeasure(config));

  Future<WSBloodSugarAutoMeasureConfig> readBloodSugarAutoMeasure() =>
      _runSessionValue((s) => s.measure.readBloodSugarAutoMeasure());

  Future<void> setBloodSugarAutoMeasure(WSBloodSugarAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setBloodSugarAutoMeasure(config));

  Future<WSTemperatureControlSetting> readTemperatureControl() =>
      _runSessionValue((s) => s.measure.readTemperatureControl());

  Future<void> setTemperatureControl(WSTemperatureControlSetting setting) =>
      _runSession((s) => s.measure.setTemperatureControl(setting));

  Future<void> setPressureAutoMeasure(bool enabled) =>
      _runSession((s) => s.measure.setPressureAutoMeasure(enabled));

  Future<void> startHeartRateMeasure() => _runSession(
        (s) => s.measure.startHeartRateSpot(),
        notifyUi: false,
      );

  Future<void> stopHeartRateMeasure() => _runSession(
        (s) => s.measure.stopHeartRateSpot(),
        notifyUi: false,
      );

  Future<void> startBloodPressureSpotMeasure() => _runSession(
        (s) => s.measure.startBloodPressureSpotMeasure(),
        notifyUi: false,
      );

  Future<void> stopBloodPressureSpotMeasure() => _runSession(
        (s) => s.measure.stopBloodPressureSpotMeasure(),
        notifyUi: false,
      );

  Future<void> startSpO2SpotMeasure() => _runSession(
        (s) => s.measure.startSpO2SpotMeasure(),
        notifyUi: false,
      );

  Future<void> stopSpO2SpotMeasure() => _runSession(
        (s) => s.measure.stopSpO2SpotMeasure(),
        notifyUi: false,
      );

  Future<void> checkSpO2SpotMeasure() => _runSession(
        (s) => s.measure.checkSpO2SpotMeasure(),
        notifyUi: false,
      );

  Future<void> startTemperatureSpotMeasure() => _runSession(
        (s) => s.measure.startTemperatureSpotMeasure(),
        notifyUi: false,
      );

  Future<void> stopTemperatureSpotMeasure() => _runSession(
        (s) => s.measure.stopTemperatureSpotMeasure(),
        notifyUi: false,
      );

  Future<void> checkTemperatureSpotMeasure() => _runSession(
        (s) => s.measure.checkTemperatureSpotMeasure(),
        notifyUi: false,
      );

  Future<void> startBloodGlucoseSpotMeasure() => _runSession(
        (s) => s.measure.startBloodGlucoseSpotMeasure(),
        notifyUi: false,
      );

  Future<void> stopBloodGlucoseSpotMeasure() => _runSession(
        (s) => s.measure.stopBloodGlucoseSpotMeasure(),
        notifyUi: false,
      );

  Future<WSSettingSubmission> setUserProfile(WSUserProfile profile) async =>
      WSSettingSubmission('userProfile');

  Future<WSSettingSubmission> setGoals(WSGoals goals) async =>
      WSSettingSubmission('goals');

  Future<WSDateFormat> readDateFormat() async => WSDateFormat.monthDay;

  Future<WSSettingSubmission> setDateFormat(WSDateFormat value) async =>
      WSSettingSubmission('dateFormat');

  Future<int> readScreenLightDuration() async => 5;

  Future<WSSettingSubmission> setScreenLightDuration(int value) async =>
      WSSettingSubmission('screenLightDuration');

  Future<int> readScreenBrightness() async => 50;

  Future<WSSettingSubmission> setScreenBrightness(int value) async =>
      WSSettingSubmission('screenBrightness');

  Future<int> readHomePage() async => 0;

  Future<WSSettingSubmission> setHomePage(int value) async =>
      WSSettingSubmission('homePage');

  Future<bool> readTurnWristToWake() async => true;

  Future<WSSettingSubmission> setTurnWristToWake(bool value) async =>
      WSSettingSubmission('turnWristToWake');

  Future<WSDoNotDisturb> readDoNotDisturb() async =>
      const WSDoNotDisturb(enabled: false, schedule: _kDemoDayRange);

  Future<WSVerifiedSetting<WSDoNotDisturb>> setDoNotDisturb(
          WSDoNotDisturb value) async =>
      WSVerifiedSetting(
        previous:
            const WSDoNotDisturb(enabled: false, schedule: _kDemoDayRange),
        value: value,
      );

  Future<WSSedentaryReminder> readSedentaryReminder() async =>
      const WSSedentaryReminder(
        enabled: false,
        thresholdMinutes: 60,
        notifyHour: 12,
        startHour: 9,
        endHour: 18,
        repeatDays: 0x7f,
      );

  Future<WSVerifiedSetting<WSSedentaryReminder>> setSedentaryReminder(
          WSSedentaryReminder value) async =>
      WSVerifiedSetting(
        previous: const WSSedentaryReminder(
          enabled: false,
          thresholdMinutes: 60,
          notifyHour: 12,
          startHour: 9,
          endHour: 18,
          repeatDays: 0x7f,
        ),
        value: value,
      );

  Future<List<WSAlarm>> readAlarms() async => const [];

  Future<WSSettingSubmission> setAlarms(
    List<WSAlarm> values, {
    Set<int>? previousAlarmIds,
  }) async =>
      WSSettingSubmission('alarms');

  Future<void> disconnect() async {
    final id = _selectedDeviceId;
    if (id != null) await disconnectDevice(id);
  }

  Future<void> disconnectDevice(String id) async {
    await _watch.closeSession(id);
    if (_selectedDeviceId == id) {
      _selectedDeviceId = attachedSessions
          .where((e) => !e.isClosing && !e.session.isDisposed)
          .firstOrNull
          ?.deviceId;
    }
    _refreshBusy();
    _notifyUi();
  }

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) return;
    if (!(await Permission.locationWhenInUse.request()).isGranted) {
      throw StateError('请授予蓝牙/定位权限以扫描 WS 设备');
    }
  }

  /// Whether scan can start without showing a permission dialog (Android).
  Future<bool> scanPermissionsGranted() async {
    if (!_watch.usesBleScan || !Platform.isAndroid) return true;
    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      return true;
    }
    return Permission.locationWhenInUse.isGranted;
  }

  /// Called when the connection page opens: scan only if permissions are already granted.
  Future<void> autoStartScanOnConnectionPage() async {
    if (_disposed || !isInitialized || _connecting || isScanning) {
      return;
    }
    if (!await scanPermissionsGranted()) return;
    await startScan();
  }

  void rememberUserId(String value) => _userId = value.trim();

  void _sessionWorkStarted(WSWatchSession session) {
    _busy[session] = (_busy[session] ?? 0) + 1;
    _refreshBusy();
  }

  void _sessionWorkEnded(WSWatchSession session) {
    final count = (_busy[session] ?? 1) - 1;
    if (count <= 0) {
      _busy.remove(session);
    } else {
      _busy[session] = count;
    }
    _refreshBusy();
  }

  /// Mirrors [WSWatchSession] state and tracks [sessionBusy]; failures **rethrow**.
  Future<void> _runSession(
    Future<void> Function(WSWatchSession session) operation, {
    bool notifyUi = true,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('请先连接 WS 设备');
    }
    _deviceErrors.remove(session);
    _sessionWorkStarted(session);
    try {
      await operation(session);
      if (notifyUi) _notifyUi();
    } catch (error) {
      if (!_disposed &&
          identical(
              _watch.sessionOf(session.connection.target.deviceId), session))
        _deviceErrors[session] = error;
      if (notifyUi) _notifyUi();
      rethrow;
    } finally {
      _sessionWorkEnded(session);
    }
  }

  /// Same as [_runSession] but returns a value; failures **rethrow**.
  Future<T> _runSessionValue<T>(
    Future<T> Function(WSWatchSession session) operation, {
    bool notifyUi = true,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('WS device must be connected first');
    }
    _deviceErrors.remove(session);
    _sessionWorkStarted(session);
    try {
      final result = await operation(session);
      if (notifyUi) _notifyUi();
      return result;
    } catch (error) {
      if (!_disposed &&
          identical(
              _watch.sessionOf(session.connection.target.deviceId), session))
        _deviceErrors[session] = error;
      if (notifyUi) _notifyUi();
      rethrow;
    } finally {
      _sessionWorkEnded(session);
    }
  }

  void _recordState(String deviceId, WSSessionState state) {
    final log = _logs.putIfAbsent(deviceId, () => []);
    final message = switch (state.phase) {
      WSSessionPhase.connecting => '正在连接设备',
      WSSessionPhase.connected => '设备已连接',
      WSSessionPhase.loggingIn => '正在登录',
      WSSessionPhase.ready => '登录完成',
      WSSessionPhase.loginRejected => '登录被拒绝，需要首次绑定',
      WSSessionPhase.disconnected => '设备已断开',
      WSSessionPhase.failed => '会话失败：${state.error}',
      _ => null,
    };
    if (message == null || (log.isNotEmpty && log.last == message)) {
      return;
    }
    log.add(message);
    if (log.length > 12) log.removeAt(0);
  }

  Future<void> shutdown() => _watch.dispose();

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_watch.dispose().catchError((Object error) {
      WsDemoLog.info("WS cleanup failed: $error");
    }));
    for (final sync in _syncs.values) {
      sync.dispose();
    }
    scanDevices.dispose();
    scanActive.dispose();
    sessionBusy.dispose();
    super.dispose();
  }
}
