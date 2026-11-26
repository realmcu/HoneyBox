import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_record_protocol.dart';

void main() {
  test('builds RECORD_REQ and CANCEL_REQ frames', () {
    expect(
      WatchRecordProtocol.buildRequest(),
      Uint8List.fromList([0x14, 0x00, 0x05, 0x00, 0x00]),
    );
    expect(
      WatchRecordProtocol.buildCancelRequest(),
      Uint8List.fromList([0x14, 0x00, 0x04, 0x00, 0x00]),
    );
  });

  test('parses record START and rejects malformed frames', () {
    final response = WatchRecordProtocol.parseResponse(
      Uint8List.fromList([
        0x14,
        0x00,
        0x01,
        0x00,
        0x0A,
        0x01,
        0x00,
        0x00,
        0x3E,
        0x80,
        0x01,
        0x14,
        0x3E,
        0x80,
        0x04,
      ]),
    );
    expect(response, isNotNull);
    expect(response!.key, WatchRecordProtocol.startKey);
    expect(
      WatchRecordProtocol.decodeStart(response.value),
      contains('16000 Hz'),
    );

    expect(
      WatchRecordProtocol.parseResponse(
        Uint8List.fromList([0x14, 0x00, 0x01, 0x00, 0x02, 0x01]),
      ),
      isNull,
    );
  });

  test('decodes PCM START and parses PCM DATA', () {
    final start = WatchRecordProtocol.parseResponse(Uint8List.fromList([
      0x14, 0x00, 0x01, 0x00, 0x0D,
      0x02, 0x00, 0x00, 0x3E, 0x80, 0x01, 0x0F, 0x00, 0x00, 0x01,
      0x10, 0x01, 0xE0,
    ]))!;
    expect(WatchRecordProtocol.decodeStart(start.value), contains('PCM 16000 Hz'));
    expect(WatchRecordProtocol.decodeStart(start.value), contains('480 B/帧'));

    final response = WatchRecordProtocol.parseResponse(Uint8List.fromList([
      0x14, 0x00, 0x02, 0x00, 0x0E,
      0x00, 0x07, 0x00, 0x00, 0x00, 0x69, 0x01, 0x00,
      0x00, 0x04, 0x01, 0x02, 0x03, 0x04,
    ]))!;
    final data = WatchRecordProtocol.parseData(response)!;
    expect(data.seq, 7);
    expect(data.timestamp, 105);
    expect(data.frames.single, Uint8List.fromList([1, 2, 3, 4]));
    expect(data.byteLength, 4);
  });

  test('decodes stop reasons', () {
    expect(
      WatchRecordProtocol.decodeStop(Uint8List.fromList([0x04])),
      '手表拒绝录音请求',
    );
  });
}
