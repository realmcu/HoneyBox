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

/// HoneyBox-side composition of public JW SDK objects.
///
/// This controller never writes GATT bytes or imports transport packages; it
/// only coordinates the public scanner, session, and login APIs.
///
/// Scan result updates use [scanDevices] so high-frequency BLE advertisements
/// coalesce to at most one UI refresh per frame.
class WSDemoController extends ChangeNotifier {
  WSDemoController({WSWatch? watch})
      : _watch = watch ??
            WSWatch(
              config: const WSConfig(
                simulationEnabled: true,
                simulationExclusive: true,
              ),
            ) {
    _subscriptions.add(_watch.scanResults.listen((devices) {
      _devices = devices;
      _scheduleScanUiUpdate();
    }));
    _subscriptions.add(_watch.scanErrors.listen((error) {
      sheetError.value = error;
      scanActive.value = _watch.isScanning;
    }));
  }

  final WSWatch _watch;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final ValueNotifier<List<WSScanDevice>> scanDevices = ValueNotifier(const []);
  final ValueNotifier<bool> scanActive = ValueNotifier(false);
  final ValueNotifier<Object?> sheetError = ValueNotifier(null);
  bool _scanUiUpdateScheduled = false;
  bool _uiNotifyScheduled = false;

  List<WSScanDevice> _devices = const [];
  WSWatchSession? _session;
  String _userId = '123456';
  WSSessionState _state = const WSSessionState();
  Object? _error;
  bool _disposed = false;
  final _sessionLog = <String>[];

  List<WSScanDevice> get devices => scanDevices.value;
  WSWatchSession? get session => _session;
  WSSessionState get state => _state;
  Object? get error => _error ?? sheetError.value;
  bool get isScanning => scanActive.value;
  bool get isInitialized => _watch.isInitialized;
  bool get isConnecting => _connecting;
  List<String> get sessionLog => List.unmodifiable(_sessionLog);
  String get userId => _userId;
  bool _connecting = false;
  WSScanDevice? _connectingDevice;

  Listenable get scanListenable =>
      Listenable.merge([scanDevices, scanActive, sheetError]);

  WSScanDevice? get connectingDevice => _connectingDevice;

  WsDemoLastDevice? _lastDevice;

  /// Last device that connected successfully in this Demo install.
  WsDemoLastDevice? get lastDevice => _lastDevice;

