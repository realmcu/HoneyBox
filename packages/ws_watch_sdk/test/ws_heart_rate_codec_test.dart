import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/wire/ws_data_command.dart';
import 'package:ws_watch_sdk/src/wire/ws_l2_message.dart';
import 'package:ws_watch_sdk/src/history/ws_heart_rate_codec.dart';

void main() {
  test('decodes spec example heart rate frame', () {
    final frame = WSL2Message(
      command: WSDataCommand.command,
      version: WSDataCommand.version,
      key: WSDataCommand.keyDataHeartRate,
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
    final rows = WSHeartRateCodec.decodeDataFrame(frame);
    expect(rows.length, 2);
    expect(rows[0].bpm, 0x48);
    expect(rows[1].bpm, 0x4B);
    expect(rows[0].time, 0x889ACC6A);
  });
}
