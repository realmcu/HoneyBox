import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_model_protocol.dart';

void main() {
  test('builds an empty model snapshot request', () {
    expect(
      WatchModelProtocol.buildGetRequest(),
      Uint8List.fromList([0x12, 0x00, 0x01, 0x00, 0x00]),
    );
  });

  test('parses battery, charging state, and firmware version', () {
    final snapshot = WatchModelProtocol.parseSnapshot(Uint8List.fromList([
      0x12,
      0x00,
      0x02,
      0x00,
      0x09,
      0x01,
      0x03,
      87,
      0x05,
      0x31,
      0x2e,
      0x32,
      0x2e,
      0x33,
    ]));

    expect(snapshot, isNotNull);
    expect(snapshot!.batteryPercent, 87);
    expect(snapshot.batteryValid, isTrue);
    expect(snapshot.charging, isTrue);
    expect(snapshot.firmwareVersion, '1.2.3');
  });

  test('rejects malformed model snapshots', () {
    expect(
      WatchModelProtocol.parseSnapshot(
        Uint8List.fromList([0x12, 0x00, 0x02, 0x00, 0x04, 1, 1, 50, 2]),
      ),
      isNull,
    );
  });

  test('parses schema v2 canonical time and activity totals', () {
    final snapshot = WatchModelProtocol.parseSnapshot(Uint8List.fromList([
      0x12,
      0x00,
      0x02,
      0x00,
      0x19,
      0x02,
      0x07,
      88,
      0x05,
      0x68,
      0x8B,
      0x3C,
      0x00,
      0x00,
      0x00,
      0x04,
      0xD2,
      0x00,
      0x00,
      0x03,
      0x20,
      0x00,
      0x00,
      0x00,
      0x7B,
      0x31,
      0x2e,
      0x32,
      0x2e,
      0x33,
    ]));

    expect(snapshot, isNotNull);
    expect(snapshot!.steps, 1234);
    expect(snapshot.distanceMeters, 800);
    expect(snapshot.caloriesDeciKcal, 123);
    expect(snapshot.wallClock,
        DateTime.fromMillisecondsSinceEpoch(0x688B3C00 * 1000, isUtc: true));
    expect(snapshot.firmwareVersion, '1.2.3');
  });
}
