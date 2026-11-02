/// Wire values retain unknown byte codes for forward compatibility.
abstract class WSByteValue {
  WSByteValue(this.code) {
    RangeError.checkValueInInterval(code, 0, 255, 'code');
  }
  final int code;
  String get label;
  bool get isKnown;
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is WSByteValue &&
      other.code == code;
  @override
  int get hashCode => Object.hash(runtimeType, code);
  @override
  String toString() => '$label (0x${code.toRadixString(16).padLeft(2, '0')})';
}

class WSHourSystem extends WSByteValue {
  WSHourSystem(super.code);
  static final twentyFourHour = WSHourSystem(0);
  static final twelveHour = WSHourSystem(1);
  static final List<WSHourSystem> knownValues =
      List.unmodifiable([twentyFourHour, twelveHour]);
  @override
  bool get isKnown => code < 2;
  @override
  String get label => isKnown ? const ['24 小时制', '12 小时制'][code] : '未知';
}

class WSDateFormat extends WSByteValue {
  WSDateFormat(super.code);
  static final monthDay = WSDateFormat(0);
  static final dayMonth = WSDateFormat(1);
  static final List<WSDateFormat> knownValues =
      List.unmodifiable([monthDay, dayMonth]);
  @override
  bool get isKnown => code < 2;
  @override
  String get label => isKnown ? const ['MM-DD', 'DD-MM'][code] : '未知';
}

class WSDistanceUnit extends WSByteValue {
  WSDistanceUnit(super.code);
  static final metric = WSDistanceUnit(0);
  static final imperial = WSDistanceUnit(1);
  static final List<WSDistanceUnit> knownValues =
      List.unmodifiable([metric, imperial]);
  @override
  bool get isKnown => code < 2;
  @override
  String get label => isKnown ? const ['公制', '英制'][code] : '未知';
}

class WSWeightUnit extends WSByteValue {
  WSWeightUnit(super.code);
  static final kilograms = WSWeightUnit(0);
  static final pounds = WSWeightUnit(1);
  static final List<WSWeightUnit> knownValues =
      List.unmodifiable([kilograms, pounds]);
  @override
  bool get isKnown => code < 2;
  @override
  String get label => isKnown ? const ['千克', '磅'][code] : '未知';
}
