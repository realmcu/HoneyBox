import 'dart:typed_data';

import 'package:ebadge_app/services/l1_engine.dart';
import 'package:ebadge_app/services/l2_file_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

// CRC-16/CCITT-FALSE over the L2 payload only (PROTOCOL.md §2.1).
int crc16ForTest(List<int> data) {
  int crc = 0xFFFF;
  for (final byte in data) {
    crc ^= (byte << 8) & 0xFFFF;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0
          ? (((crc << 1) ^ 0x1021) & 0xFFFF)
          : ((crc << 1) & 0xFFFF);
    }
  }
  return crc & 0xFFFF;
}

Uint8List l1FrameForTest(int ctrl, int seq, List<int> payload) {
  final crc = crc16ForTest(payload); // payload only, no header
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
  test('sendL2 builds CRC-16/CCITT-FALSE over the L2 payload only', () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    final seq = engine.sendL2(Uint8List.fromList([0x0B, 0x00, 0x01]));

    expect(seq, 0);
    expect(writes, l1FrameForTest(0x00, 0, [0x0B, 0x00, 0x01]));
  });

  test('sendL2 matches PROTOCOL.md BEGIN_REQ example bytes (crc=0xD69B)', () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    // PROTOCOL.md §5 example ①: BEGIN_REQ L2 payload (18 bytes), seq=0.
    const payload = <int>[
      0x10, 0x00, 0x01, 0x00, 0x0d, 0x01, 0x00, 0x00, 0x27, 0x10, //
      0x08, 0x00, 0x05, 0x61, 0x2e, 0x70, 0x6e, 0x67,
    ];
    engine.sendL2(Uint8List.fromList(payload));

    expect(writes, [
      0xab, 0x00, 0x00, 0x12, 0xd6, 0x9b, 0x00, 0x00, //
      ...payload,
    ]);
  });

  test('data frame receive sends ACK (empty payload → CRC 0xFFFF)', () {
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
