import 'dart:typed_data';
import 'setting_values.dart';

class WSDisplayFormat {
  WSDisplayFormat(
      {WSHourSystem? hourSystem,
      WSDateFormat? dateFormat,
      WSDistanceUnit? distanceUnit,
      WSWeightUnit? weightUnit})
      : hourSystem = hourSystem ?? WSHourSystem.twentyFourHour,
        dateFormat = dateFormat ?? WSDateFormat.monthDay,
        distanceUnit = distanceUnit ?? WSDistanceUnit.metric,
        weightUnit = weightUnit ?? WSWeightUnit.kilograms;
  factory WSDisplayFormat.fromBytes(List<int> bytes) {
    if (bytes.length != 4 || bytes.any((b) => b < 0 || b > 255)) {
      throw const FormatException('display format requires exactly four bytes');
    }
    return WSDisplayFormat(
        hourSystem: WSHourSystem(bytes[0]),
        dateFormat: WSDateFormat(bytes[1]),
        distanceUnit: WSDistanceUnit(bytes[2]),
        weightUnit: WSWeightUnit(bytes[3]));
  }
  final WSHourSystem hourSystem;
  final WSDateFormat dateFormat;
  final WSDistanceUnit distanceUnit;
  final WSWeightUnit weightUnit;
  Uint8List get raw => Uint8List.fromList([
        hourSystem.code,
        dateFormat.code,
        distanceUnit.code,
        weightUnit.code
      ]).asUnmodifiableView();
  WSDisplayFormat copyWith(
          {WSHourSystem? hourSystem,
          WSDateFormat? dateFormat,
          WSDistanceUnit? distanceUnit,
          WSWeightUnit? weightUnit}) =>
      WSDisplayFormat(
          hourSystem: hourSystem ?? this.hourSystem,
          dateFormat: dateFormat ?? this.dateFormat,
          distanceUnit: distanceUnit ?? this.distanceUnit,
          weightUnit: weightUnit ?? this.weightUnit);
  @override
  bool operator ==(Object other) =>
      other is WSDisplayFormat &&
      hourSystem == other.hourSystem &&
      dateFormat == other.dateFormat &&
      distanceUnit == other.distanceUnit &&
      weightUnit == other.weightUnit;
  @override
  int get hashCode =>
      Object.hash(hourSystem, dateFormat, distanceUnit, weightUnit);
  @override
  String toString() =>
      '${hourSystem.label} / ${dateFormat.label} / ${distanceUnit.label} / ${weightUnit.label}';
}
