import 'history/jw_history_models.dart';
import 'dart:typed_data';
import 'jw_configuration.dart';

class JwCapabilities {
  final BigInt _bits;
  final String rawHex;
  final int factorySwitchRaw;
  JwCapabilities._(this._bits, this.rawHex, this.factorySwitchRaw);
  factory JwCapabilities.fromWire(Uint8List functions, Uint8List factory) {
    if (functions.length != 8 || factory.length != 1) {
      throw const FormatException('JW capability payload length');
    }
    final hex =
        functions.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return JwCapabilities._(BigInt.parse(hex, radix: 16), hex, factory.single);
  }
  bool _bit(int n) => ((_bits >> n) & BigInt.one) == BigInt.one;
  // T_FUNCTION_LIST in communicate_parse.h, not the stale CLI reserve names.
  bool get bloodOxygen => _bit(24);
  bool get bloodPressure => _bit(33);
  bool get steps => _bit(36);
  bool get sleep => _bit(37);
  bool get exercise => _bit(48);
  bool get sportControl => _bit(3);
  bool get legacyAlarm => _bit(58);
  bool get longSit => _bit(59);
  bool get socialReminder => _bit(40);
  bool get camera => _bit(52);
  bool get findDevice => _bit(54);
  bool get readiness => _bit(0);
  bool get metabDaily => _bit(2);
  bool get pressureMonitor => _bit(5);
  bool get hrv => _bit(15);
  bool get temperature => _bit(29);
  bool get heartRate => _bit(34);
  bool get languages => _bit(43);
  bool get hourSystem => _bit(44);
  bool get distanceUnit => _bit(45);
  bool get displayTime => _bit(39);
  bool get screenBrightness => _bit(55);
  bool get autoHeartRate => _bit(34);
  bool get autoBloodOxygen => _bit(19);
  bool get autoBloodPressure => _bit(14);
  bool get healthStatus => _bit(17);
  bool get turnOverWrist => _bit(42);
  bool get disturb => _bit(35);
  bool get heatStressReminder => _bit(4);
  bool get highHeartRateReminder => _bit(11);
  bool get factoryBloodPressure => factorySwitchRaw & 1 != 0;
  bool get factoryTemperature => factorySwitchRaw & 2 != 0;
  bool get factoryStress => factorySwitchRaw & 4 != 0;
}

class JwDeviceInfo {
  final String deviceKey;
  final String? name;
  final String? firmware;
  final String? hardware;
  final int? battery;
  const JwDeviceInfo(
      {required this.deviceKey,
      this.name,
      this.firmware,
      this.hardware,
      this.battery});
}

class JwHeartRateSample {
  final int bpm;
  final DateTime date;
  final int minute;
  final int second;
  final DateTime receivedAt;
  final Uint8List raw;
  JwHeartRateSample(
      {required this.bpm,
      required this.date,
      required this.minute,
      required this.second,
      required this.receivedAt,
      required Uint8List raw})
      : raw = Uint8List.fromList(raw).asUnmodifiableView();
}

enum JwDevicePhase {
  loading,
  readOnly,
  identityUnavailable,
  loggingIn,
  loggedIn,
  loginRejected,
  failed,
  disconnected
}

const _keepJwValue = Object();

class JwDeviceState {
  final JwDevicePhase phase;
  final JwDeviceInfo? info;
  final JwCapabilities? capabilities;
  final int? language;
  final JwHeartRateSample? lastHeartRate;
  final bool timeSubmitted;
  final bool heartRateStreaming;
  final bool operationInProgress;
  final String? operationError;
  final JwHistoryProgress? historyProgress;
  final JwHistoryResult? lastHistoryResult;
  final JwConfigurationValues? configurationValues;
  Map<JwConfigurationDomain, JwConfigurationValue> get configuration =>
      configurationValues?.values ?? const {};
  const JwDeviceState(
      {this.phase = JwDevicePhase.loading,
      this.info,
      this.capabilities,
      this.language,
      this.lastHeartRate,
      this.timeSubmitted = false,
      this.heartRateStreaming = false,
      this.operationInProgress = false,
      this.operationError,
      this.historyProgress,
      this.lastHistoryResult,
      this.configurationValues});
  bool get canWrite => phase == JwDevicePhase.loggedIn && !operationInProgress;
  JwDeviceState copyWith(
          {JwDevicePhase? phase,
          JwDeviceInfo? info,
          JwCapabilities? capabilities,
          int? language,
          Object? lastHeartRate = _keepJwValue,
          bool? timeSubmitted,
          bool? heartRateStreaming,
          bool? operationInProgress,
          Object? operationError = _keepJwValue,
          Object? historyProgress = _keepJwValue,
          Object? lastHistoryResult = _keepJwValue,
          Map<JwConfigurationDomain, JwConfigurationValue>? configuration}) =>
      JwDeviceState(
          configurationValues: configuration == null
              ? configurationValues
              : JwConfigurationValues(configuration),
          historyProgress: identical(historyProgress, _keepJwValue)
              ? this.historyProgress
              : historyProgress as JwHistoryProgress?,
          lastHistoryResult: identical(lastHistoryResult, _keepJwValue)
              ? this.lastHistoryResult
              : lastHistoryResult as JwHistoryResult?,
          phase: phase ?? this.phase,
          info: info ?? this.info,
          capabilities: capabilities ?? this.capabilities,
          language: language ?? this.language,
          lastHeartRate: identical(lastHeartRate, _keepJwValue)
              ? this.lastHeartRate
              : lastHeartRate as JwHeartRateSample?,
          timeSubmitted: timeSubmitted ?? this.timeSubmitted,
          heartRateStreaming: heartRateStreaming ?? this.heartRateStreaming,
          operationInProgress: operationInProgress ?? this.operationInProgress,
          operationError: identical(operationError, _keepJwValue)
              ? this.operationError
              : operationError as String?);
}

