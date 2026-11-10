import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import '../capability/jw_feature.dart';
import '../history/jw_history_models.dart';
import '../history/jw_history_sync.dart';
import '../history/jw_history_sync_frame.dart';
import '../history/jw_history_sync_listener.dart';
import '../storage/jw_history_store.dart';
import '../model/jw_device_info.dart';
import '../model/jw_device_function_info.dart';
import '../model/jw_error.dart';
import '../model/jw_identity.dart';
import '../model/jw_session_state.dart';
import '../settings/jw_address_book_codec.dart';
import '../settings/jw_address_book_models.dart';
import '../settings/jw_settings_models.dart';
import '../settings/jw_settings_codec.dart';
import '../control/jw_control.dart';
import '../control/jw_control_coordinator.dart';
import '../measure/jw_measure.dart';
import '../measure/jw_measure_coordinator.dart';
import '../today/jw_today_activity_codec.dart';
import '../today/jw_today_activity_models.dart';
import 'jw_link.dart';
import 'jw_protocol.dart';

/// One owned connection/session. Reconnection creates a new instance.
final class JWWatchSession {
  JWWatchSession(this.connection, {required JWHistoryStore historyStore})
      : _historyStore = historyStore,
        _link = JWLink(connection),
        _state = const JWSessionState();

  final WatchTransportConnection connection;
  final JWHistoryStore _historyStore;
  final JWLink _link;
  final _states = StreamController<JWSessionState>.broadcast(sync: true);
  JWSessionState _state;
  StreamSubscription<JWException>? _linkFailures;
  Future<void>? _opening;
  String? _authenticatedUserId;
  bool _disposed = false;

  JWSessionState get state => _state;
  Stream<JWSessionState> get states => _states.stream;

  /// The user ID authenticated by the current ready session.
  ///
  /// This is intentionally not included in [JWSessionState] or diagnostic
  /// events, so UI logging cannot accidentally disclose it.
  String? get authenticatedUserId => _authenticatedUserId;

  /// The only history scope associated with the current authenticated session.
  ///
  /// It is available only after successful login or first-time binding. The
  /// MAC comes from the connection target, so callers never need an invented
  /// device ID or a separate device registry merely to read health history.
  JWHistoryScope? get historyScope {
    final userId = _authenticatedUserId;
    if (userId == null || !_state.isReady) return null;
    final deviceMac = _state.device?.deviceMac ?? connection.target.deviceId;
    return JWHistoryScope(userId: userId, deviceMac: deviceMac);
  }

  /// The same [JWHistoryStore] opened by [JWWatch.initialize].
  ///
  /// Use with [historyScope] for offline queries after synchronization.
  JWHistoryStore get historyStore => _historyStore;

  Future<void>? _healthSync;

  /// True while [syncHealthData] is running on this session.
  bool get isHealthSyncActive => _healthSync != null;

  JWMeasureCoordinator? _measureCoordinator;
  JWMeasure? _measure;
  JWControlCoordinator? _controlCoordinator;
  JWControl? _control;

  /// Measure control and spot-measure listeners for the authenticated session.
  JWMeasure get measure => _measure ??= JWMeasure(
        link: _link,
        coordinator: _measureCoordinator ??= JWMeasureCoordinator(
          link: _link,
          isHealthSyncActive: () => _healthSync != null,
          temperatureCapable: () =>
              _state.functionInfo?.supports(JWDeviceFunction.temperature) ??
              false,
        ),
        isReady: () => _state.isReady,
        isHealthSyncActive: () => _healthSync != null,
        functionInfo: () => _state.functionInfo,
      );

  /// Take-photo, find-phone, music, and weather (`cmd 0x07`).
  JWControl get control => _control ??= JWControl(
        link: _link,
        coordinator: _controlCoordinator ??= JWControlCoordinator(link: _link),
        isReady: () => _state.isReady,
        functionInfo: () => _state.functionInfo,
      );

  /// Synchronizes JW health history for the authenticated session.
  ///
  /// Delivers decoded batches through [listener], persists through a background
  /// writer, and confirms the device only after wire completion and storage drain.
  /// There is no cancel API; link loss fails through [JWHistorySyncListener.onSyncFailed].
  Future<void> syncHealthData(
    JWHistorySyncListener listener, {
    void Function(JWHistorySyncFrame frame)? onHistoryFrame,
  }) {
    _requireReadyForSettings();
    final scope = historyScope;
    if (scope == null) {
      throw StateError('JW health sync requires an authenticated session');
    }
    if (_healthSync != null) {
      throw StateError('JW health sync is already active on this session');
    }
    final run = JWHealthHistorySync(
      link: _link,
      store: _historyStore,
      scope: scope,
      listener: listener,
      onHistoryFrame: onHistoryFrame,
    ).run();
    _healthSync = run;
    return run.whenComplete(() => _healthSync = null);
  }

