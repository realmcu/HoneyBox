import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_protocol.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_fixture.dart';

Future<void> turn() => Future<void>.delayed(Duration.zero);
void main() {
  late FakeJwTransport t;
  late JwSession s;
  setUp(() {
    t = FakeJwTransport();
    s = JwSession(t,
        ackTimeout: const Duration(milliseconds: 30),
        replyTimeout: const Duration(milliseconds: 50));
  });
  tearDown(() async {
    await s.close();
    await t.dispose();
  });
  test(
      'incoming frames retain matched replies and original duplicate sequences',
      () async {
    final frames = <JwFrame>[];
    final events = <JwMessage>[];
    final incoming = s.incomingFrames.listen(frames.add);
    final ordinary = s.events.listen(events.add);
    await s.open();
    final request = s.request(
        JwRequest(command: 5, key: 1, responseKey: 7, readOnly: false));
    await turn();
    final raw = JwCodec.encode(
        seq: 0xffff,
        noAck: true,
        payload: JwCodec.encodeL2(5, [JwField(7, jwHex('000000'))]));
    t.rx.add(raw);
    await request;
    t.rx.add(raw);
    final invalid = Uint8List.fromList(raw)..[4] ^= 1;
    t.rx.add(invalid);
    await turn();
    expect(frames.map((f) => f.seq), [0xffff, 0xffff]);
    expect(frames.first.payload, jwHex('0500070003000000'));
    expect(events, isEmpty);
    await incoming.cancel();
    await ordinary.cancel();
  });
  test('incoming frames stream remains open until the session closes',
      () async {
    var closed = false;
    s.incomingFrames.listen((_) {}, onDone: () => closed = true);
    await s.open();
    await turn();
    expect(closed, isFalse);
    await s.close();
    await turn();
    expect(closed, isTrue);
  });
  test(
      'real L2 reply before ACK completes query and sends original-sequence ACK',
      () async {
    await s.open();
    final p = s.request(JwCommands.functionList());
    await turn();
    t.emitHex('ab00000de856000102003700084dd17dfce34ad83d');
    expect((await p).fields.single.value, jwHex('4dd17dfce34ad83d'));
    await turn();
    expect(t.writes.last, jwHex('ab10000000000001'));
  });
  test('negative ACK retries ACK-only command and never proves delivery',
      () async {
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (!f.ack) {
        final nack =
            JwCodec.encode(seq: f.seq, payload: Uint8List(0), ack: true)
              ..[1] = 0x30;
        t.rx.add(nack);
      }
    };
    await s.open();
    await expectLater(
        s.send(JwCommands.time(DateTime(2026))),
        throwsA(
            isA<JwLinkException>().having((e) => e.stage, 'stage', 'nack')));
    expect(t.writes, hasLength(3));
    expect(t.writes[1], t.writes[0]);
    expect(t.writes[2], t.writes[0]);
    expect(s.isOpen, isFalse);
  });
  test('negative ACK query retries same frame before positive ACK and L2',
      () async {
    var attempts = 0;
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (f.ack) return;
      if (++attempts == 1) {
        final nack =
            JwCodec.encode(seq: f.seq, payload: Uint8List(0), ack: true)
              ..[1] = 0x30;
        t.rx.add(nack);
      } else {
        t.emitAck(f.seq);
        t.emitMessage(2, 0x37, jwHex('4dd17dfce34ad83d'));
      }
    };
    await s.open();
    final reply = await s.request(JwCommands.functionList());
    expect(reply.fields.single.value, jwHex('4dd17dfce34ad83d'));
    expect(attempts, 2);
    final requests = t.writes.where((w) => !JwFrameDecoder().add(w).single.ack);
    expect(requests, hasLength(2));
    expect(requests.last, requests.first);
    expect(s.isOpen, isTrue);
  });
  test('missing ACK sends three identical frames and fails by ACK stage',
      () async {
    await s.open();
    await expectLater(s.send(JwCommands.time(DateTime(2026))),
        throwsA(isA<JwLinkException>().having((e) => e.stage, 'stage', 'ack')));
    expect(t.writes.length, 3);
    expect(t.writes[1], t.writes[0]);
    expect(t.writes[2], t.writes[0]);
    expect(s.isOpen, isFalse);
  });
  test('transport ACK does not invent an application reply', () async {
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (!f.ack) t.emitAck(f.seq);
    };
    await s.open();
    await expectLater(
        s.request(JwCommands.functionList()),
        throwsA(
            isA<JwLinkException>().having((e) => e.stage, 'stage', 'reply')));
    expect(t.sent.where((f) => !f.ack).length, 1);
  });
  test('wrong-sequence ACK cannot complete an ACK-only command', () async {
    await s.open();
    final p = s.send(JwCommands.time(DateTime(2026)));
    var done = false;
    p.then((_) => done = true);
    await turn();
    t.emitAck(0xffff);
    await turn();
    expect(done, isFalse);
    t.emitAck(1);
    await p;
  });
  test('noAck data and incoming ACK never generate ACK loops', () async {
    await s.open();
    final events = <JwMessage>[];
    final sub = s.events.listen(events.add);
    addTearDown(sub.cancel);
    t.emitMessage(5, 0xfe, jwHex('01'), noAck: true);
    t.emitAck(400);
    await turn();
    expect(t.writes, isEmpty);
    expect(events.length, 1);
  });
  test('duplicate data is ACKed twice but delivered once', () async {
    await s.open();
    final events = <JwMessage>[];
    final sub = s.events.listen(events.add);
    addTearDown(sub.cancel);
    t.emitHex('ab00000de856000102003700084dd17dfce34ad83d');
    t.emitHex('ab00000de856000102003700084dd17dfce34ad83d');
    await turn();
    expect(events.length, 1);
    expect(t.sent.where((f) => f.ack).length, 2);
  });
  test('request queue is serial and an unrelated key remains an event',
      () async {
    await s.open();
    final events = <JwMessage>[];
    final sub = s.events.listen(events.add);
    addTearDown(sub.cancel);
    final a = s.request(JwCommands.functionList());
    final b = s.request(JwCommands.factorySwitch());
    await turn();
    expect(t.sent.where((f) => !f.ack).length, 1);
    t.rx.add(JwCodec.encode(
        seq: 50,
        payload: JwCodec.encodeL2(2, [
          JwField(0x37, jwHex('4dd17dfce34ad83d')),
          JwField(0xfe, jwHex('03'))
        ])));
    await a;
    await turn();
    expect(t.sent.where((f) => !f.ack).length, 2);
    expect(events.single.fields.single.key, 0xfe);
    t.emitMessage(6, 0x3e, jwHex('03'));
    expect((await b).fields.single.value, [3]);
  });
  test('disconnect ends waiting and queued requests', () async {
    await s.open();
    final a = s.request(JwCommands.functionList());
    final b = s.request(JwCommands.factorySwitch());
    final ea = expectLater(a, throwsA(isA<JwLinkException>()));
    final eb = expectLater(b, throwsA(isA<JwLinkException>()));
    await turn();
    t.emitDisconnect();
    await Future.wait([ea, eb]);
    expect(s.isOpen, isFalse);
  });
  test('disconnect while subscribing cannot report an open session', () async {
    t.subscribeGate = Completer<void>();
    final p = s.open();
    final e = expectLater(p, throwsA(isA<JwLinkException>()));
    await turn();
    t.emitDisconnect();
    t.subscribeGate!.complete();
    await e;
    expect(s.isOpen, isFalse);
  });
  test('CCCD and write errors have phases and never leave hanging futures',
      () async {
    t.failSubscribe = true;
    await expectLater(
        s.open(),
        throwsA(isA<JwLinkException>()
            .having((e) => e.stage, 'stage', 'subscribe')));
    final other = FakeJwTransport();
    final session = JwSession(other);
    addTearDown(() async {
      await session.close();
      await other.dispose();
    });
    await session.open();
    other.failWrite = true;
    await expectLater(
        session.send(JwCommands.time(DateTime(2026))),
        throwsA(
            isA<JwLinkException>().having((e) => e.stage, 'stage', 'write')));
  });
  test(
      'old-port replies after close do not finish a fresh session or replay writes',
      () async {
    await s.open();
    final old = s.request(JwCommands.bind(Uint8List(32)));
    final oldFail = expectLater(old, throwsA(isA<JwLinkException>()));
    await turn();
    await s.close();
    await oldFail;
    final fresh = FakeJwTransport();
    final next = JwSession(fresh);
    addTearDown(() async {
      await next.close();
      await fresh.dispose();
    });
    await next.open();
    expect(fresh.writes, isEmpty);
    final p = next.request(JwCommands.functionList());
    var done = false;
    p.then((_) => done = true);
    await turn();
    t.emitHex('ab00000de856000102003700084dd17dfce34ad83d');
    await turn();
    expect(done, isFalse);
    fresh.emitMessage(2, 0x37, jwHex('4dd17dfce34ad83d'));
    await p;
  });
  test('CRC-damaged replies never enter application events', () async {
    await s.open();
    final events = <JwMessage>[];
    final sub = s.events.listen(events.add);
    addTearDown(sub.cancel);
    t.emitHex('ab00000de857000102003700084dd17dfce34ad83d');
    await turn();
    expect(events, isEmpty);
    expect(t.writes, isEmpty);
  });
}