  Future<void> loadLastDevice() async {
    final stored = await WsDemoLastDeviceStore.read();
    if (stored != null &&
        _watch.isSimulationExclusive &&
        stored.deviceMac != kWsWatchSimDeviceId) {
      // 与 JW 共用过 jw_demo_last_device.json 时的残留真机 MAC，清掉以免「上次设备」走 BLE。
      await WsDemoLastDeviceStore.clear();
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
    if (_watch.isSimulationExclusive &&
        last.deviceMac != kWsWatchSimDeviceId) {
      return connect(const WSScanDevice(
        deviceMac: kWsWatchSimDeviceId,
        name: 'WS Watch Simulator',
        rssi: 0,
        isSimulated: true,
      ));
    }
    await _ensurePermissions();
    return connect(WSScanDevice(
      deviceMac: last.deviceMac,
      name: last.name,
      rssi: 0,
      isSimulated: last.deviceMac == kWsWatchSimDeviceId,
    ));
  }

  Future<void> _rememberConnectedDevice(WSScanDevice device) async {
    final snapshot = WsDemoLastDevice(
      name: device.name.trim().isEmpty ? 'JW 设备' : device.name.trim(),
      deviceMac: device.deviceMac,
    );
    _lastDevice = snapshot;
    await WsDemoLastDeviceStore.write(snapshot);
    _notifyUi();
  }

  /// Clears stale scan rows when opening the connection page.
  void resetConnectionScanUi() {
    clearScanResults();
    _error = null;
    sheetError.value = null;
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
    sheetError.value = null;
    try {
      if (!isInitialized) {
        throw StateError('JW SDK must be initialized before scanning.');
      }
      if (!_watch.isSimulationExclusive) {
        await _ensurePermissions();
      }
      await _watch.stopScan();
      clearScanResults();
      scanActive.value = !_watch.isSimulationExclusive;
      await _watch.startScan();
      _publishScanUiNow();
      scanActive.value = _watch.isScanning;
    } catch (error) {
      scanActive.value = _watch.isScanning;
      sheetError.value = error;
    }
  }

  Future<void> initialize() async {
    _error = null;
    sheetError.value = null;
    _notifyUi();
    try {
      await _watch.initialize();
    } catch (error) {
      _error = error;
      sheetError.value = error;
    }
    _notifyUi();
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
    if (_state.isConnected) return true;
    if (_watch.isSimulationExclusive &&
        device.deviceMac != kWsWatchSimDeviceId) {
      final error = StateError(
        '当前 WS Demo 为模拟器模式，请连接列表中的「WS Watch Simulator」。',
      );
      _error = error;
      sheetError.value = error;
      _notifyUi();
      return false;
    }
    if (!isInitialized) {
      final error = StateError('WS SDK must be initialized before connecting.');
      _error = error;
      sheetError.value = error;
      _notifyUi();
      return false;
    }
    _connecting = true;
    _connectingDevice = device;
    clearScanResults();
    _notifyUi();
    await stopScan();
    await _session?.dispose();
    _sessionLog.clear();
    _session = _watch.createSession(device.deviceMac);
    _subscriptions.add(_session!.states.listen((state) {
      _state = state;
      _recordState(state);
      _notifyUi();
    }));
    _error = null;
    sheetError.value = null;
    _notifyUi();
    try {
      await _session!.connect();
      if (_state.isConnected) {
        unawaited(_rememberConnectedDevice(device));
      }
      return _state.isConnected;
    } catch (error) {
      _error = error;
      sheetError.value = error;
      _notifyUi();
      return false;
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

  WSDeviceFunctionInfo? _functionInfo;
  WSDeviceFunctionInfo? get functionInfo => _functionInfo;
  int? _batteryPercent;
  int? get batteryPercent => _batteryPercent;

  bool get isHealthSyncActive => _session?.isHealthSyncActive ?? false;

  Future<void> syncHealthData(WSHistorySyncListener listener) =>
      _runSession((s) => s.syncHealthData(listener));

  Future<WSTodayActivitySummary?> fetchTodayActivitySummary() =>
      _runSessionValue((s) async => wsDemoTodaySummaryFromSnapshot(await s.today.queryToday()));

  Future<void> readDeviceInfo() => _runSession((_) async {
        _state = _session!.state;
      });

  Future<int?> readBattery() => _runSessionValue((s) async {
        final value = await s.control.queryBatteryPercent();
        _batteryPercent = value;
        _notifyUi();
        return value;
      });

  Future<void> readDeviceDetails() => readDeviceInfo();

  Future<void> readDeviceFeatures() => _runSession((_) async {
        _functionInfo = WSDeviceFunctionInfo.demoAllSupported();
        _notifyUi();
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

  Future<WSVerifiedSetting<WSHourSystem>> setHourSystem(WSHourSystem value) async =>
      WSVerifiedSetting(previous: WSHourSystem.h24, value: value);

  Future<WSVerifiedSetting<WSUnitSystem>> setUnitSystem(WSUnitSystem value) async =>
      WSVerifiedSetting(previous: WSUnitSystem.metric, value: value);

  Future<WSHeatStressReminder> readHeatStressReminder() async =>
      const WSHeatStressReminder(enabled: false, schedule: _kDemoDayRange);

  Future<WSVerifiedSetting<WSHeatStressReminder>> setHeatStressReminder(
          WSHeatStressReminder value) async =>
      WSVerifiedSetting(
        previous: const WSHeatStressReminder(enabled: false, schedule: _kDemoDayRange),
        value: value,
      );

  Future<WSHighHeartRateReminder> readHighHeartRateReminder() async =>
      const WSHighHeartRateReminder(enabled: false, thresholdBpm: 160);

  Future<WSVerifiedSetting<WSHighHeartRateReminder>> setHighHeartRateReminder(
          WSHighHeartRateReminder value) async =>
      WSVerifiedSetting(
        previous: const WSHighHeartRateReminder(enabled: false, thresholdBpm: 160),
        value: value,
      );

  Future<bool> readLowSpO2Reminder() async => false;

  Future<WSSettingSubmission> setLowSpO2Reminder(bool enabled) async =>
      WSSettingSubmission('lowSpO2');

  Future<WSSettingSubmission> syncTime() => _runSessionValue((s) async {
        await s.settings.setTimeUnix(DateTime.now().millisecondsSinceEpoch ~/ 1000);
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

  Future<WSAutoMeasureConfig> readHeartRateAutoMeasure() async =>
      const WSAutoMeasureConfig(enabled: false, intervalMinutes: 0);

  Future<List<int>> readHeartRateIntervalOptions() async => const [10, 20, 30];

  Future<void> setHeartRateAutoMeasure(WSAutoMeasureConfig config) async {}

  Future<WSAutoMeasureConfig> readSpO2AutoMeasure() async =>
      const WSAutoMeasureConfig(enabled: false, intervalMinutes: 0);

  Future<void> setSpO2AutoMeasure(WSAutoMeasureConfig config) async {}

  Future<WSAutoMeasureConfig> readBloodPressureAutoMeasure() async =>
      const WSAutoMeasureConfig(enabled: false, intervalMinutes: 0);

  Future<void> setBloodPressureAutoMeasure(WSAutoMeasureConfig config) async {}

  Future<WSBloodSugarAutoMeasureConfig> readBloodSugarAutoMeasure() async =>
      const WSBloodSugarAutoMeasureConfig(enabled: false, intervalMinutes: 0);

  Future<void> setBloodSugarAutoMeasure(WSBloodSugarAutoMeasureConfig config) async {}

  Future<WSTemperatureControlSetting> readTemperatureControl() async =>
      const WSTemperatureControlSetting(enabled: false, adjust: false, celsius: true);

  Future<void> setTemperatureControl(WSTemperatureControlSetting setting) async {}

  Future<void> setPressureAutoMeasure(bool enabled) async {}

  Future<void> startHeartRateMeasure() =>
      _runSession((s) => s.measure.startHeartRateSpot());

  Future<void> stopHeartRateMeasure() =>
      _runSession((s) => s.measure.stopHeartRateSpot());

  Future<void> startBloodPressureSpotMeasure() async =>
      throw UnimplementedError('WS spot BP pending');

  Future<void> stopBloodPressureSpotMeasure() async {}

  Future<void> startSpO2SpotMeasure() async =>
      throw UnimplementedError('WS spot SpO2 pending');

  Future<void> stopSpO2SpotMeasure() async {}

  Future<void> checkSpO2SpotMeasure() async {}

  Future<void> startTemperatureSpotMeasure() async =>
      throw UnimplementedError('WS spot temperature pending');

  Future<void> stopTemperatureSpotMeasure() async {}

  Future<void> checkTemperatureSpotMeasure() async {}

  Future<void> startBloodGlucoseSpotMeasure() async =>
      throw UnimplementedError('WS spot glucose pending');

  Future<void> stopBloodGlucoseSpotMeasure() async {}

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

  Future<WSVerifiedSetting<WSDoNotDisturb>> setDoNotDisturb(WSDoNotDisturb value) async =>
      WSVerifiedSetting(
        previous: const WSDoNotDisturb(enabled: false, schedule: _kDemoDayRange),
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
    final session = _session;
    _session = null;
    _state = const WSSessionState(phase: WSSessionPhase.disconnected);
    await session?.dispose();
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
    if (!Platform.isAndroid) return true;
    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      return true;
    }
    return Permission.locationWhenInUse.isGranted;
  }

  /// Called when the connection page opens: scan only if permissions are already granted.
  Future<void> autoStartScanOnConnectionPage() async {
    if (_disposed ||
        !isInitialized ||
        _state.isConnected ||
        _connecting ||
        isScanning) {
      return;
    }
    if (!await scanPermissionsGranted()) return;
    await startScan();
  }

  void rememberUserId(String value) => _userId = value.trim();

  Future<void> _runSession(
      Future<void> Function(WSWatchSession session) operation) async {
    final session = _session;
    if (session == null) {
      _error = StateError('请先连接 WS 设备');
      sheetError.value = _error;
      _notifyUi();
      return;
    }
    _error = null;
    sheetError.value = null;
    _notifyUi();
    try {
      await operation(session);
      _state = session.state;
      _notifyUi();
    } catch (error) {
      _error = error;
      sheetError.value = error;
      _notifyUi();
    }
  }

  Future<T> _runSessionValue<T>(
      Future<T> Function(WSWatchSession session) operation) async {
    final session = _session;
    if (session == null) {
      final error = StateError('WS device must be connected first');
      _error = error;
      sheetError.value = error;
      _notifyUi();
      throw error;
    }
    _error = null;
    sheetError.value = null;
    _notifyUi();
    try {
      return await operation(session);
    } catch (error) {
      _error = error;
      sheetError.value = error;
      _notifyUi();
      rethrow;
    }
  }

  void _recordState(WSSessionState state) {
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
    if (message == null ||
        (_sessionLog.isNotEmpty && _sessionLog.last == message)) {
      return;
    }
    _sessionLog.add(message);
    if (_sessionLog.length > 12) _sessionLog.removeAt(0);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_session?.dispose());
    unawaited(_watch.dispose());
    scanDevices.dispose();
    scanActive.dispose();
    sheetError.dispose();
    super.dispose();
  }
}
