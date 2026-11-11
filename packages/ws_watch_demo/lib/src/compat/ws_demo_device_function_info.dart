import 'dart:collection';
import 'dart:typed_data';

/// Individual flags in JW's eight-byte device-function report.
///
/// Names and bit positions mirror Android's `WSDeviceFunctionInfo` and
/// `DeviceFunctionHandler`. A flag describes firmware support; it does not
/// mean a setting is currently enabled.
enum WSDeviceFunction {
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
final class WSDeviceFunctionInfo {
  WSDeviceFunctionInfo._(Uint8List raw, Map<WSDeviceFunction, bool> values)
      : raw = Uint8List.fromList(raw).asUnmodifiableView(),
        _values = UnmodifiableMapView(values);

  /// Exactly eight bytes, in protocol order.
  final Uint8List raw;
  final Map<WSDeviceFunction, bool> _values;

  bool supports(WSDeviceFunction function) => _values[function]!;
  Map<WSDeviceFunction, bool> get values => _values;
  Iterable<WSDeviceFunction> get supported =>
      _values.entries.where((entry) => entry.value).map((entry) => entry.key);


  static WSDeviceFunctionInfo demoAllSupported() {
    final raw = Uint8List(8)..fillRange(0, 8, 0xFF);
    return fromWire(raw);
  }

  static WSDeviceFunctionInfo fromWire(Uint8List value) {
    if (value.length != 8) {
      throw FormatException(
          'Invalid JW device-function payload length: ${value.length}');
    }
    bool bit(int byte, int index) => (value[byte] & (1 << index)) != 0;
    return WSDeviceFunctionInfo._(value, {
      for (final entry in _bits.entries)
        entry.key: bit(entry.value.$1, entry.value.$2),
    });
  }

  static const _bits = <WSDeviceFunction, (int, int)>{
    WSDeviceFunction.musicControl: (0, 0),
    WSDeviceFunction.volumeControl: (0, 1),
    WSDeviceFunction.alarm: (0, 2),
    WSDeviceFunction.longSitReminder: (0, 3),
    WSDeviceFunction.eventReminder: (0, 4),
    WSDeviceFunction.autoLock: (0, 5),
    WSDeviceFunction.appSportRateDetect: (0, 6),
    WSDeviceFunction.baseSwitch: (0, 7),
    WSDeviceFunction.multiSport: (1, 0),
    WSDeviceFunction.stepWatch: (1, 1),
    WSDeviceFunction.countDown: (1, 2),
    WSDeviceFunction.rateReminder: (1, 3),
    WSDeviceFunction.cameraControl: (1, 4),
    WSDeviceFunction.findPhone: (1, 5),
    WSDeviceFunction.findDevice: (1, 6),
    WSDeviceFunction.lightControl: (1, 7),
    WSDeviceFunction.notifyReminder: (2, 0),
    WSDeviceFunction.screenTheme: (2, 1),
    WSDeviceFunction.turnLight: (2, 2),
    WSDeviceFunction.multiLanguage: (2, 3),
    WSDeviceFunction.hourSystem: (2, 4),
    WSDeviceFunction.unitSystem: (2, 5),
    WSDeviceFunction.ota: (2, 6),
    WSDeviceFunction.nfc: (2, 7),
    WSDeviceFunction.earPhone: (3, 0),
    WSDeviceFunction.bpDetection: (3, 1),
    WSDeviceFunction.rate: (3, 2),
    WSDeviceFunction.disturb: (3, 3),
    WSDeviceFunction.step: (3, 4),
    WSDeviceFunction.sleep: (3, 5),
    WSDeviceFunction.weChatRun: (3, 6),
    WSDeviceFunction.lightDuration: (3, 7),
    WSDeviceFunction.todayAdjust: (4, 7),
    WSDeviceFunction.sleepAdjust: (4, 6),
    WSDeviceFunction.temperature: (4, 5),
    WSDeviceFunction.bp2: (4, 4),
    WSDeviceFunction.alarm2: (4, 3),
    WSDeviceFunction.customUi: (4, 2),
    WSDeviceFunction.downloadUi: (4, 1),
    WSDeviceFunction.spo2Measure: (4, 0),
    WSDeviceFunction.modeUpgrade: (5, 7),
    WSDeviceFunction.sleepQuality2: (5, 6),
    WSDeviceFunction.sportRate2: (5, 5),
    WSDeviceFunction.rateTempPressure: (5, 4),
    WSDeviceFunction.spo2Continuous: (5, 3),
    WSDeviceFunction.ecgFunction: (5, 2),
    WSDeviceFunction.deviceStateSync: (5, 1),
    WSDeviceFunction.addressBook: (5, 0),
    WSDeviceFunction.rtkHrv: (6, 7),
    WSDeviceFunction.rtkBp3: (6, 6),
    WSDeviceFunction.bloodSugar: (6, 5),
    WSDeviceFunction.hypoxia: (6, 4),
    WSDeviceFunction.highHrv: (6, 3),
    WSDeviceFunction.sleepAll: (6, 2),
    WSDeviceFunction.deviceDateFormat: (6, 1),
    WSDeviceFunction.hideQTAndHrv: (6, 0),
    WSDeviceFunction.readiness: (7, 0),
    WSDeviceFunction.metab: (7, 2),
    WSDeviceFunction.controlDeviceSport: (7, 3),
    WSDeviceFunction.heatStress: (7, 4),
    WSDeviceFunction.pressure: (7, 5),
    WSDeviceFunction.hideHealthFunction: (7, 6),
    WSDeviceFunction.ecgBelt: (7, 7),
  };
}
