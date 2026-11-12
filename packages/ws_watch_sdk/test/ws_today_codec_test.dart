import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/wire/ws_today_codec.dart';

void main() {
  test('decodePayload uses little-endian for step/distance fields', () {
    final payload = Uint8List.fromList([
      0x80, 0x3f, 0xf3, 0x6a, // dataTime
      0x6e, 0x14, 0x00, 0x00, // steps = 5230
      0x42, 0x0e, 0x00, 0x00, // distance = 3650
      0xc2, 0x08, 0x00, 0x00, // calories tenth-kcal
      0x48, 0x00, // active minutes
      0x48, // recent HR
      0x19, 0xd5, 0xf3, 0x6a, // recent HR time
    ]);
    final snap = WSTodayCodec.decodePayload(payload);
    expect(snap.steps, 5230);
    expect(snap.distanceMeters, 3650);
    expect(snap.caloriesTenthKcal, 2242);
    expect(snap.steps, isNot(0x6e140000));
  });
}
