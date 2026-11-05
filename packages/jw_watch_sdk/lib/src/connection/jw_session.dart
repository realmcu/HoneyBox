import 'dart:async';
import 'dart:convert';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import '../capability/jw_feature.dart';
import '../model/jw_device_info.dart';
import '../model/jw_device_function_info.dart';
import '../model/jw_error.dart';
import '../model/jw_identity.dart';
import '../model/jw_session_state.dart';
import '../settings/jw_settings_models.dart';
import '../settings/jw_settings_codec.dart';
import 'jw_link.dart';
import 'jw_protocol.dart';

/// One owned connection/session. Reconnection creates a new instance.
final class JWWatchSession {
  JWWatchSession(this.connection)
      : _link = JWLink(connection),
        _state = const JWSessionState();

  final WatchTransportConnection connection;
  final JWLink _link;
  final _states = StreamController<JWSessionState>.broadcast(sync: true);
  JWSessionState _state;
  StreamSubscription<JWException>? _linkFailures;
  Future<void>? _opening;
  bool _disposed = false;

  JWSessionState get state => _state;
  Stream<JWSessionState> get states => _states.stream;

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
            targetId: info.targetId,
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
      final targetId = current?.targetId ?? connection.target.deviceId;
      final device = JWDeviceInfo(
        targetId: targetId,
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
            targetId: info.targetId,
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

  Future<void> login(JWIdentity identity) async {
    _requireConnected();
    _publish(
        _state.copyWith(phase: JWSessionPhase.loggingIn, clearError: true));
    final reply = await _link.request(JWProtocolCommands.login(identity.bytes));
    if (!_isSuccess(reply)) {
      _publish(_state.copyWith(phase: JWSessionPhase.loginRejected));
      return;
    }
    _publish(_state.copyWith(phase: JWSessionPhase.ready));
  }

  Future<void> bindFirstTime(JWIdentity identity,
      {required bool confirmed}) async {
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
      _publish(_state.copyWith(phase: JWSessionPhase.loginRejected));
      return;
    }
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
    _publish(_state.copyWith(phase: JWSessionPhase.readOnly));
  }

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
    await _link.send(JWProtocolCommands.setTime(JWSettingsCodec.encodeTime(time)));
    return const JWSettingSubmission('time');
  }

  /// Submits user profile data. JW V2 does not expose a read-back command.
  Future<JWSettingSubmission> setUserProfile(JWUserProfile profile) async {
    _requireReadyForSettings();
    await _link.send(
        JWProtocolCommands.setUserProfile(JWSettingsCodec.encodeUserProfile(profile)));
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
    return _oneByteSetting(await _link.request(JWProtocolCommands.readDateFormat()),
        'date format', JWDateFormat.fromCode);
  }

  /// Submits the date format. Firmware does not consistently expose a
  /// read-back response across JW devices.
  Future<JWSettingSubmission> setDateFormat(JWDateFormat value) async {
    _requireReadyForSettings();
    await _link.send(JWProtocolCommands.setDateFormat(value.code));
    return const JWSettingSubmission('date format');
  }

  Future<int> readScreenLightDuration() =>
      _readDisplayScalar(JWProtocolCommands.readScreenLightDuration(),
          'screen light duration', min: 3, max: 30);

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

  Future<int> readHomePage() => _readDisplayScalar(
      JWProtocolCommands.readHomePage(), 'home page', min: 0, max: 255);

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

  Future<JWSedentaryReminder> readSedentaryReminder() async {
    _requireReadyForSettings();
    return JWSettingsCodec.decodeSedentaryReminder(
        (await _link.request(JWProtocolCommands.readSedentaryReminder())).value);
  }

  Future<JWVerifiedSetting<JWSedentaryReminder>>
      setSedentaryReminderVerified(JWSedentaryReminder value) async {
    final previous = await readSedentaryReminder();
    await _link.send(JWProtocolCommands.setSedentaryReminder(
        JWSettingsCodec.encodeSedentaryReminder(value)));
    final actual = await readSedentaryReminder();
    _verifySetting('sedentary reminder', value, actual);
    return JWVerifiedSetting(previous: previous, value: actual);
  }

  Future<List<JWAlarm>> readAlarms() async {
    _requireReadyForSettings();
    return JWSettingsCodec
        .decodeAlarms((await _link.request(JWProtocolCommands.readAlarms())).value);
  }

  /// Replaces the legacy alarm table without a read-back equality guarantee.
  ///
  /// The device can normalize alarm dates/slots when writing the table, so a
  /// read-after-write equality check is not a valid success criterion.
  Future<JWSettingSubmission> setAlarms(List<JWAlarm> alarms) async {
    _requireReadyForSettings();
    final requested = List<JWAlarm>.unmodifiable(alarms);
    await _link.send(
        JWProtocolCommands.setAlarms(JWSettingsCodec.encodeAlarms(requested)));
    return const JWSettingSubmission('alarms');
  }

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
      return JWDeviceInfo(targetId: connection.target.deviceId);
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
      targetId: connection.target.deviceId,
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
      JWFeature.controls: support(JWFeature.controls, bit(52) || bit(54)),
      JWFeature.sport: support(JWFeature.sport, bit(3) || bit(48)),
      JWFeature.advancedHealth: support(
          JWFeature.advancedHealth, bit(0) || bit(2) || bit(5) || bit(15)),
    });
  }

  bool _isSuccess(JWProtocolMessage reply) =>
      reply.value.length == 1 && reply.value.single == 0;

  T _oneByteSetting<T>(JWProtocolMessage reply, String name,
      T Function(int code) decode) {
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
    final value = _oneByteSetting(await _link.request(request), name, (value) => value);
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

  void _publish(JWSessionState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _linkFailures?.cancel();
    await _link.dispose();
    _state = _state.copyWith(phase: JWSessionPhase.disposed);
    await _states.close();
  }
}
