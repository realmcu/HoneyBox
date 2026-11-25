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

  test('decodes stop reasons', () {
    expect(
      WatchRecordProtocol.decodeStop(Uint8List.fromList([0x04])),
      '手表拒绝录音请求',
    );
  });
}
