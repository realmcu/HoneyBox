import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_time_protocol.dart';

void main() {
  group('WatchTimeProtocol', () {
    test('builds an exact big-endian time settings frame', () {
      final frame = WatchTimeProtocol.buildSetTime(
        DateTime(2024, 7, 27, 15, 42, 36),
      );

      expect(
        frame,
        [0x02, 0x00, 0x01, 0x00, 0x04, 0x61, 0xF6, 0xFA, 0xA4],
      );
    });

    test('supports the lower and upper protocol years', () {
      final lower = WatchTimeProtocol.buildSetTime(DateTime(2000, 1, 1));
      final upper = WatchTimeProtocol.buildSetTime(
        DateTime(2063, 12, 31, 23, 59, 59),
      );

      expect(lower.sublist(5), [0x00, 0x42, 0x00, 0x00]);
      expect(upper.sublist(5), [0xFF, 0x3F, 0x7E, 0xFB]);
    });

    test('rejects years outside the protocol range', () {
      expect(
        () => WatchTimeProtocol.buildSetTime(DateTime(1999, 12, 31)),
        throwsArgumentError,
      );
      expect(
        () => WatchTimeProtocol.buildSetTime(DateTime(2064, 1, 1)),
        throwsArgumentError,
      );
    });
  });
}
