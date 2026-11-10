import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

import 'jw_demo_last_device_store.dart';

/// Turns public SDK errors into short, actionable UI copy.
///
/// The SDK deliberately keeps [JWException.msg] in English for
/// developers. The Demo owns localized end-user wording and must make it
/// clear that command failures do not imply that the BLE session disconnected.
String describeJWDemoError(Object error) {
  if (error is JWException) {
    return switch (error.code) {
      JWErrorCode.businessReplyTimeout =>
        '设备在 5 秒内未回应此设置查询；该功能可能不支持或设备暂时忙，当前连接仍保持。',
      JWErrorCode.ackTimeout => '设备未确认本次发送；当前连接仍保持，可稍后重试。',
      JWErrorCode.nack => '设备拒绝了本次命令；当前连接仍保持。',
      JWErrorCode.writeTimeout ||
      JWErrorCode.writeFailed =>
        '本次蓝牙写入失败；当前连接仍保持，可重试。',
      JWErrorCode.transportDisconnected => '设备连接已断开。',
      JWErrorCode.historySyncIdleTimeout =>
        '同步超过 ${kJWHistorySyncIdleTimeout.inSeconds} 秒无进展；本轮已结束，连接可能仍保持。',
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
class JWDemoController extends ChangeNotifier {
  JWDemoController({JWWatch? watch}) : _watch = watch ?? JWWatch() {
    _subscriptions.add(_watch.scanResults.listen((devices) {
      _devices = devices;
      _scheduleScanUiUpdate();
    }));
    _subscriptions.add(_watch.scanErrors.listen((error) {
      sheetError.value = error;
      scanActive.value = _watch.isScanning;
    }));
  }

  final JWWatch _watch;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final ValueNotifier<List<JWScanDevice>> scanDevices = ValueNotifier(const []);
  final ValueNotifier<bool> scanActive = ValueNotifier(false);
  final ValueNotifier<Object?> sheetError = ValueNotifier(null);
  bool _scanUiUpdateScheduled = false;
  bool _uiNotifyScheduled = false;

  List<JWScanDevice> _devices = const [];
  JWWatchSession? _session;
  String _userId = '123456';
  JWSessionState _state = const JWSessionState();
  Object? _error;
  bool _disposed = false;
  final _sessionLog = <String>[];

  List<JWScanDevice> get devices => scanDevices.value;
  JWWatchSession? get session => _session;
  JWSessionState get state => _state;
  Object? get error => _error ?? sheetError.value;
  bool get isScanning => scanActive.value;
  bool get isInitialized => _watch.isInitialized;
  bool get isConnecting => _connecting;
  List<String> get sessionLog => List.unmodifiable(_sessionLog);
  String get userId => _userId;
  bool _connecting = false;
  JWScanDevice? _connectingDevice;

  Listenable get scanListenable =>
      Listenable.merge([scanDevices, scanActive, sheetError]);

  JWScanDevice? get connectingDevice => _connectingDevice;

  JwDemoLastDevice? _lastDevice;

  /// Last device that connected successfully in this Demo install.
  JwDemoLastDevice? get lastDevice => _lastDevice;

  Future<void> loadLastDevice() async {
    _lastDevice = await JwDemoLastDeviceStore.read();
    _notifyUi();
  }

  /// Connects using [lastDevice] without opening the scan page.
  Future<bool> connectLastDevice() async {
    final last = _lastDevice;
    if (last == null) return false;
    await _ensurePermissions();
    return connect(JWScanDevice(
      deviceMac: last.deviceMac,
      name: last.name,
      rssi: 0,
    ));
  }

  Future<void> _rememberConnectedDevice(JWScanDevice device) async {
    final snapshot = JwDemoLastDevice(
      name: device.name.trim().isEmpty ? 'JW 设备' : device.name.trim(),
      deviceMac: device.deviceMac,
    );
    _lastDevice = snapshot;
    await JwDemoLastDeviceStore.write(snapshot);
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
      await _ensurePermissions();
      await _watch.stopScan();
      clearScanResults();
      scanActive.value = true;
      await _watch.startScan();
      _publishScanUiNow();
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

  Future<bool> connect(JWScanDevice device) async {
    if (_connecting) return false;
    if (_state.isConnected) return true;
    if (!isInitialized) {
      final error = StateError('JW SDK must be initialized before connecting.');
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

  Future<void> readDeviceInfo() =>
      _runSession((session) => session.readDeviceInfo());

  Future<int?> readBattery() =>
      _runSessionValue((session) => session.readBattery());

  Future<void> readDeviceDetails() =>
      _runSession((session) => session.readDeviceDetails());

  Future<void> readDeviceFeatures() =>
      _runSession((session) => session.readDeviceFeatures());

  Future<JWLanguage> readLanguage() =>
      _runSessionValue((session) => session.readLanguage());

  Future<JWHourSystem> readHourSystem() =>
      _runSessionValue((session) => session.readHourSystem());

  Future<JWUnitSystem> readUnitSystem() =>
      _runSessionValue((session) => session.readUnitSystem());

  Future<JWVerifiedSetting<JWLanguage>> setLanguage(JWLanguage value) =>
      _runSessionValue((session) => session.setLanguageVerified(value));

  Future<JWVerifiedSetting<JWHourSystem>> setHourSystem(JWHourSystem value) =>
      _runSessionValue((session) => session.setHourSystemVerified(value));

  Future<JWVerifiedSetting<JWUnitSystem>> setUnitSystem(JWUnitSystem value) =>
      _runSessionValue((session) => session.setUnitSystemVerified(value));

  Future<JWHeatStressReminder> readHeatStressReminder() =>
      _runSessionValue((session) => session.readHeatStressReminder());

  Future<JWVerifiedSetting<JWHeatStressReminder>> setHeatStressReminder(
          JWHeatStressReminder value) =>
      _runSessionValue(
          (session) => session.setHeatStressReminderVerified(value));

  Future<JWHighHeartRateReminder> readHighHeartRateReminder() =>
      _runSessionValue((session) => session.readHighHeartRateReminder());

  Future<JWVerifiedSetting<JWHighHeartRateReminder>> setHighHeartRateReminder(
          JWHighHeartRateReminder value) =>
      _runSessionValue(
          (session) => session.setHighHeartRateReminderVerified(value));

  Future<bool> readLowSpO2Reminder() =>
      _runSessionValue((session) => session.readLowSpO2Reminder());

  Future<JWSettingSubmission> setLowSpO2Reminder(bool enabled) =>
      _runSessionValue((session) => session.setLowSpO2Reminder(enabled));

  Future<JWSettingSubmission> syncTime() =>
      _runSessionValue((session) => session.setTime(DateTime.now()));

  Future<JWSettingSubmission> findDevice(bool enabled) =>
      _runSessionValue((session) => session.findDevice(enabled));

  Future<JWSettingSubmission> setAddressBook(
          List<JWAddressBookEntry> entries) =>
      _runSessionValue((session) => session.setAddressBook(entries));

  Future<JWNotifySettings> readNotifySettings() =>
      _runSessionValue((session) => session.readNotifySettings());

  Future<JWVerifiedSetting<JWNotifySettings>> setNotifySettings(
          JWNotifySettings value) =>
      _runSessionValue((session) => session.setNotifySettingsVerified(value));

  Future<JWVerifiedSetting<JWNotifySettings>> setNotifyChannel(
          JWNotifyChannel channel, bool enabled) =>
      _runSessionValue(
          (session) => session.setNotifyChannelVerified(channel, enabled));

  Future<JWSettingSubmission> sendNotifyMessage(
    JWNotifyChannel channel, {
    String text = '',
  }) =>
      _runSessionValue(
          (session) => session.sendNotifyMessage(channel, text: text));

  Future<JWSettingSubmission> sendIncomingCall({String display = ''}) =>
      _runSessionValue(
          (session) => session.sendIncomingCall(display: display));

  Future<Uint8List> resetHistorySyncMarkers() =>
      _runSessionValue((session) => session.resetHistorySyncMarkers());

  /// Sends factory RESET (`0x06/0xFC`), then tears down the local session.
  Future<void> clearDeviceData({required bool confirmed}) async {
    await _runSessionValue(
        (session) => session.clearDeviceData(confirmed: confirmed));
    await disconnect();
  }

  bool get isHealthSyncActive => _session?.isHealthSyncActive ?? false;

  Future<JWAutoMeasureConfig> readHeartRateAutoMeasure() =>
      _runSessionValue((s) => s.measure.readHeartRateAutoMeasure());

  Future<void> setHeartRateAutoMeasure(JWAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setHeartRateAutoMeasure(config));

  Future<JWAutoMeasureConfig> readSpO2AutoMeasure() =>
      _runSessionValue((s) => s.measure.readSpO2AutoMeasure());

  Future<void> setSpO2AutoMeasure(JWAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setSpO2AutoMeasure(config));

  Future<JWAutoMeasureConfig> readBloodPressureAutoMeasure() =>
      _runSessionValue((s) => s.measure.readBloodPressureAutoMeasure());

  Future<void> setBloodPressureAutoMeasure(JWAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setBloodPressureAutoMeasure(config));

  Future<JWBloodSugarAutoMeasureConfig> readBloodSugarAutoMeasure() =>
      _runSessionValue((s) => s.measure.readBloodSugarAutoMeasure());

  Future<void> setBloodSugarAutoMeasure(
          JWBloodSugarAutoMeasureConfig config) =>
      _runSession((s) => s.measure.setBloodSugarAutoMeasure(config));

  Future<JWTemperatureControlSetting> readTemperatureControl() =>
      _runSessionValue((s) => s.measure.readTemperatureControl());

  Future<void> setTemperatureControl(JWTemperatureControlSetting setting) =>
      _runSession((s) => s.measure.setTemperatureControl(setting));

  Future<void> setPressureAutoMeasure(bool enabled) =>
      _runSession((s) => s.measure.setPressureAutoMeasure(enabled));

  Future<void> startHeartRateMeasure() =>
      _runSession((s) => s.measure.startHeartRateMeasure());

  Future<void> stopHeartRateMeasure() =>
      _runSession((s) => s.measure.stopHeartRateMeasure());

  Future<void> startBloodPressureSpotMeasure() =>
      _runSession((s) => s.measure.startBloodPressureSpotMeasure());

  Future<void> stopBloodPressureSpotMeasure() =>
      _runSession((s) => s.measure.stopBloodPressureSpotMeasure());

  Future<void> startSpO2SpotMeasure() =>
      _runSession((s) => s.measure.startSpO2SpotMeasure());

  Future<void> stopSpO2SpotMeasure() =>
      _runSession((s) => s.measure.stopSpO2SpotMeasure());

  Future<void> checkSpO2SpotMeasure() =>
      _runSession((s) => s.measure.checkSpO2SpotMeasure());

  Future<void> startTemperatureSpotMeasure() =>
      _runSession((s) => s.measure.startTemperatureSpotMeasure());

  Future<void> stopTemperatureSpotMeasure() =>
      _runSession((s) => s.measure.stopTemperatureSpotMeasure());

  Future<void> checkTemperatureSpotMeasure() =>
      _runSession((s) => s.measure.checkTemperatureSpotMeasure());

  Future<void> startBloodGlucoseSpotMeasure() =>
      _runSession((s) => s.measure.startBloodGlucoseSpotMeasure());

  Future<void> stopBloodGlucoseSpotMeasure() =>
      _runSession((s) => s.measure.stopBloodGlucoseSpotMeasure());

  Future<JWSettingSubmission> setUserProfile(JWUserProfile profile) =>
      _runSessionValue((session) => session.setUserProfile(profile));

  Future<JWSettingSubmission> setGoals(JWGoals goals) =>
      _runSessionValue((session) => session.setGoals(goals));

  Future<JWDateFormat> readDateFormat() =>
      _runSessionValue((session) => session.readDateFormat());

  Future<JWSettingSubmission> setDateFormat(JWDateFormat value) =>
      _runSessionValue((session) => session.setDateFormat(value));

  Future<int> readScreenLightDuration() =>
      _runSessionValue((session) => session.readScreenLightDuration());

  Future<JWSettingSubmission> setScreenLightDuration(int value) =>
      _runSessionValue((session) => session.setScreenLightDuration(value));

  Future<int> readScreenBrightness() =>
      _runSessionValue((session) => session.readScreenBrightness());

  Future<JWSettingSubmission> setScreenBrightness(int value) =>
      _runSessionValue((session) => session.setScreenBrightness(value));

  Future<int> readHomePage() =>
      _runSessionValue((session) => session.readHomePage());

  Future<JWSettingSubmission> setHomePage(int value) =>
      _runSessionValue((session) => session.setHomePage(value));

  Future<bool> readTurnWristToWake() =>
      _runSessionValue((session) => session.readTurnWristToWake());

  Future<JWSettingSubmission> setTurnWristToWake(bool value) =>
      _runSessionValue((session) => session.setTurnWristToWake(value));

  Future<JWDoNotDisturb> readDoNotDisturb() =>
      _runSessionValue((session) => session.readDoNotDisturb());

  Future<JWVerifiedSetting<JWDoNotDisturb>> setDoNotDisturb(
          JWDoNotDisturb value) =>
      _runSessionValue((session) => session.setDoNotDisturbVerified(value));

  Future<JWSedentaryReminder> readSedentaryReminder() =>
      _runSessionValue((session) => session.readSedentaryReminder());

  Future<JWVerifiedSetting<JWSedentaryReminder>> setSedentaryReminder(
          JWSedentaryReminder value) =>
      _runSessionValue(
          (session) => session.setSedentaryReminderVerified(value));

  Future<List<JWAlarm>> readAlarms() =>
      _runSessionValue((session) => session.readAlarms());

  Future<JWSettingSubmission> setAlarms(
    List<JWAlarm> values, {
    Set<int>? previousAlarmIds,
  }) =>
      _runSessionValue((session) =>
          session.setAlarms(values, previousIds: previousAlarmIds));

  Future<void> disconnect() async {
    final session = _session;
    _session = null;
    _state = const JWSessionState(phase: JWSessionPhase.disconnected);
    await session?.dispose();
    _notifyUi();
  }

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) return;
    if (!(await Permission.locationWhenInUse.request()).isGranted) {
      throw StateError('请授予蓝牙/定位权限以扫描 JW 设备');
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
      Future<void> Function(JWWatchSession session) operation) async {
    final session = _session;
    if (session == null) {
      _error = StateError('请先连接 JW 设备');
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
      Future<T> Function(JWWatchSession session) operation) async {
    final session = _session;
    if (session == null) {
      final error = StateError('JW device must be connected first');
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

  void _recordState(JWSessionState state) {
    final message = switch (state.phase) {
      JWSessionPhase.connecting => '正在连接设备',
      JWSessionPhase.connected => '设备已连接',
      JWSessionPhase.loggingIn => '正在登录',
      JWSessionPhase.ready => '登录完成',
      JWSessionPhase.loginRejected => '登录被拒绝，需要首次绑定',
      JWSessionPhase.disconnected => '设备已断开',
      JWSessionPhase.failed => '会话失败：${state.error}',
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
