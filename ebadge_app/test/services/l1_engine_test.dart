import 'dart:typed_data';

import 'package:ebadge_app/services/l1_engine.dart';
import 'package:ebadge_app/services/l2_file_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

int crc16ForTest(List<int> data) {
  int crc = 0;
  for (final byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? ((crc >> 1) ^ 0x8408) : (crc >> 1);
    }
  }
  return crc & 0xFFFF;
}

Uint8List l1FrameForTest(int ctrl, int seq, List<int> payload) {
  final crcInput = <int>[
    0xAB,
    ctrl,
    payload.length >> 8,
    payload.length & 0xFF,
    ...payload
  ];
  final crc = crc16ForTest(crcInput);
  return Uint8List.fromList([
    0xAB,
    ctrl,
    payload.length >> 8,
    payload.length & 0xFF,
    crc >> 8,
    crc & 0xFF,
    seq >> 8,
    seq & 0xFF,
    ...payload,
  ]);
}

void main() {
  test('sendL2 builds CRC over magic, control, length, and payload', () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    final seq = engine.sendL2(Uint8List.fromList([0x0B, 0x00, 0x01]));

    expect(seq, 0);
    expect(writes, l1FrameForTest(0x00, 0, [0x0B, 0x00, 0x01]));
  });

  test('data frame receive sends ACK whose CRC includes magic and ack control',
      () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    engine.onNotified(
        l1FrameForTest(0x00, 0x1234, [0x0B, 0x00, 0x06, 0x00, 0x00]));

    expect(writes, l1FrameForTest(0x10, 0x1234, const []));
  });

  test('attach does not reset connection-level sequence number', () {
    final engine = L1Engine(writeFn: (_) {});
    engine.sendL2(Uint8List.fromList([1]));
    final session = FileTransferSession(sendL2: engine.sendL2);

    engine.attach(session);

    expect(engine.currentSeq, 1);
  });

  test('malformed oversized frame header does not block later valid frames',
      () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    engine.onNotified(Uint8List.fromList([0xAB, 0x00, 0xFF, 0xFF, 0x00]));
    engine.onNotified(l1FrameForTest(0x00, 2, [0x0B, 0x00, 0x06, 0x00, 0x00]));

    expect(writes, l1FrameForTest(0x10, 2, const []));
  });
}
