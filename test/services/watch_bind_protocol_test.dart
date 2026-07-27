import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_bind_protocol.dart';

void main() {
  group('WatchBindProtocol', () {
    test('builds a bind request with a 32-byte user ID', () {
      final userId = Uint8List.fromList(List<int>.generate(32, (i) => i));

      final frame = WatchBindProtocol.buildRequest(userId);

      expect(frame.sublist(0, 5), [0x03, 0x00, 0x01, 0x00, 0x20]);
      expect(frame.sublist(5), userId);
      expect(frame, hasLength(37));
    });

    test('rejects a user ID that is not exactly 32 bytes', () {
      expect(
        () => WatchBindProtocol.buildRequest(Uint8List(31)),
        throwsArgumentError,
      );
      expect(
        () => WatchBindProtocol.buildRequest(Uint8List(33)),
        throwsArgumentError,
      );
    });

    test('parses success and failure bind responses', () {
      expect(
        WatchBindProtocol.parseResponse(
          Uint8List.fromList([0x03, 0x00, 0x02, 0x00, 0x01, 0x00]),
        ),
        WatchBindResult.success,
      );
      expect(
        WatchBindProtocol.parseResponse(
          Uint8List.fromList([0x03, 0x00, 0x02, 0x00, 0x01, 0x01]),
        ),
        WatchBindResult.failed,
      );
    });

    test('ignores unrelated and malformed responses', () {
      final frames = [
        [0x02, 0x00, 0x02, 0x00, 0x01, 0x00],
        [0x03, 0x00, 0x01, 0x00, 0x01, 0x00],
        [0x03, 0x00, 0x02, 0x00, 0x02, 0x00],
        [0x03, 0x00, 0x02, 0x00, 0x01],
        [0x03, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00],
      ];

      for (final frame in frames) {
        expect(
          WatchBindProtocol.parseResponse(Uint8List.fromList(frame)),
          isNull,
          reason: 'Unexpectedly parsed $frame',
        );
      }
    });

    test('generates a 32-byte user ID', () {
      expect(WatchBindProtocol.generateUserId(), hasLength(32));
    });
  });
}