  /// Reads today step / calorie / distance totals from the watch (HL §5.0B/§5.0C).
  ///
  /// Does not read [historyStore] and does not persist the snapshot. Requires
  /// [JWDeviceFunction.todayAdjust] when [JWSessionState.functionInfo] is present.
  Future<JWTodayActivitySummary> fetchTodayActivitySummary() async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.todayAdjust, 'today activity summary');
    final reply =
        await _link.request(JWProtocolCommands.queryTodayActivitySummary);
    return decodeJWTodayActivitySummary(reply.value);
  }

  /// Clears device-side history sync markers so a later [syncHealthData] can
  /// transfer records again (HL §5.FA / Android `setFullSync`).
  ///
  /// Fire-and-forget: protocol has no application reply; returns empty bytes
  /// after transport send completes.
  Future<Uint8List> resetHistorySyncMarkers() async {
    _requireReadyForSettings();
    if (_healthSync != null) {
      throw StateError('JW health sync is already active');
    }
    await _link.send(JWProtocolCommands.resetHistorySyncMarkers());
    return Uint8List(0);
  }

  /// Factory RESET (HL §6.FC): erase device data; firmware typically reboots.
  ///
  /// Android App「清除数据」→ `WristbandManager.sendResetRequest`. Requires an
  /// explicit application confirmation. No business reply; link drop / ACK
  /// timeout after a successful enqueue is treated as success.
  Future<void> clearDeviceData({required bool confirmed}) async {
    if (!confirmed) {
      throw StateError('JW clearDeviceData requires explicit user confirmation');
    }
    _requireReadyForSettings();
    if (_healthSync != null) {
      throw StateError('JW health sync is already active');
    }
    try {
      await _link.send(JWProtocolCommands.clearDeviceData());
    } on JWException catch (error) {
      if (error.code != JWErrorCode.transportDisconnected &&
          error.code != JWErrorCode.ackTimeout) {
        rethrow;
      }
    }
  }

  /// Opens the JW byte channel. This does not log in, bind, or query device
  /// characteristics; applications can present those as explicit steps.
  Future<void> connect() => _opening ??= _connect();

  Future<void> _connect() async {
    _publish(
        _state.copyWith(phase: JWSessionPhase.connecting, clearError: true));
    _linkFailures = _link.failures.listen((error) {
      if (!_disposed) {
        _publish(
            _state.copyWith(phase: JWSessionPhase.disconnected, error: error));
      }
    });
    try {
      await _link.open();
      _publish(_state.copyWith(phase: JWSessionPhase.connected));
    } catch (error) {
      if (!_disposed) {
        _publish(_state.copyWith(phase: JWSessionPhase.failed, error: error));
      }
      rethrow;
    }
  }

  /// Reads standard GATT device information. Does not read the JW capability
  /// report.
  Future<void> readDeviceInfo() async {
    _requireConnected();
    final wasReady = _state.isReady;
    final previousBattery = _state.device?.battery;
    _publish(_state.copyWith(clearError: true));
    try {
      final info = await _readDeviceInfo();
      final phase = wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
      _publish(_state.copyWith(
          phase: phase,
          device: JWDeviceInfo(
            deviceMac: info.deviceMac,
            name: info.name,
            serialNumber: info.serialNumber,
            firmware: info.firmware,
            hardware: info.hardware,
            battery: previousBattery,
          )));
    } catch (error) {
      if (!_disposed) {
        final phase =
            wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
        _publish(_state.copyWith(phase: phase, error: error));
      }
      rethrow;
    }
  }

  /// Reads the standard GATT battery level (service `180f`, characteristic `2a19`).
  ///
  /// This is independent from [readDeviceInfo], matching the legacy Android
  /// battery read entry point.
  Future<int?> readBattery() async {
    _requireConnected();
    final wasReady = _state.isReady;
    _publish(_state.copyWith(clearError: true));
    try {
      final level = await _readBattery();
      final current = _state.device;
      final deviceMac = current?.deviceMac ?? connection.target.deviceId;
      final device = JWDeviceInfo(
        deviceMac: deviceMac,
        name: current?.name,
        serialNumber: current?.serialNumber,
        firmware: current?.firmware,
        hardware: current?.hardware,
        battery: level,
      );
      final phase = wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
      _publish(_state.copyWith(phase: phase, device: device));
      return level;
    } catch (error) {
      if (!_disposed) {
        final phase =
            wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
        _publish(_state.copyWith(phase: phase, error: error));
      }
      rethrow;
    }
  }

  /// Reads optional GATT device information and the JW capability report.
  /// The connection remains usable even when this optional discovery fails.
  Future<void> readDeviceDetails() async {
    _requireConnected();
    final wasReady = _state.isReady;
    final previousBattery = _state.device?.battery;
    _publish(_state.copyWith(clearError: true));
    try {
      final info = await _readDeviceInfo();
      final features = await _readFeatures();
      final phase = wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
      _publish(_state.copyWith(
          phase: phase,
          device: JWDeviceInfo(
            deviceMac: info.deviceMac,
            name: info.name,
            serialNumber: info.serialNumber,
            firmware: info.firmware,
            hardware: info.hardware,
            battery: previousBattery,
          ),
          features: features));
    } catch (error) {
      if (!_disposed) {
        final phase =
            wasReady ? JWSessionPhase.ready : JWSessionPhase.connected;
        _publish(_state.copyWith(phase: phase, error: error));
      }
      rethrow;
    }
  }

  /// Reads the complete eight-byte JW device-function report (0x02/0x37).
  ///
  /// This is independent from standard GATT device information. The parsed
  /// result is retained in [state.functionInfo] and is also summarized into
  /// the existing top-level [JWFeature] groups.
  Future<void> readDeviceFeatures() async {
    _requireConnected();
    final wasReady = _state.isReady;
    _publish(_state.copyWith(clearError: true));
    try {
      final reply = await _link.request(JWProtocolCommands.functions());
      final functionInfo = JWDeviceFunctionInfo.fromWire(reply.value);
      final features = await _readFeatures();
      _publish(_state.copyWith(
          phase: wasReady ? JWSessionPhase.ready : JWSessionPhase.connected,
          functionInfo: functionInfo,
          features: features));
    } catch (error) {
      if (!_disposed) {
        _publish(_state.copyWith(
            phase: wasReady ? JWSessionPhase.ready : JWSessionPhase.connected,
            error: error));
      }
      rethrow;
    }
  }

  /// Logs in with the application-provided JW user ID.
  ///
  /// The SDK never generates a replacement identity: doing so could make a
  /// previously bound watch reject its real owner. A successful login also
  /// synchronizes the connected device clock before entering `ready`.
  Future<void> login(String userId) async {
    final identity = JWIdentity(userId);
    _requireConnected();
    _publish(
        _state.copyWith(phase: JWSessionPhase.loggingIn, clearError: true));
    final reply = await _link.request(JWProtocolCommands.login(identity.bytes));
    if (!_isSuccess(reply)) {
      _authenticatedUserId = null;
      _publish(_state.copyWith(phase: JWSessionPhase.loginRejected));
      return;
    }
    await _syncClockAfterAuthentication();
    _authenticatedUserId = identity.value;
    _publish(_state.copyWith(phase: JWSessionPhase.ready));
  }

  Future<void> bindFirstTime(String userId, {required bool confirmed}) async {
    final identity = JWIdentity(userId);
    if (!confirmed) {
      throw StateError('First JW bind requires explicit user confirmation');
    }
    if (_state.phase != JWSessionPhase.loginRejected &&
        _state.phase != JWSessionPhase.connected &&
        _state.phase != JWSessionPhase.readOnly) {
      throw StateError('JW bind is not available in ${_state.phase.name}');
    }
    _publish(
        _state.copyWith(phase: JWSessionPhase.loggingIn, clearError: true));
    final reply = await _link.request(JWProtocolCommands.bind(identity.bytes));
    if (!_isSuccess(reply)) {
      _authenticatedUserId = null;
      _publish(_state.copyWith(phase: JWSessionPhase.loginRejected));
      return;
    }
    await _syncClockAfterAuthentication();
    _authenticatedUserId = identity.value;
    _publish(_state.copyWith(phase: JWSessionPhase.ready));
  }

  /// Removes this installation's binding after an explicit application-level
  /// confirmation. JW firmware does not send a business reply for this command.
  Future<void> unbind({required bool confirmed}) async {
    if (!confirmed) {
      throw StateError('JW unbind requires explicit user confirmation');
    }
    if (_state.phase != JWSessionPhase.ready) {
      throw StateError('JW unbind is not available in ${_state.phase.name}');
    }
    await _link.send(JWProtocolCommands.unbind());
    _authenticatedUserId = null;
    _publish(_state.copyWith(phase: JWSessionPhase.readOnly));
  }

  Future<void> _syncClockAfterAuthentication() => _link.send(
      JWProtocolCommands.setTime(JWSettingsCodec.encodeTime(DateTime.now())));

  /// Reads the language currently reported by the device.
  Future<JWLanguage> readLanguage() async {
    _requireReadyForSettings();
    final reply = await _link.request(JWProtocolCommands.readLanguage());
    return _oneByteSetting(reply, 'language', JWLanguage.fromCode);
  }

  /// Writes [value], then reads the device state back to verify it.
  Future<JWVerifiedSetting<JWLanguage>> setLanguageVerified(
      JWLanguage value) async {
    _requireReadyForSettings();
    final previous = await readLanguage();
    await _link.send(JWProtocolCommands.setLanguage(value.code));
    final actual = await readLanguage();
    _verifySetting('language', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  /// Reads the 12/24-hour system currently reported by the device.
  Future<JWHourSystem> readHourSystem() async {
    _requireReadyForSettings();
    final reply = await _link.request(JWProtocolCommands.readHourSystem());
    return _oneByteSetting(reply, 'hour system', JWHourSystem.fromCode);
  }

  /// Writes [value], then reads the device state back to verify it.
  Future<JWVerifiedSetting<JWHourSystem>> setHourSystemVerified(
      JWHourSystem value) async {
    _requireReadyForSettings();
    final previous = await readHourSystem();
    await _link.send(JWProtocolCommands.setHourSystem(value.code));
    final actual = await readHourSystem();
    _verifySetting('hour system', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  /// Reads the metric/imperial system currently reported by the device.
  Future<JWUnitSystem> readUnitSystem() async {
    _requireReadyForSettings();
    final reply = await _link.request(JWProtocolCommands.readUnitSystem());
    return _oneByteSetting(reply, 'unit system', JWUnitSystem.fromCode);
  }

  /// Writes [value], then reads the device state back to verify it.
  Future<JWVerifiedSetting<JWUnitSystem>> setUnitSystemVerified(
      JWUnitSystem value) async {
    _requireReadyForSettings();
    final previous = await readUnitSystem();
    await _link.send(JWProtocolCommands.setUnitSystem(value.code));
    final actual = await readUnitSystem();
    _verifySetting('unit system', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  /// Submits local [time] to the device.
  ///
  /// The JW protocol has no read-back command for this setting, so the result
  /// confirms transport submission only, not that firmware applied the clock.
  Future<JWSettingSubmission> setTime(DateTime time) async {
    _requireReadyForSettings();
    await _link
        .send(JWProtocolCommands.setTime(JWSettingsCodec.encodeTime(time)));
    return const JWSettingSubmission('time');
  }

  /// Submits user profile data. JW V2 does not expose a read-back command.
  Future<JWSettingSubmission> setUserProfile(JWUserProfile profile) async {
    _requireReadyForSettings();
    await _link.send(JWProtocolCommands.setUserProfile(
        JWSettingsCodec.encodeUserProfile(profile)));
    return const JWSettingSubmission('user profile');
  }

  /// Submits all daily goals. JW V2 does not expose read-back commands.
  Future<JWSettingSubmission> setGoals(JWGoals goals) async {
    _requireReadyForSettings();
    await _link.send(JWProtocolCommands.setStepGoal(
        JWSettingsCodec.encodeUint32(goals.steps, 'steps')));
    await _link.send(JWProtocolCommands.setSleepGoal(
        JWSettingsCodec.encodeUint16(goals.sleepMinutes, 'sleepMinutes')));
    await _link.send(JWProtocolCommands.setCalorieGoal(
        JWSettingsCodec.encodeUint16(goals.calories, 'calories')));
    return const JWSettingSubmission('daily goals');
  }

  Future<JWDateFormat> readDateFormat() async {
    _requireReadyForSettings();
    return _oneByteSetting(
        await _link.request(JWProtocolCommands.readDateFormat()),
        'date format',
        JWDateFormat.fromCode);
  }

  /// Submits the date format. Firmware does not consistently expose a
  /// read-back response across JW devices.
  Future<JWSettingSubmission> setDateFormat(JWDateFormat value) async {
    _requireReadyForSettings();
    await _link.send(JWProtocolCommands.setDateFormat(value.code));
    return const JWSettingSubmission('date format');
  }

  Future<int> readScreenLightDuration() => _readDisplayScalar(
      JWProtocolCommands.readScreenLightDuration(), 'screen light duration',
      min: 3, max: 30);

  /// Submits screen light duration without a read-back value.
  Future<JWSettingSubmission> setScreenLightDuration(int seconds) async {
    _requireReadyForSettings();
    _rangeSetting(seconds, 'screen light duration', min: 3, max: 30);
    await _link.send(JWProtocolCommands.setScreenLightDuration(seconds));
    return const JWSettingSubmission('screen light duration');
  }

  Future<int> readScreenBrightness() => _readDisplayScalar(
      JWProtocolCommands.readScreenBrightness(), 'screen brightness',
      min: 20, max: 100);

  /// Submits screen brightness without a read-back value.
  Future<JWSettingSubmission> setScreenBrightness(int percent) async {
    _requireReadyForSettings();
    _rangeSetting(percent, 'screen brightness', min: 20, max: 100);
    await _link.send(JWProtocolCommands.setScreenBrightness(percent));
    return const JWSettingSubmission('screen brightness');
  }

  Future<int> readHomePage() =>
      _readDisplayScalar(JWProtocolCommands.readHomePage(), 'home page',
          min: 0, max: 255);

  /// Submits the home page index without a read-back value.
  Future<JWSettingSubmission> setHomePage(int index) async {
    _requireReadyForSettings();
    _rangeSetting(index, 'home page', min: 0, max: 255);
    await _link.send(JWProtocolCommands.setHomePage(index));
    return const JWSettingSubmission('home page');
  }

  Future<bool> readTurnWristToWake() async {
    _requireReadyForSettings();
    final value = _oneByteSetting(
        await _link.request(JWProtocolCommands.readTurnWristToWake()),
        'turn wrist to wake',
        (value) => value);
    if (value != 0 && value != 1) {
      throw FormatException('Unsupported JW turn wrist to wake value: $value');
    }
    return value == 1;
  }

  /// Submits the wrist-to-wake state without a read-back value.
  Future<JWSettingSubmission> setTurnWristToWake(bool value) async {
    _requireReadyForSettings();
    await _link.send(JWProtocolCommands.setTurnWristToWake(value));
    return const JWSettingSubmission('turn wrist to wake');
  }

  /// Starts or stops Immediate Alert find-device (GATT `1802` / `2a06`).
  ///
  /// Writes alert level `2` when [enabled] is true and `0` when false. This is
  /// the same path as Android `WristbandManager.enableImmediateAlert`, not a
  /// private protocol FAC vibrate command. Requires [JWDeviceFunction.findDevice]
  /// and a [WatchBleConnection] with a writable IAS endpoint.
  Future<JWSettingSubmission> findDevice(bool enabled) async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.findDevice, 'find device');
    if (connection is! WatchBleConnection) {
      throw StateError('Find device requires a BLE connection');
    }
    final ble = connection as WatchBleConnection;
    await ble.writeCharacteristic(
      service: '1802',
      characteristic: '2a06',
      bytes: Uint8List.fromList([enabled ? 2 : 0]),
    );
    return const JWSettingSubmission('find device');
  }

  /// Replaces the on-device address book (V2 `setAddressBook`).
  ///
  /// Pass an empty list to clear. At most [kJwMaxAddressBookEntries] contacts.
  Future<JWSettingSubmission> setAddressBook(
      List<JWAddressBookEntry> entries) async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.addressBook, 'address book');
    final list = List<JWAddressBookEntry>.unmodifiable(entries);
    if (list.length > kJwMaxAddressBookEntries) {
      throw ArgumentError.value(list.length, 'entries',
          'must not exceed $kJwMaxAddressBookEntries');
    }
    final count = list.length;
    if (count == 0) {
      await _link.send(JWProtocolCommands.setAddressBookValue(
          encodeAddressBookPhase(status: 0, size: 0)));
      return const JWSettingSubmission('address book');
    }
    await _link.send(JWProtocolCommands.setAddressBookValue(
        encodeAddressBookPhase(status: 0, size: count)));
    for (final entry in list) {
      final reply = await _link.sendAndAwaitUnsolicited(
        request: JWProtocolCommands.setAddressBookValue(
            encodeAddressBookEntry(entry)),
        responseCommand: 2,
        responseKey: JWProtocolCommands.addressBookResponseKey,
      );
      if (!decodeAddressBookEntryAck(reply.value)) {
        throw const JWException(
            JWErrorCode.protocol, 'JW address book entry rejected by device');
      }
    }
    await _link.send(JWProtocolCommands.setAddressBookValue(
        encodeAddressBookPhase(status: 1, size: count)));
    return const JWSettingSubmission('address book');
  }

  Future<JWDoNotDisturb> readDoNotDisturb() async {
    _requireReadyForSettings();
    return JWSettingsCodec.decodeDoNotDisturb(
        (await _link.request(JWProtocolCommands.readDoNotDisturb())).value);
  }

  Future<JWVerifiedSetting<JWDoNotDisturb>> setDoNotDisturbVerified(
      JWDoNotDisturb value) async {
    final previous = await readDoNotDisturb();
    await _link.send(JWProtocolCommands.setDoNotDisturb(
        JWSettingsCodec.encodeDoNotDisturb(value)));
    final actual = await readDoNotDisturb();
    _verifySetting('do not disturb', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  Future<JWHeatStressReminder> readHeatStressReminder() async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.heatStress, 'heat stress reminder');
    return JWSettingsCodec.decodeHeatStressReminder(
        (await _link.request(JWProtocolCommands.readHeatStressReminder()))
            .value);
  }

  Future<JWVerifiedSetting<JWHeatStressReminder>> setHeatStressReminderVerified(
      JWHeatStressReminder value) async {
    _requireDeviceFunction(JWDeviceFunction.heatStress, 'heat stress reminder');
    final previous = await readHeatStressReminder();
    await _link.send(JWProtocolCommands.setHeatStressReminder(
        JWSettingsCodec.encodeHeatStressReminder(value)));
    final actual = await readHeatStressReminder();
    _verifySetting('heat stress reminder', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  Future<JWHighHeartRateReminder> readHighHeartRateReminder() async {
    _requireReadyForSettings();
    _requireAnyDeviceFunction(
      const [JWDeviceFunction.rateReminder, JWDeviceFunction.highHrv],
      'high heart rate reminder',
    );
    return JWSettingsCodec.decodeHighHeartRateReminder(
        (await _link.request(JWProtocolCommands.readHighHeartRateReminder()))
            .value);
  }

  /// Low blood-oxygen alert (`cmd 0x02` / `0x72`–`0x74`), aligned with App
  /// `CSFunctionManager.setLowSpO2Reminder` and V2 `setHypoxiaSwitch`.
  Future<bool> readLowSpO2Reminder() async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.hypoxia, 'low SpO2 reminder');
    return JWSettingsCodec.decodeLowSpO2Reminder(
        (await _link.request(JWProtocolCommands.readLowSpO2Reminder())).value);
  }

  Future<JWSettingSubmission> setLowSpO2Reminder(bool enabled) async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.hypoxia, 'low SpO2 reminder');
    await _link.send(JWProtocolCommands.setLowSpO2Reminder(enabled));
    return const JWSettingSubmission('low SpO2 reminder');
  }

  Future<JWVerifiedSetting<bool>> setLowSpO2ReminderVerified(
      bool enabled) async {
    _requireDeviceFunction(JWDeviceFunction.hypoxia, 'low SpO2 reminder');
    final previous = await readLowSpO2Reminder();
    await _link.send(JWProtocolCommands.setLowSpO2Reminder(enabled));
    final actual = await readLowSpO2Reminder();
    if (actual != enabled) {
      throw JWException(
        JWErrorCode.protocol,
        'JW low SpO2 reminder read-back mismatch '
        '(expected $enabled, got $actual)',
      );
    }
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  Future<JWVerifiedSetting<JWHighHeartRateReminder>>
      setHighHeartRateReminderVerified(JWHighHeartRateReminder value) async {
    _requireAnyDeviceFunction(
      const [JWDeviceFunction.rateReminder, JWDeviceFunction.highHrv],
      'high heart rate reminder',
    );
    final previous = await readHighHeartRateReminder();
    await _link.send(JWProtocolCommands.setHighHeartRateReminder(
        JWSettingsCodec.encodeHighHeartRateReminder(value)));
    final actual = await readHighHeartRateReminder();
    _verifySetting('high heart rate reminder', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  Future<JWSedentaryReminder> readSedentaryReminder() async {
    _requireReadyForSettings();
    return JWSettingsCodec.decodeSedentaryReminder(
        (await _link.request(JWProtocolCommands.readSedentaryReminder()))
            .value);
  }

  /// Reads social / call notify switches (`0x28` → `0x29`).
  Future<JWNotifySettings> readNotifySettings() async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.notifyReminder, 'notify reminder');
    return JWSettingsCodec.decodeNotifySettings(
        (await _link.request(JWProtocolCommands.readNotifySettings())).value);
  }

  /// Writes the full notify-switch table (`0x2D`) and reads it back.
  Future<JWVerifiedSetting<JWNotifySettings>> setNotifySettingsVerified(
      JWNotifySettings value) async {
    _requireDeviceFunction(JWDeviceFunction.notifyReminder, 'notify reminder');
    final previous = await readNotifySettings();
    await _link.send(JWProtocolCommands.setNotifySettings(
        JWSettingsCodec.encodeNotifySettings(value)));
    final actual = await readNotifySettings();
    _verifySetting('notify settings', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  /// Toggles one channel via single-byte `0x25`, then reads the full table.
  Future<JWVerifiedSetting<JWNotifySettings>> setNotifyChannelVerified(
    JWNotifyChannel channel,
    bool enabled,
  ) async {
    _requireDeviceFunction(JWDeviceFunction.notifyReminder, 'notify reminder');
    final previous = await readNotifySettings();
    await _link.send(JWProtocolCommands.setNotifyChannel(
        enabled ? channel.enableCode : channel.disableCode));
    final actual = await readNotifySettings();
    final expected = previous.withChannel(channel, enabled);
    _verifySetting('notify channel', expected, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  /// Pushes an app message alert to the watch (`cmd 0x04` / `key 0x04`).
  Future<JWSettingSubmission> sendNotifyMessage(
    JWNotifyChannel channel, {
    String text = '',
  }) async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.notifyReminder, 'notify reminder');
    await _link.send(JWProtocolCommands.sendNotifyMessage(
        JWSettingsCodec.encodeNotifyMessage(channel, text)));
    return const JWSettingSubmission('notify message');
  }

  /// Pushes an incoming-call alert (`cmd 0x04` / `key 0x01`).
  Future<JWSettingSubmission> sendIncomingCall({String display = ''}) async {
    _requireReadyForSettings();
    _requireDeviceFunction(JWDeviceFunction.notifyReminder, 'notify reminder');
    await _link.send(JWProtocolCommands.sendIncomingCall(
        JWSettingsCodec.encodeIncomingCall(display)));
    return const JWSettingSubmission('incoming call');
  }

  Future<JWVerifiedSetting<JWSedentaryReminder>> setSedentaryReminderVerified(
      JWSedentaryReminder value) async {
    final previous = await readSedentaryReminder();
    await _link.send(JWProtocolCommands.setSedentaryReminder(
        JWSettingsCodec.encodeSedentaryReminder(value)));
    final actual = await readSedentaryReminder();
    _verifySetting('sedentary reminder', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  Future<List<JWAlarm>> readAlarms() async {
    _requireReadyForSettings();
    if (_usesLabeledAlarmProtocol()) {
      return readLabeledAlarms();
    }
    return readStandardAlarms();
  }

  Future<List<JWAlarm>> readStandardAlarms() async {
    _requireReadyForSettings();
    return JWSettingsCodec.decodeAlarms(
        (await _link.request(JWProtocolCommands.readAlarms())).value);
  }

  Future<List<JWAlarm>> readLabeledAlarms() async {
    _requireReadyForSettings();
    final messages = await _link.collectSettingResponses(
      trigger: JWProtocolCommands.requestAlarms2(),
      responseCommand: 2,
      responseKey: JWProtocolCommands.alarms2ResponseKey,
      isComplete: (message) {
        final chunk = JWSettingsCodec.decodeAlarm2ReadChunk(message.value);
        return chunk.count == 0 || chunk.curIndex == chunk.count;
      },
    );
    return JWSettingsCodec.decodeAlarm2List(
        messages.map((message) => message.value).toList());
  }

  /// Replaces the device alarm table without a read-back equality guarantee.
  ///
  /// Uses labeled alarm2 when supported, otherwise the standard alarm table.
  Future<JWSettingSubmission> setAlarms(
    List<JWAlarm> alarms, {
    Set<int>? previousIds,
  }) async {
    _requireReadyForSettings();
    final requested = List<JWAlarm>.unmodifiable(alarms);
    if (_usesLabeledAlarmProtocol()) {
      await _replaceLabeledAlarms(requested, previousIds: previousIds);
    } else {
      await _link.send(JWProtocolCommands.setAlarms(
          JWSettingsCodec.encodeAlarms(requested)));
    }
    return const JWSettingSubmission('alarms');
  }

  Future<void> _replaceLabeledAlarms(
    List<JWAlarm> alarms, {
    Set<int>? previousIds,
  }) async {
    final nextIds = alarms.map((alarm) => alarm.id).toSet();
    final staleIds = {...?previousIds}..removeAll(nextIds);
    for (final id in staleIds) {
      await _link
          .send(JWProtocolCommands.setAlarm2(JWSettingsCodec.encodeAlarm2(
        JWAlarm(
          id: id,
          time: DateTime.now(),
          repeatDays: 0,
          enabled: false,
        ),
        delete: true,
      )));
    }
    for (final alarm in alarms) {
      await _link.send(
          JWProtocolCommands.setAlarm2(JWSettingsCodec.encodeAlarm2(alarm)));
    }
  }

  bool _usesLabeledAlarmProtocol() =>
      _state.functionInfo?.supports(JWDeviceFunction.alarm2) ?? false;

  Future<int?> _readBattery() async {
    if (connection is! WatchBleConnection) return null;
    final ble = connection as WatchBleConnection;
    try {
      final bytes = await ble.readGatt(service: '180f', characteristic: '2a19');
      return bytes.length == 1 && bytes.single <= 100 ? bytes.single : null;
    } catch (_) {
      return null;
    }
  }

  Future<JWDeviceInfo> _readDeviceInfo() async {
    if (connection is! WatchBleConnection) {
      return JWDeviceInfo(deviceMac: connection.target.deviceId);
    }
    final ble = connection as WatchBleConnection;
    Future<String?> text(String service, String characteristic) async {
      try {
        final bytes = await ble.readGatt(
            service: service, characteristic: characteristic);
        final value = utf8
            .decode(bytes, allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim();
        return value.isEmpty ? null : value;
      } catch (_) {
        return null;
      }
    }

    return JWDeviceInfo(
      deviceMac: connection.target.deviceId,
      name: await text('1800', '2a00'),
      serialNumber: await text('180a', '2a25'),
      firmware: await text('180a', '2a26'),
      hardware: await text('180a', '2a27'),
    );
  }

  Future<Map<JWFeature, JWFeatureSupport>> _readFeatures() async {
    final functions = await _link.request(JWProtocolCommands.functions());
    final factory = await _link.request(JWProtocolCommands.factorySwitch());
    if (functions.value.length != 8 || factory.value.length != 1) {
      throw const FormatException('Invalid JW capability payload');
    }
    final bits = BigInt.parse(
        functions.value
            .map((value) => value.toRadixString(16).padLeft(2, '0'))
            .join(),
        radix: 16);
    bool bit(int index) => ((bits >> index) & BigInt.one) == BigInt.one;
    JWFeatureSupport support(JWFeature feature, bool value) => JWFeatureSupport(
        feature: feature,
        availability: value
            ? JWFeatureAvailability.supported
            : JWFeatureAvailability.unsupported,
        reason: value
            ? null
            : 'Current device capability list does not report support');
    return Map.unmodifiable({
      JWFeature.connection: support(JWFeature.connection, true),
      JWFeature.deviceInformation: support(JWFeature.deviceInformation, true),
      JWFeature.settings:
          support(JWFeature.settings, bit(43) || bit(44) || bit(45)),
      JWFeature.reminders:
          support(JWFeature.reminders, bit(58) || bit(59) || bit(40)),
      JWFeature.measurements: support(
          JWFeature.measurements, bit(24) || bit(29) || bit(33) || bit(34)),
      JWFeature.history:
          support(JWFeature.history, bit(34) || bit(36) || bit(37)),
      JWFeature.notifications: support(JWFeature.notifications, bit(40)),
      JWFeature.controls: support(
          JWFeature.controls,
          bit(0) || bit(12) || bit(13) /* music, camera, findPhone */),
      JWFeature.sport: support(JWFeature.sport, bit(3) || bit(48)),
      JWFeature.advancedHealth: support(
          JWFeature.advancedHealth, bit(0) || bit(2) || bit(5) || bit(15)),
    });
  }

  bool _isSuccess(JWProtocolMessage reply) =>
      reply.value.length == 1 && reply.value.single == 0;

  T _oneByteSetting<T>(
      JWProtocolMessage reply, String name, T Function(int code) decode) {
    if (reply.value.length != 1) {
      throw FormatException('Invalid JW $name response length');
    }
    return decode(reply.value.single);
  }

  void _verifySetting<T>(String name, T expected, T actual) {
    if (actual != expected) {
      throw StateError('JW $name read-back did not match the submitted value');
    }
  }

  Future<int> _readDisplayScalar(JWProtocolRequest request, String name,
      {required int min, required int max}) async {
    _requireReadyForSettings();
    final value =
        _oneByteSetting(await _link.request(request), name, (value) => value);
    if (value < min || value > max) {
      throw FormatException('Unsupported JW $name value: $value');
    }
    return value;
  }

  void _rangeSetting(int value, String name,
      {required int min, required int max}) {
    if (value < min || value > max) {
      throw ArgumentError.value(value, name, 'must be between $min and $max');
    }
  }

  void _requireConnected() {
    if (!_link.isOpen || _state.phase == JWSessionPhase.disconnected) {
      throw StateError('JW session is not connected');
    }
  }

  void _requireReadyForSettings() {
    _requireConnected();
    if (_state.phase != JWSessionPhase.ready) {
      throw StateError('JW settings require an authenticated session');
    }
  }

  void _requireDeviceFunction(JWDeviceFunction function, String name) {
    final info = _state.functionInfo;
    if (info == null || !info.supports(function)) {
      throw StateError('JW device does not support $name');
    }
  }

  void _requireAnyDeviceFunction(
      List<JWDeviceFunction> functions, String name) {
    final info = _state.functionInfo;
    if (info == null || !functions.any(info.supports)) {
      throw StateError('JW device does not support $name');
    }
  }

  void _publish(JWSessionState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _authenticatedUserId = null;
    _measureCoordinator?.dispose();
    _measureCoordinator = null;
    _measure = null;
    _controlCoordinator?.dispose();
    _controlCoordinator = null;
    _control = null;
    await _linkFailures?.cancel();
    await _link.dispose();
    _state = _state.copyWith(phase: JWSessionPhase.disposed);
    await _states.close();
  }
}
