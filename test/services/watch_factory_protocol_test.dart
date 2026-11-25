import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_factory_protocol.dart';

void main() {
  test('builds the golden battery-voltage request', () {
    expect(
      WatchFactoryProtocol.buildRead(0x03),
      Uint8List.fromList([0x06, 0x00, 0x03, 0x00, 0x00]),
    );
  });

  test('builds a value request with big-endian length', () {
    expect(
      WatchFactoryProtocol.buildCommand(0x29, [1]),
      Uint8List.fromList([0x06, 0x00, 0x29, 0x00, 0x01, 0x01]),
    );
  });

  test('builds a voice-prompt test request', () {
    expect(
      WatchFactoryProtocol.buildCommand(0x2A, [0x00, 0x00]),
      Uint8List.fromList([0x06, 0x00, 0x2A, 0x00, 0x02, 0x00, 0x00]),
    );
  });

  test('parses a factory response and rejects mismatched lengths', () {
    final response = WatchFactoryProtocol.parseResponse(
      Uint8List.fromList([0x06, 0x00, 0x04, 0x00, 0x02, 0x0F, 0xA0]),
    );
    expect(response, isNotNull);
    expect(response!.key, 0x04);
    expect(response.value, Uint8List.fromList([0x0F, 0xA0]));

    expect(
      WatchFactoryProtocol.parseResponse(
        Uint8List.fromList([0x06, 0x00, 0x04, 0x00, 0x03, 0x00]),
      ),
      isNull,
    );
  });

  test('decodes the documented factory values', () {
    expect(
      WatchFactoryProtocol.decodeBatteryMillivolts(
        Uint8List.fromList([0x0B, 0xB8]),
      ),
      '3000 mV',
    );
    expect(
      WatchFactoryProtocol.decodePatchVersion(
        Uint8List.fromList([1, 2, 3, 100]),
      ),
      '1.2.3.100',
    );
    expect(
      WatchFactoryProtocol.decodeText(
        Uint8List.fromList([0x52, 0x54, 0x4C, 0x30, 0x30, 0x31]),
      ),
      'RTL001',
    );
  });
}
