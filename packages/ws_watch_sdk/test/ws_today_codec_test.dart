import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/wire/ws_today_codec.dart';

void main() {
  test('decodePayload uses protocol big-endian fields', () {
    final payload = Uint8List.fromList([
      0x6a, 0xf3, 0x3f, 0x80, // dataTime
      0x00, 0x00, 0x14, 0x6e, // steps = 5230
      0x00, 0x00, 0x0e, 0x42, // distance = 3650
      0x00, 0x00, 0x08, 0xc2, // calories tenth-kcal
      0x00, 0x48, // active minutes
      0x48, // recent HR
      0x6a, 0xf3, 0xd5, 0x19, // recent HR time
    ]);
    final snap = WSTodayCodec.decodePayload(payload);
    expect(snap.steps, 5230);
    expect(snap.distanceMeters, 3650);
    expect(snap.caloriesTenthKcal, 2242);
    expect(snap.steps, isNot(0x6e140000));
  });
}
