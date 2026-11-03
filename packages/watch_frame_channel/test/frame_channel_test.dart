import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_frame_channel/watch_frame_channel.dart';

Uint8List hex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16)
    ]);
Future<void> turn() => Future<void>.delayed(Duration.zero);
const quick = WatchFrameConfig(
    ackTimeout: Duration(milliseconds: 20),
    chunkWriteTimeout: Duration(milliseconds: 30),
    rxAssembleTimeout: Duration(milliseconds: 20),
    maxRetries: 1);
Matcher frameError(WatchFrameErrorKind kind) =>
    isA<WatchFrameException>().having((e) => e.kind, 'kind', kind);

class Port {
  final rx = StreamController<Uint8List>.broadcast(sync: true),
      down = StreamController<void>.broadcast(sync: true);
  final writes = <Uint8List>[];
  int limit = 244, closes = 0;
  Future<void> Function(Uint8List)? onWrite;
  late final port = WatchFramePort(
      received: rx.stream,
      disconnected: down.stream,
      maxWriteLength: () => limit,
      write: (b) async {
        writes.add(Uint8List.fromList(b));
        await onWrite?.call(b);
      },
      close: () async {
        closes++;
      });
  void ack(int seq, {bool error = false}) => rx.add(Uint8List.fromList(
      [0xab, error ? 0x30 : 0x10, 0, 0, 0, 0, seq >> 8, seq & 255]));
  Future<void> dispose() async {
    await rx.close();
    await down.close();
  }
}