/// Only the ten bits declared by this V101 firmware, not the broader JS layout.
class JwHealthStatus {
  final Uint8List raw;
  JwHealthStatus(Uint8List value)
      : raw = Uint8List.fromList(value).asUnmodifiableView() {
    if (raw.length != 8 ||
        raw.take(6).any((b) => b != 0) ||
        (raw[6] & 0xfc) != 0) {
      throw JwConfigurationException(
          stage: 'invalid',
          raw: raw,
          cause: 'health status length/unknown bits');
    }
  }
  int get reportedBits => ByteData.sublistView(raw).getUint64(0);
  bool _bit(int n) => reportedBits & (1 << n) != 0;
  bool get hrManualReported => _bit(0);
  bool get hrContinuousReported => _bit(1);
  bool get bpManualReported => _bit(2);
  bool get bpContinuousReported => _bit(3);
  bool get spo2ManualReported => _bit(4);
  bool get spo2ContinuousReported => _bit(5);
  bool get stressManualReported => _bit(6);
  bool get stressContinuousReported => _bit(7);
  bool get exerciseReported => _bit(8);
  bool get ecgReported => _bit(9);
}

class JwTurnOverWristStatus {
  final Uint8List raw;
  JwTurnOverWristStatus(Uint8List value)
      : raw = Uint8List.fromList(value).asUnmodifiableView() {
    if (raw.length != 1 || raw[0] > 1) {
      throw JwConfigurationException(
          stage: 'invalid', raw: raw, cause: 'wrist switch');
    }
  }
  bool get savedEnabled => raw[0] == 1;
}

int _reminderBits(Uint8List raw, String name, {bool heat = false}) {
  if (raw.length != 3) {
    throw JwConfigurationException(
        stage: 'invalid', raw: raw, cause: '$name length');
  }
  final bits = (raw[0] << 16) | (raw[1] << 8) | raw[2];
  if (((bits >> 17) & 31) > 23 ||
      ((bits >> 11) & 63) > 59 ||
      ((bits >> 6) & 31) > 23 ||
      (bits & 63) > 59 ||
      (heat && bits & 0x800000 != 0)) {
    throw JwConfigurationException(
        stage: 'invalid', raw: raw, cause: '$name time/reserved bits');
  }
  return bits;
}

class JwDisturbStatus {
  final Uint8List raw;
  final int _bits;
  JwDisturbStatus(Uint8List value)
      : raw = Uint8List.fromList(value).asUnmodifiableView(),
        _bits = _reminderBits(value, 'DND');
  bool get enabled => _bits & 0x400000 != 0;
  bool get active => _bits & 0x800000 != 0;
  int get startMinutes => ((_bits >> 17) & 31) * 60 + ((_bits >> 11) & 63);
  int get endMinutes => ((_bits >> 6) & 31) * 60 + (_bits & 63);
}

class JwHeatStressReminderStatus {
  final Uint8List raw;
  final int _bits;
  JwHeatStressReminderStatus(Uint8List value)
      : raw = Uint8List.fromList(value).asUnmodifiableView(),
        _bits = _reminderBits(value, 'heat window', heat: true);
  bool get timeWindowEnabled => _bits & 0x400000 != 0;
  int get startMinutes => ((_bits >> 17) & 31) * 60 + ((_bits >> 11) & 63);
  int get endMinutes => ((_bits >> 6) & 31) * 60 + (_bits & 63);
  bool get allDayAllowedByTimeGate =>
      !timeWindowEnabled || startMinutes == endMinutes;
}

class JwHeartRateReminderDiagnostic {
  final Uint8List raw;
  JwHeartRateReminderDiagnostic(Uint8List value)
      : raw = Uint8List.fromList(value).asUnmodifiableView() {
    if (raw.length != 2 || raw[0] > 1) {
      throw JwConfigurationException(
          stage: 'invalid', raw: raw, cause: 'high HR diagnostic');
    }
  }
  bool get reportedFlag => raw[0] == 1;
  int get threshold => raw[1];
}
