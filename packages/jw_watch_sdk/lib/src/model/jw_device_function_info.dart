import 'dart:collection';
import 'dart:typed_data';

/// Individual flags in JW's eight-byte device-function report.
///
/// Names and bit positions mirror Android's `JWDeviceFunctionInfo` and
/// `DeviceFunctionHandler`. A flag describes firmware support; it does not
/// mean a setting is currently enabled.
enum JWDeviceFunction {
  musicControl,
  volumeControl,
  alarm,
  longSitReminder,
  eventReminder,
  autoLock,
  appSportRateDetect,
  baseSwitch,
  multiSport,
  stepWatch,
  countDown,
  rateReminder,
  cameraControl,
  findPhone,
  findDevice,
  lightControl,
  notifyReminder,
  screenTheme,
  turnLight,
  multiLanguage,
  hourSystem,
  unitSystem,
  ota,
  nfc,
  earPhone,
  bpDetection,
  rate,
  disturb,
  step,
  sleep,
  weChatRun,
  lightDuration,
  todayAdjust,
  sleepAdjust,
  temperature,
  bp2,
  alarm2,
  customUi,
  downloadUi,
  spo2Measure,
  modeUpgrade,
  sleepQuality2,
  sportRate2,
  rateTempPressure,
  spo2Continuous,
  ecgFunction,
  deviceStateSync,
  addressBook,
  rtkHrv,
  rtkBp3,
  bloodSugar,
  hypoxia,
  highHrv,
  sleepAll,
  deviceDateFormat,
  hideQTAndHrv,
  readiness,
  metab,
  controlDeviceSport,
  heatStress,
  pressure,
  hideHealthFunction,
  ecgBelt,
}

/// Parsed JW device-function report (`0x02/0x37`).
final class JWDeviceFunctionInfo {
  JWDeviceFunctionInfo._(Uint8List raw, Map<JWDeviceFunction, bool> values)
      : raw = Uint8List.fromList(raw).asUnmodifiableView(),
        _values = UnmodifiableMapView(values);

  /// Exactly eight bytes, in protocol order.
  final Uint8List raw;
  final Map<JWDeviceFunction, bool> _values;

  bool supports(JWDeviceFunction function) => _values[function]!;
  Map<JWDeviceFunction, bool> get values => _values;
  Iterable<JWDeviceFunction> get supported =>
      _values.entries.where((entry) => entry.value).map((entry) => entry.key);

  static JWDeviceFunctionInfo fromWire(Uint8List value) {
    if (value.length != 8) {
      throw FormatException(
          'Invalid JW device-function payload length: ${value.length}');
    }
    bool bit(int byte, int index) => (value[byte] & (1 << index)) != 0;
    return JWDeviceFunctionInfo._(value, {
      for (final entry in _bits.entries) entry.key: bit(entry.value.$1, entry.value.$2),
    });
  }

  static const _bits = <JWDeviceFunction, (int, int)>{
    JWDeviceFunction.musicControl: (0, 0),
    JWDeviceFunction.volumeControl: (0, 1),
    JWDeviceFunction.alarm: (0, 2),
    JWDeviceFunction.longSitReminder: (0, 3),
    JWDeviceFunction.eventReminder: (0, 4),
    JWDeviceFunction.autoLock: (0, 5),
    JWDeviceFunction.appSportRateDetect: (0, 6),
    JWDeviceFunction.baseSwitch: (0, 7),
    JWDeviceFunction.multiSport: (1, 0),
    JWDeviceFunction.stepWatch: (1, 1),
    JWDeviceFunction.countDown: (1, 2),
    JWDeviceFunction.rateReminder: (1, 3),
    JWDeviceFunction.cameraControl: (1, 4),
    JWDeviceFunction.findPhone: (1, 5),
    JWDeviceFunction.findDevice: (1, 6),
    JWDeviceFunction.lightControl: (1, 7),
    JWDeviceFunction.notifyReminder: (2, 0),
    JWDeviceFunction.screenTheme: (2, 1),
    JWDeviceFunction.turnLight: (2, 2),
    JWDeviceFunction.multiLanguage: (2, 3),
    JWDeviceFunction.hourSystem: (2, 4),
    JWDeviceFunction.unitSystem: (2, 5),
    JWDeviceFunction.ota: (2, 6),
    JWDeviceFunction.nfc: (2, 7),
    JWDeviceFunction.earPhone: (3, 0),
    JWDeviceFunction.bpDetection: (3, 1),
    JWDeviceFunction.rate: (3, 2),
    JWDeviceFunction.disturb: (3, 3),
    JWDeviceFunction.step: (3, 4),
    JWDeviceFunction.sleep: (3, 5),
    JWDeviceFunction.weChatRun: (3, 6),
    JWDeviceFunction.lightDuration: (3, 7),
    JWDeviceFunction.todayAdjust: (4, 7),
    JWDeviceFunction.sleepAdjust: (4, 6),
    JWDeviceFunction.temperature: (4, 5),
    JWDeviceFunction.bp2: (4, 4),
    JWDeviceFunction.alarm2: (4, 3),
    JWDeviceFunction.customUi: (4, 2),
    JWDeviceFunction.downloadUi: (4, 1),
    JWDeviceFunction.spo2Measure: (4, 0),
    JWDeviceFunction.modeUpgrade: (5, 7),
    JWDeviceFunction.sleepQuality2: (5, 6),
    JWDeviceFunction.sportRate2: (5, 5),
    JWDeviceFunction.rateTempPressure: (5, 4),
    JWDeviceFunction.spo2Continuous: (5, 3),
    JWDeviceFunction.ecgFunction: (5, 2),
    JWDeviceFunction.deviceStateSync: (5, 1),
    JWDeviceFunction.addressBook: (5, 0),
    JWDeviceFunction.rtkHrv: (6, 7),
    JWDeviceFunction.rtkBp3: (6, 6),
    JWDeviceFunction.bloodSugar: (6, 5),
    JWDeviceFunction.hypoxia: (6, 4),
    JWDeviceFunction.highHrv: (6, 3),
    JWDeviceFunction.sleepAll: (6, 2),
    JWDeviceFunction.deviceDateFormat: (6, 1),
    JWDeviceFunction.hideQTAndHrv: (6, 0),
    JWDeviceFunction.readiness: (7, 0),
    JWDeviceFunction.metab: (7, 2),
    JWDeviceFunction.controlDeviceSport: (7, 3),
    JWDeviceFunction.heatStress: (7, 4),
    JWDeviceFunction.pressure: (7, 5),
    JWDeviceFunction.hideHealthFunction: (7, 6),
    JWDeviceFunction.ecgBelt: (7, 7),
  };
}
