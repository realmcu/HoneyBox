import 'dart:typed_data';

/// Device-local calendar fields with no timezone or absolute-instant conversion.
class WSWallClock {
  WSWallClock(
      {required this.year,
      required this.month,
      required this.day,
      this.hour = 0,
      this.minute = 0,
      this.second = 0}) {
    final calendar = DateTime.utc(year, month, day, hour, minute, second);
    if (calendar.year != year ||
        calendar.month != month ||
        calendar.day != day ||
        calendar.hour != hour ||
        calendar.minute != minute ||
        calendar.second != second) {
      throw ArgumentError('invalid wall-clock calendar fields');
    }
    RangeError.checkValueInInterval(seconds, 0, 0xffffffff, 'wallClockSeconds');
  }

  /// Copies the supplied calendar fields, regardless of DateTime.isUtc.
  factory WSWallClock.fromCalendar(DateTime calendar) => WSWallClock(
      year: calendar.year,
      month: calendar.month,
      day: calendar.day,
      hour: calendar.hour,
      minute: calendar.minute,
      second: calendar.second);
  factory WSWallClock.fromSeconds(int seconds) {
    RangeError.checkValueInInterval(seconds, 0, 0xffffffff, 'wallClockSeconds');
    return WSWallClock.fromCalendar(
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true));
  }
  factory WSWallClock.fromBytes(List<int> bytes) {
    if (bytes.length != 4 || bytes.any((b) => b < 0 || b > 255)) {
      throw const FormatException('wall clock requires four bytes');
    }
    return WSWallClock.fromSeconds(
        ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(0));
  }
  final int year, month, day, hour, minute, second;
  int get seconds =>
      DateTime.utc(year, month, day, hour, minute, second)
          .millisecondsSinceEpoch ~/
      1000;
  Uint8List encode() =>
      (ByteData(4)..setUint32(0, seconds)).buffer.asUint8List();
  @override
  bool operator ==(Object other) =>
      other is WSWallClock && seconds == other.seconds;
  @override
  int get hashCode => seconds.hashCode;
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
}
