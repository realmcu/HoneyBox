import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/honey/honey_data.dart';
import 'package:ws_watch_sdk/src/honey/honey_l2.dart';
import 'package:ws_watch_sdk/src/history/honey_heart_rate_codec.dart';

void main() {
  test('decodes spec example heart rate frame', () {
    final frame = HoneyL2Message(
      command: HoneyDataCommand.command,
      version: HoneyDataCommand.version,
      key: HoneyDataCommand.keyDataHeartRate,
      value: Uint8List.fromList([
        0x05,
        0x00,
        0x02,
        0x6A,
        0xCC,
        0x9A,
        0x88,
        0x48,
        0x6A,
        0xCC,
        0x9A,
        0xC4,
        0x4B,
      ]),
    );
    final rows = HoneyHeartRateCodec.decodeDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].bpm, 0x48);
    expect(rows[1].bpm, 0x4B);
    expect(rows[0].time, 0x6ACC9A88);
  });
}
