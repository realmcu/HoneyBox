import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_time_protocol.dart';

void main() {
  group('WatchTimeProtocol', () {
    test('builds an exact big-endian wall clock seconds frame', () {
      // (2024, 7, 27, 15, 42, 36) => calendar.timegm(...) = 1722094956
      // 1722094956 = 0x66A5156C
      final frame = WatchTimeProtocol.buildSetTime(
        DateTime(2024, 7, 27, 15, 42, 36),
      );

      expect(
        frame,
        [0x02, 0x00, 0x01, 0x00, 0x04, 0x66, 0xA5, 0x15, 0x6C],
      );
    });

    test('year 2000 encodes correctly', () {
      // (2000, 1, 1, 0, 0, 0) => 946684800 = 0x386D4380
      final frame = WatchTimeProtocol.buildSetTime(DateTime(2000, 1, 1));
      expect(frame.sublist(5), [0x38, 0x6D, 0x43, 0x80]);
    });

    test('year 2063 encodes correctly', () {
      // (2063, 12, 31, 23, 59, 59) => 2966371199 = 0xB0CF3B7F
      final frame = WatchTimeProtocol.buildSetTime(
        DateTime(2063, 12, 31, 23, 59, 59),
      );
      expect(frame.sublist(5), [0xB0, 0xCF, 0x3B, 0x7F]);
    });

    test('supports the maximum unsigned 32-bit timestamp', () {
      final frame = WatchTimeProtocol.buildSetTime(
        DateTime(2106, 2, 7, 6, 28, 15),
      );

      expect(frame.sublist(5), [0xFF, 0xFF, 0xFF, 0xFF]);
    });

    test('rejects timestamps beyond the unsigned 32-bit range', () {
      expect(
        () => WatchTimeProtocol.buildSetTime(
          DateTime(2106, 2, 7, 6, 28, 16),
        ),
        throwsArgumentError,
      );
      expect(
        () => WatchTimeProtocol.buildSetTime(
          DateTime(2106, 12, 31, 23, 59, 59),
        ),
        throwsArgumentError,
      );
    });

    test('rejects years outside the protocol range', () {
      expect(
        () => WatchTimeProtocol.buildSetTime(DateTime(1969, 12, 31)),
        throwsArgumentError,
      );
      expect(
        () => WatchTimeProtocol.buildSetTime(DateTime(2107, 1, 1)),
        throwsArgumentError,
      );
    });
  });
}
