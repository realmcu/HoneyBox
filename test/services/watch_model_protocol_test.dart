import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_model_protocol.dart';

void main() {
  test('builds the golden device-info read request', () {
    expect(
      WatchModelProtocol.buildGetRequest(),
      Uint8List.fromList([0x02, 0x00, 0x30, 0x00, 0x01, 0x01]),
    );
  });

  test('parses device information and firmware version', () {
    final value = Uint8List.fromList([
      0x02,
      0x00,
      0x01,
      0x01,
      0x02,
      0x03,
      0x00,
      0x64,
      0x01,
      0x01,
      0x01,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x02,
      0x41,
      0x42,
    ]);
    final frame = Uint8List.fromList([
      0x02,
      0x00,
      0x30,
      value.length >> 8,
      value.length & 0xFF,
      ...value,
    ]);

    final snapshot = WatchModelProtocol.parseSnapshot(frame);

    expect(snapshot, isNotNull);
    expect(snapshot!.firmwareVersion, '1.2.3');
    expect(snapshot.batteryValid, isFalse);
    expect(WatchModelProtocol.decodeSerial(frame), 'AB');
  });

  test('rejects invalid device-info responses', () {
    expect(
      WatchModelProtocol.parseSnapshot(
        Uint8List.fromList([0x12, 0x00, 0x02, 0x00, 0x04, 1, 1, 50, 2]),
      ),
      isNull,
    );
    expect(
      WatchModelProtocol.parseSnapshot(
        Uint8List.fromList([
          0x02,
          0x00,
          0x30,
          0x00,
          0x12,
          ...List<int>.filled(18, 0),
        ]),
      ),
      isNull,
    );
  });
}
