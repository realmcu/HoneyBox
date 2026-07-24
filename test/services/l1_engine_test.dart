import 'dart:typed_data';

import 'package:honeybox/services/l1_engine.dart';
import 'package:honeybox/services/l2_file_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

// CRC-16/ARC (poly 0xA001 reflected, init 0) over the L2 payload only
// (PROTOCOL.md §2.1).
int crc16ForTest(List<int> data) {
  int crc = 0x0000;
  for (final byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? ((crc >> 1) ^ 0xA001) : (crc >> 1);
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
  test('sendL2 builds CRC-16/ARC over the L2 payload only', () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    final seq = engine.sendL2(Uint8List.fromList([0x0B, 0x00, 0x01]));

    expect(seq, 0);
    expect(writes, l1FrameForTest(0x00, 0, [0x0B, 0x00, 0x01]));
  });

  test('sendL2 matches PROTOCOL.md BEGIN_REQ example bytes (crc=0x2B6F)', () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    // PROTOCOL.md §5 example ①: BEGIN_REQ L2 payload (18 bytes), seq=0.
    const payload = <int>[
      0x10, 0x00, 0x01, 0x00, 0x0d, 0x01, 0x00, 0x00, 0x27, 0x10, //
      0x08, 0x00, 0x05, 0x61, 0x2e, 0x70, 0x6e, 0x67,
    ];
    engine.sendL2(Uint8List.fromList(payload));

    expect(writes, [
      0xab, 0x00, 0x00, 0x12, 0x2b, 0x6f, 0x00, 0x00, //
      ...payload,
    ]);
  });

  test('data frame receive sends ACK (empty payload → CRC 0x0000)', () {
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));

    engine.onNotified(
        l1FrameForTest(0x00, 0x1234, [0x0B, 0x00, 0x06, 0x00, 0x00]));

    expect(writes, l1FrameForTest(0x10, 0x1234, const []));
  });

  test('attach resets the L1 seq to 0 so each transfer starts at seq=0', () {
    // PROTOCOL.md §三: every transfer's BEGIN_REQ goes out as L1[seq=0], and the
    // desk-mate reference host resets seq on each attach(). This is what lets a
    // SECOND transfer succeed after a first one has advanced the counter.
    final engine = L1Engine(writeFn: (_) {});
    engine.sendL2(Uint8List.fromList([1])); // advance seq → 1
    expect(engine.currentSeq, 1);
    final session = FileTransferSession(sendL2: engine.sendL2);

    engine.attach(session);

    expect(engine.currentSeq, 0);
  });

  test('attach clears stale RX bytes from a prior transfer', () {
    // A leftover partial frame from a previous transfer must not corrupt the
    // parse of the new session's responses (desk-mate attach() clears _rx_buf).
    final writes = <int>[];
    final engine = L1Engine(writeFn: (chunk) => writes.addAll(chunk));
    // Feed an incomplete frame (header claims 5 payload bytes, none delivered).
    engine.onNotified(Uint8List.fromList([0xAB, 0x00, 0x00, 0x05, 0x00, 0x00]));

    engine.attach(FileTransferSession(sendL2: engine.sendL2));
    // A fresh, complete inbound data frame should now ACK cleanly at seq=7.
    engine.onNotified(l1FrameForTest(0x00, 7, [0x0B, 0x00, 0x06, 0x00, 0x00]));

    expect(writes, l1FrameForTest(0x10, 7, const []));
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