void main() {
  test('CRC catalogue check and exact eight-byte endian vectors', () {
    final b = hex('313233343536373839');
    expect(watchCrc16(b), 0xbb3d); // Independent CRC-16/ARC catalogue check.
    expect(WatchFrame(seq: 0x1234, payload: b).encode(),
        hex('ab000009bb3d1234313233343536373839'));
    expect(WatchFrame.decode(hex('ab000009bb3d1234313233343536373839')).payload,
        b);
    expect(
        WatchFrame(seq: 65535, isAck: true).encode(), hex('ab1000000000ffff'));
    expect(WatchFrame(seq: 0, isAck: true, isError: true).encode(),
        hex('ab30000000000000'));
  });
  test('independent real JW capture and profile flags', () {
    final f = WatchFrame.decode(hex('ab000006b2d00001020050000101'),
        profile: WatchFrameProfile.jw);
    expect(f.seq, 1);
    expect(f.payload, hex('020050000101'));
    for (final flag in [0, 0x10, 0x30, 0x40, 0x50, 0x70]) {
      final b = [0xab, flag, 0, 0, 0, 0, 0, 7];
      expect(WatchFrame.validHeader(b, 236, profile: WatchFrameProfile.jw),
          isTrue);
      expect(WatchFrame.validHeader(b, 65535), flag < 0x40);
    }
    for (final flag in [1, 0x20, 0x60, 0x80, 0xff]) {
      expect(
          WatchFrame.validHeader([0xab, flag, 0, 0, 0, 0, 0, 1], 236,
              profile: WatchFrameProfile.jw),
          isFalse);
    }
    for (final bad in ['ab10000100000001ff', 'ab10000000010001']) {
      expect(() => WatchFrame.decode(hex(bad)), throwsFormatException);
    }
  });
  test('immutable snapshots', () {
    final b = Uint8List.fromList([1]), f = WatchFrame(seq: 0, payload: [1]);
    final e = WatchFrameEvent(
        direction: WatchFrameDirection.rx,
        kind: WatchFrameKind.data,
        raw: b,
        connectionGeneration: 8);
    final p = WatchReceivedPayload(1, b);
    b[0] = 9;
    expect(f.payload, [1]);
    expect(e.raw, [1]);
    expect(p.bytes, [1]);
    expect(() => f.payload[0] = 5, throwsUnsupportedError);
  });
  for (final profile in WatchFrameProfile.values) {
    test('$profile every split boundary, concatenation, bounded noise', () {
      final frames = <WatchFrame>[], raw = hex('ab000006b2d00001020050000101');
      final a = WatchFrameAssembler(
          timeout: null,
          maxPayloadLength: profile.maxPayloadLength,
          profile: profile,
          onFrame: (f, _) => frames.add(f),
          onError: (_, __, ___) {});
      for (var i = 1; i < raw.length; i++) {
        a.add(Uint8List.fromList([0, 255, ...raw.sublist(0, i)]));
        expect(a.bufferedBytes, i);
        a.add(Uint8List.fromList([...raw.sublist(i), ...raw]));
        expect(a.bufferedBytes, 0);
      }
      expect(frames.length, 2 * (raw.length - 1));
      a.add(Uint8List.fromList(List.filled(200000, 0xab)));
      expect(a.bufferedBytes, lessThanOrEqualTo(profile.maxPayloadLength + 8));
      a.clear();
      a.add(hex('ab00010000000001'));
      if (profile == WatchFrameProfile.jw) expect(a.bufferedBytes, lessThan(8));
      a.clear();
      a.add(raw);
      expect(frames.last.payload, hex('020050000101'));
      a.dispose();
    });
  }
  test('JW rescans CRC-corrupt bytes for embedded good frame', () {
    final frames = <WatchFrame>[];
    final a = WatchFrameAssembler(
        timeout: null,
        maxPayloadLength: 236,
        profile: WatchFrameProfile.jw,
        onFrame: (f, _) => frames.add(f),
        onError: (_, __, ___) {});
    a.add(hex('ab000008ffff0001ab50000000000002'));
    expect(frames.single.seq, 2);
    a.dispose();
  });
  group('reliable channel', () {
    late Port p;
    late WatchFrameChannel c;
    setUp(() {
      p = Port();
      c = WatchFrameChannel(p.port, config: quick);
    });
    tearDown(() async {
      await c.close();
      await p.dispose();
    });
    test('early ACK and copying send buffer', () async {
      p.onWrite = (_) async {
        p.ack(1);
      };
      final b = Uint8List.fromList([5]);
      final f = c.send(b);
      b[0] = 9;
      await f;
      expect(WatchFrame.decode(p.writes.single).payload, [5]);
    });
    for (final nack in [false, true]) {
      test('${nack ? 'ERR' : 'lost'} ACK retries identical bytes', () async {
        p.onWrite = (_) async {
          if (p.writes.length == 1 && nack) p.ack(1, error: true);
          if (p.writes.length == 2) p.ack(1);
        };
        await c.send(Uint8List(1));
        expect(p.writes, hasLength(2));
        expect(p.writes[0], p.writes[1]);
      });
    }
    test('wrong ACK ignored and retry exhausted', () async {
      p.onWrite = (_) async {
        p.ack(65535);
      };
      await expectLater(c.send(Uint8List(1)),
          throwsA(frameError(WatchFrameErrorKind.ackTimeout)));
      expect(p.writes, hasLength(2));
    });
    test('non-idempotent retry zero and ERR exhaustion', () async {
      p.onWrite = (_) async {
        p.ack(1, error: true);
      };
      await expectLater(c.send(Uint8List(1), maxRetries: 0),
          throwsA(frameError(WatchFrameErrorKind.nack)));
      expect(p.writes, hasLength(1));
    });
    test(
        'confirmation identifies active handle, not queued send or same generation',
        () async {
      final a = c.startSend(Uint8List(1)), b = c.startSend(Uint8List(1));
      final op = Port();
      final oc = WatchFrameChannel(op.port, generation: c.generation),
          foreign = c.startSend(Uint8List(1));
      final of = oc.startSend(Uint8List(1));
      await turn();
      expect(c.confirmReceived(b), isFalse);
      expect(c.confirmReceived(of), isFalse);
      expect(c.confirmReceived(a), isTrue);
      await a.completed;
      expect(c.confirmReceived(a), isFalse);
      await turn();
      expect(b.sequence, 2);
      p.ack(2);
      await b.completed;
      await turn();
      p.ack(3);
      await foreign.completed;
      await oc.close();
      await expectLater(
          of.completed, throwsA(frameError(WatchFrameErrorKind.disconnected)));
      await op.dispose();
    });
    test('matching reply proof wins over earlier NACK in same write', () async {
      late WatchFrameSend s;
      p.onWrite = (_) async {
        p.ack(1, error: true);
        c.confirmReceived(s);
      };
      s = c.startSend(Uint8List(1), maxRetries: 0);
      await s.completed;
      expect(p.writes, hasLength(1));
    });
    test('ACK priority only at frame boundary and live write limit', () async {
      p.limit = 10;
      final gate = Completer<void>();
      p.onWrite = (_) async {
        if (p.writes.length == 1) await gate.future;
      };
      final f = c.send(Uint8List(24));
      await turn();
      p.rx.add(hex('ab000006b2d00001020050000101'));
      expect(p.writes, hasLength(1));
      p.limit = 20;
      gate.complete();
      await turn();
      expect(p.writes.map((w) => w.length), [10, 20, 2, 8]);
      expect(p.writes.last, hex('ab10000000000001'));
      p.ack(1);
      await f;
    });
    test('duplicates reACK and sequence conflict remains observable', () async {
      final data = <WatchReceivedPayload>[], events = <WatchFrameEvent>[];
      c.payloads.listen(data.add);
      c.frames.listen(events.add);
      final b = hex('ab000006b2d00001020050000101');
      p.rx.add(b);
      p.rx.add(b);
      p.rx.add(WatchFrame(seq: 1, payload: [9]).encode());
      await c.flushWrites();
      expect(data, hasLength(2));
      expect(p.writes, hasLength(3));
      expect(events.where((e) => e.kind == WatchFrameKind.sequenceConflict),
          hasLength(1));
    });
    test('partial write failure aborts queued sends and preserves cause',
        () async {
      p.limit = 10;
      final error = StateError('partial frame');
      p.onWrite = (_) async {
        if (p.writes.length == 2) throw error;
      };
      final a = c.send(Uint8List(40)), b = c.send(Uint8List(1));
      final m = isA<WatchFrameWriteException>()
          .having((e) => e.cause, 'cause', same(error));
      await Future.wait(
          [expectLater(a, throwsA(m)), expectLater(b, throwsA(m))]);
      await c.close();
      expect(p.writes, hasLength(2));
      expect(p.closes, 1);
    });
    test('hanging write cannot append another frame after timeout', () async {
      final gate = Completer<void>();
      p.onWrite = (_) => gate.future;
      final a = c.send(Uint8List(40)), b = c.send(Uint8List(1));
      await Future.wait([
        expectLater(a, throwsA(frameError(WatchFrameErrorKind.writeTimeout))),
        expectLater(b, throwsA(frameError(WatchFrameErrorKind.writeTimeout)))
      ]);
      gate.complete();
      await turn();
      expect(p.writes, hasLength(1));
    });
    test('disconnect clears active, queued and residual bytes', () async {
      final a = c.send(Uint8List(1)), b = c.send(Uint8List(1));
      final check = Future.wait([
        expectLater(a, throwsA(frameError(WatchFrameErrorKind.disconnected))),
        expectLater(b, throwsA(frameError(WatchFrameErrorKind.disconnected)))
      ]);
      await turn();
      p.rx.add(hex('ab000006b2d00001'));
      p.down.add(null);
      await check;
      await c.close();
      p.ack(1);
      expect(c.bufferedBytes, 0);
      expect(p.writes, hasLength(1));
      expect(p.closes, 1);
    });
    test('notification stream errors terminate sends', () async {
      final a = c.send(Uint8List(1));
      final check =
          expectLater(a, throwsA(frameError(WatchFrameErrorKind.receive)));
      p.rx.addError(StateError('notify'));
      await check;
    });
    test('retry and ACK observations retain generation, seq and correlation',
        () async {
      final events = <WatchFrameEvent>[];
      c.frames.listen(events.add);
      p.onWrite = (_) async {
        if (p.writes.length == 2) p.ack(1);
      };
      await c.send(Uint8List(1), requestId: 'r', traceId: 't');
      expect(events.where((e) => e.kind == WatchFrameKind.retry), hasLength(1));
      expect(
          events.every((e) =>
              e.connectionGeneration == 1 &&
              e.seq == 1 &&
              e.requestId == 'r' &&
              e.traceId == 't'),
          isTrue);
    });
  });
  test('bounded send queue rejects overflow; close fails every handle',
      () async {
    final t = Port();
    final channel = WatchFrameChannel(t.port,
        config: const WatchFrameConfig(sendQueueCapacity: 2));
    final a = channel.startSend(Uint8List(0)),
        b = channel.startSend(Uint8List(0));
    await expectLater(channel.send(Uint8List(0)),
        throwsA(frameError(WatchFrameErrorKind.queueFull)));
    await channel.close();
    for (final h in [a, b]) {
      await expectLater(
          h.completed, throwsA(frameError(WatchFrameErrorKind.disconnected)));
    }
    await t.dispose();
  });
  test(
      'bounded control queue overflow terminates stream instead of dropping ACK',
      () async {
    final p = Port(), gate = Completer<void>();
    p.onWrite = (_) => gate.future;
    final c = WatchFrameChannel(p.port,
        config: const WatchFrameConfig(controlQueueCapacity: 1));
    for (var seq = 0; seq < 3; seq++) {
      p.rx.add(WatchFrame(seq: seq, payload: [1]).encode());
    }
    expect((await c.terminated as WatchFrameException).kind,
        WatchFrameErrorKind.queueFull);
    gate.complete();
    await c.close();
    expect(p.writes, hasLength(1));
    await p.dispose();
  });
  for (final profile in WatchFrameProfile.values) {
    test('$profile CRC and assembly timeout policy trusts header only',
        () async {
      final p = Port();
      final c = WatchFrameChannel(p.port,
          profile: profile,
          config: const WatchFrameConfig(
              maxPayloadLength: 236,
              rxAssembleTimeout: Duration(milliseconds: 10)));
      final data = <WatchReceivedPayload>[];
      c.payloads.listen(data.add);
      p.rx.add(hex('ab000006b2d10001020050000101'));
      await turn();
      expect(p.writes.length, profile == WatchFrameProfile.ws ? 1 : 0);
      p.rx.add(hex('ab000006b2d0000202'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(p.writes.length, profile == WatchFrameProfile.ws ? 2 : 0);
      p.rx.add(hex('ab00'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(p.writes.length, profile == WatchFrameProfile.ws ? 2 : 0);
      expect(c.bufferedBytes, 0);
      expect(data, isEmpty);
      await c.close();
      await p.dispose();
    });
  }
  test('JW noACK data and 0x50 ACK never loop', () async {
    final p = Port();
    final c = WatchFrameChannel(p.port,
        profile: WatchFrameProfile.jw,
        config: const WatchFrameConfig(maxPayloadLength: 236));
    final data = <WatchReceivedPayload>[];
    c.payloads.listen(data.add);
    final b = hex('ab400006b2d00001020050000101');
    p.rx.add(b);
    p.rx.add(b);
    expect(data, hasLength(1));
    expect(p.writes, isEmpty);
    p.onWrite = (_) async {
      p.rx.add(hex('ab50000000000001'));
    };
    await c.send(Uint8List(0));
    await c.close();
    await p.dispose();
  });
  test('maximum payload, length rejection and seq wrap for both profiles',
      () async {
    for (final profile in WatchFrameProfile.values) {
      final p = Port();
      p.limit = 512;
      final decoded = <WatchFrame>[];
      final parser = WatchFrameAssembler(
          timeout: null,
          profile: profile,
          maxPayloadLength: profile.maxPayloadLength,
          onFrame: (f, _) {
            decoded.add(f);
            p.ack(f.seq);
          },
          onError: (_, __, ___) => fail('bad frame'));
      p.onWrite = (b) async {
        parser.add(b);
      };
      final c = WatchFrameChannel(p.port,
          profile: profile,
          config: WatchFrameConfig(
              maxPayloadLength: profile.maxPayloadLength,
              initialSequence: 65535));
      await c.send(Uint8List(profile.maxPayloadLength));
      await c.send(Uint8List(0));
      expect(decoded.map((f) => f.seq), [65535, 0]);
      await expectLater(
          c.send(Uint8List(profile.maxPayloadLength + 1)), throwsArgumentError);
      await c.close();
      parser.dispose();
      await p.dispose();
    }
  });
}
