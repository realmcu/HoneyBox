import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/protocol/cmd_02_settings.dart';
import 'package:ws_watch_sdk/src/protocol/message.dart';

void main() {
  test('wall-clock vector is calendar time without timezone conversion', () {
    final time =
        WSWallClock(year: 2026, month: 10, day: 10, hour: 16, minute: 52);
    expect(time.encode(), [0x6a, 0xca, 0x6d, 0x30]);
    expect(WSWallClock.fromBytes(time.encode()), time);
    expect(WSWallClock.fromCalendar(DateTime(2026, 10, 10, 16, 52)), time);
    expect(WSWallClock.fromCalendar(DateTime.utc(2026, 10, 10, 16, 52)), time);
    expect(
        WSMessage(WSSettingsProtocol.setTime.request.address, time.encode())
            .encode(),
        [2, 0, 1, 0, 5, 0, 0x6a, 0xca, 0x6d, 0x30]);
    expect(WSWallClock.fromSeconds(0).toString(), '1970-01-01 00:00:00');
    expect(WSWallClock.fromSeconds(0xffffffff).encode(), [255, 255, 255, 255]);
  });
  test(
      'calendar normalization, out-of-range seconds and malformed time rejected',
      () {
    for (final build in <void Function()>[
      () => WSWallClock(year: 2026, month: 2, day: 29),
      () => WSWallClock(year: 2024, month: 2, day: 30),
      () => WSWallClock(year: 2026, month: 13, day: 1),
      () => WSWallClock(year: 2026, month: 1, day: 0),
      () => WSWallClock(year: 2026, month: 1, day: 1, hour: 24),
      () => WSWallClock(year: 2026, month: 1, day: 1, minute: 60),
      () => WSWallClock(year: 2026, month: 1, day: 1, second: 60),
      () => WSWallClock(
          year: 1969, month: 12, day: 31, hour: 23, minute: 59, second: 59),
      () => WSWallClock.fromSeconds(0x100000000),
    ]) {
      expect(build, throwsArgumentError);
    }
    expect(WSWallClock(year: 2024, month: 2, day: 29).day, 29);
    expect(() => WSWallClock.fromBytes([0, 0, 0]), throwsFormatException);
  });
  test('language appendix and unknown byte values', () {
    expect(WSLanguage.knownValues, hasLength(103));
    expect(WSLanguage(0), WSLanguage.english);
    expect(WSLanguage(0x12).label, '德语');
    expect(WSLanguage(0x66).label, '越南语');
    for (final code in [0x67, 255]) {
      expect(WSLanguage(code).isKnown, isFalse);
      expect(WSLanguage(code).code, code);
    }
    expect(() => WSLanguage(256), throwsRangeError);
    expect(() => WSHourSystem(-1), throwsRangeError);
  });
  test('display vector, copy and unknown fields survive unchanged', () {
    final format = WSDisplayFormat(hourSystem: WSHourSystem.twelveHour);
    expect(
        WSMessage(
                WSSettingsProtocol.setDisplayFormat.request.address, format.raw)
            .encode(),
        [2, 0, 4, 0, 5, 0, 1, 0, 0, 0]);
    final unknown = WSDisplayFormat.fromBytes([1, 0xfe, 0xfd, 0xfc]);
    final modified = unknown.copyWith(hourSystem: WSHourSystem.twentyFourHour);
    expect(modified.raw, [0, 0xfe, 0xfd, 0xfc]);
    expect(modified.dateFormat.isKnown, isFalse);
    expect(modified, WSDisplayFormat.fromBytes(modified.raw));
    expect(() => modified.raw[0] = 1, throwsUnsupportedError);
    expect(() => WSDisplayFormat.fromBytes([0, 0, 0]), throwsFormatException);
    expect(() => WSDisplayFormat.fromBytes([0, 0, 0, 0, 1]),
        throwsFormatException);
    expect(
        () => WSDisplayFormat.fromBytes([256, 0, 0, 0]), throwsFormatException);
  });
}
