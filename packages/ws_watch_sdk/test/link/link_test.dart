import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/link/frame.dart';
import 'package:ws_watch_sdk/src/link/frame_log.dart';
import 'package:ws_watch_sdk/src/link/frame_assembler.dart';
import 'package:ws_watch_sdk/src/link/link.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import '../sim/test_transport.dart';

const quick = WSLinkConfig(
    ackTimeout: Duration(milliseconds: 25),
    chunkWriteTimeout: Duration(milliseconds: 25),
    rxAssembleTimeout: Duration(milliseconds: 25),
    maxRetries: 1);
void main() {
  test('assembler handles noise, concatenation and every split boundary', () {
    final raw = WSFrame(seq: 9, payload: List.generate(64, (i) => i)).encode();
    for (var split = 1; split < raw.length; split++) {
      final frames = <WSFrame>[];
      final assembler = WSFrameAssembler(
          timeout: const Duration(seconds: 1),
          maxPayloadLength: 65535,
          onFrame: (f, _) => frames.add(f),
          onError: (_, __, ___) => fail('bad frame'));
      assembler.add(Uint8List.fromList([0, 1, ...raw.sublist(0, split)]));
      expect(frames, isEmpty);
      assembler.add(Uint8List.fromList([...raw.sublist(split), ...raw]));
      expect(frames.map((f) => f.seq), [9, 9]);
      expect(assembler.bufferedBytes, 0);
      assembler.dispose();
    }
  });
  test(
      'header validation rejects unsupported flags, oversized frames and malformed ACKs',
      () {
    for (final flag in [1, 0x20, 0x40, 0xff]) {
      expect(WSFrame.validHeader([0xab, flag, 0, 0, 0, 0, 0, 1], 64), isFalse);
    }
    expect(WSFrame.validHeader([0xab, 0x10, 0, 1, 0, 0, 0, 1], 64), isFalse);
    expect(WSFrame.validHeader([0xab, 0, 1, 0, 0, 0, 0, 1], 64), isFalse);
  });
  test('assembling timeout ACKs only a trusted complete header', () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    final events = <WSLinkEvent>[];
    link.frames.listen(events.add);
    t.receive([0xab, 0]);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(t.chunks, isEmpty);
    t.receive(WSFrame(seq: 42, payload: [1, 2, 3]).encode().sublist(0, 9));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final ack = WSFrame.decode(t.chunks.single);
    expect(ack.isError, isTrue);
    expect(ack.seq, 42);
    expect(events.where((e) => e.kind == WSFrameKind.assembleTimeout),
        hasLength(2));
    await link.close();
  });
  test('CRC failure produces ERR ACK without delivery', () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    final payloads = <WSReceivedPayload>[];
    link.payloads.listen(payloads.add);
    final raw = WSFrame(seq: 12, payload: [1, 2]).encode();
    raw[8] ^= 1;
    t.receive(raw);
    await tick();
    expect(payloads, isEmpty);
    expect(WSFrame.decode(t.chunks.single).isError, isTrue);
    await link.close();
  });
  for (final (limit, size) in [(20, 8192), (244, 8192), (512, 65535)]) {
    test('write limit $limit supports $size bytes and early ACK', () async {
      final t = TestTransport(maxWriteLength: limit);
      final link = WSLink(t, config: quick);
      final parser = WSFrameAssembler(
          timeout: const Duration(seconds: 1),
          maxPayloadLength: 65535,
          onFrame: (f, _) =>
              t.receive(WSFrame(seq: f.seq, isAck: true).encode()),
          onError: (_, __, ___) => fail('bad transmitted frame'));
      t.onWrite = (c) async {
        parser.add(c);
      };
      final bytes = Uint8List.fromList(List.generate(size, (i) => i & 255));
      await link.send(bytes);
      expect(t.chunks.every((c) => c.length <= limit), isTrue);
      expect(
          WSFrame.decode(Uint8List.fromList(t.chunks.expand((c) => c).toList()))
              .payload,
          bytes);
      await expectLater(link.send(Uint8List(65536)), throwsArgumentError);
      parser.dispose();
      await link.close();
    });
  }
  for (final nack in [false, true]) {
    test('${nack ? 'ERR ACK' : 'lost ACK'} retries same bytes and seq',
        () async {
      final t = TestTransport();
      final link = WSLink(t, config: quick);
      var attempts = 0;
      t.onWrite = (c) async {
        final f = WSFrame.decode(c);
        attempts++;
        if (attempts == 2 || nack) {
          t.receive(WSFrame(seq: f.seq, isAck: true, isError: attempts == 1)
              .encode());
        }
      };
      await link.send(Uint8List.fromList([1]));
      expect(attempts, 2);
      expect(t.chunks[0], t.chunks[1]);
      await link.close();
    });
  }
  test('wrong ACK ignored; ACK timeout retries exhausted', () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    t.onWrite = (_) async {
      t.receive(WSFrame(seq: 999, isAck: true).encode());
    };
    await expectLater(
        link.send(Uint8List(1)),
        throwsA(isA<WSTimeoutException>()
            .having((e) => e.kind, 'kind', WSTimeoutKind.ack)));
    expect(t.chunks, hasLength(2));
    await link.close();
  });
  test('ERR ACK exhausted and non-idempotent retry override', () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    t.onWrite = (c) async {
      t.receive(WSFrame(seq: WSFrame.decode(c).seq, isAck: true, isError: true)
          .encode());
    };
    await expectLater(link.send(Uint8List(1), maxRetries: 0),
        throwsA(isA<WSNackException>()));
    expect(t.chunks, hasLength(1));
    await link.close();
  });
  test(
      'ACK priority never interrupts a complete frame and does not wait for its ACK',
      () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    final gate = Completer<void>();
    t.onWrite = (_) async {
      if (t.chunks.length == 1) await gate.future;
    };
    final sent = link.send(Uint8List(50));
    await tick();
    t.receive(WSFrame(seq: 600, payload: [9]).encode());
    expect(t.chunks, hasLength(1));
    gate.complete();
    await tick();
    expect(t.chunks.map((c) => c.length), [20, 20, 18, 8]);
    expect(WSFrame.decode(t.chunks.last).seq, 600);
    t.receive(WSFrame(seq: 1, isAck: true).encode());
    await sent;
    await link.close();
  });
  test('partial write failure terminates without full-frame retry', () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    t.onWrite = (_) async {
      if (t.chunks.length == 2) throw StateError('write failed');
    };
    await expectLater(link.send(Uint8List(60)), throwsStateError);
    await link.close();
    expect(t.chunks, hasLength(2));
    expect(t.disposeCount, 1);
  });
  test('hanging write times out and cannot append another frame', () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    final gate = Completer<void>();
    t.onWrite = (_) => gate.future;
    await expectLater(
        link.send(Uint8List(40)),
        throwsA(isA<WSTimeoutException>()
            .having((e) => e.kind, 'kind', WSTimeoutKind.write)));
    await link.close();
    gate.complete();
    expect(t.chunks, hasLength(1));
  });
  test(
      'recent dedup spans intervening frames; same seq different payload survives',
      () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    final frames = <WSReceivedPayload>[];
    link.payloads.listen(frames.add);
    for (final (seq, data) in [(1, 5), (2, 6), (1, 5), (1, 7)]) {
      t.receive(WSFrame(seq: seq, payload: [data]).encode());
    }
    await tick();
    expect(frames.map((e) => e.bytes.single), [5, 6, 7]);
    expect(t.chunks, hasLength(4));
    await link.close();
  });
  test('bounded dedup age and capacity allow seq reuse', () async {
    final t = TestTransport();
    final link = WSLink(t,
        config: const WSLinkConfig(
            deduplicationCapacity: 1,
            deduplicationWindow: Duration(milliseconds: 10)));
    final frames = <WSReceivedPayload>[];
    link.payloads.listen(frames.add);
    for (final seq in [1, 2, 1]) {
      t.receive(WSFrame(seq: seq, payload: [5]).encode());
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
    t.receive(WSFrame(seq: 1, payload: [5]).encode());
    expect(frames, hasLength(4));
    await link.close();
  });
  test('disconnect aborts active and queued writes and clears assembler',
      () async {
    final t = TestTransport();
    final link = WSLink(t, config: quick);
    final a = expectLater(
        link.send(Uint8List(1)), throwsA(isA<WSDisconnectedException>()));
    final b = expectLater(
        link.send(Uint8List(1)), throwsA(isA<WSDisconnectedException>()));
    await tick();
    t.receive([0xab, 0]);
    await t.disconnect();
    await Future.wait([a, b]);
    await link.close();
    await link.close();
    expect(link.bufferedBytes, 0);
    expect(t.disposeCount, 1);
  });
  test('invalid configuration rejected before starting timers', () {
    expect(
        () => WSLink(TestTransport(),
            config: const WSLinkConfig(maxPayloadLength: 65536)),
        throwsArgumentError);
  });
  test('sequence wraps after 65535 and restarts on new connection', () async {
    final transport = TestTransport();
    final link = WSLink(transport);
    var count = 0;
    transport.onWrite = (chunk) async {
      final seq = (chunk[6] << 8) | chunk[7];
      count++;
      if (count == 1) expect(seq, 1);
      if (count == 65535) expect(seq, 65535);
      if (count == 65536) expect(seq, 0);
      if (count == 65537) expect(seq, 1);
      transport.receive([0xab, 0x10, 0, 0, 0, 0, chunk[6], chunk[7]]);
      transport.chunks.clear();
    };
    for (var i = 0; i < 65537; i++) {
      await link.send(Uint8List(0));
    }
    await link.close();
    final next = TestTransport();
    final nextLink = WSLink(next);
    next.onWrite = (chunk) async {
      next.receive([0xab, 0x10, 0, 0, 0, 0, chunk[6], chunk[7]]);
    };
    await nextLink.send(Uint8List(0));
    expect(WSFrame.decode(next.chunks.single).seq, 1);
    await nextLink.close();
  });
  test('closing from a frame observer prevents the pending chunk write',
      () async {
    final transport = TestTransport();
    final link = WSLink(transport);
    link.frames.listen((event) {
      if (event.kind == WSFrameKind.chunk) {
        link.close();
      }
    });
    await expectLater(
        link.send(Uint8List(1)), throwsA(isA<WSDisconnectedException>()));
    await link.close();
    expect(transport.chunks, isEmpty);
  });

  test('closing from an ACK observer does not deliver into a closed stream',
      () async {
    final transport = TestTransport();
    final link = WSLink(transport);
    final payloads = <WSReceivedPayload>[];
    link.payloads.listen(payloads.add);
    link.frames.listen((event) {
      if (event.kind == WSFrameKind.ack &&
          event.direction == WSFrameDirection.tx) {
        link.close();
      }
    });
    transport.receive(WSFrame(seq: 9, payload: [1]).encode());
    await link.close();
    expect(payloads, isEmpty);
  });
}
