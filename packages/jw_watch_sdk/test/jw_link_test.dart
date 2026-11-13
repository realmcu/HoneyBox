import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/connection/jw_link.dart';
import 'package:jw_watch_sdk/src/connection/jw_protocol.dart';
import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport/watch_transport.dart';
import 'support/fake_connection.dart';

const quick = WatchFrameConfig(
  ackTimeout: Duration(milliseconds: 15),
  maxRetries: 2,
  chunkWriteTimeout: Duration(milliseconds: 20),
  maxPayloadLength: 236,
);
Matcher code(JWErrorCode code) =>
    isA<JWException>().having((e) => e.code, 'code', code);

void main() {
  late FakeConnection connection;
  late JWLink link;
  late List<JWException> failures;
  setUp(() async {
    connection =
        FakeConnection(WatchDeviceTarget(transportId: 'ble', deviceId: 'a'));
    link = JWLink(connection, config: quick);
    failures = [];
    link.failures.listen(failures.add);
    await link.open();
  });
  tearDown(() => link.dispose());

  void ack(Uint8List bytes, {bool nack = false}) {
    if (bytes[1] & 0x10 != 0) return;
    connection.rx.add(
        WatchFrame(seq: (bytes[6] << 8) | bytes[7], isAck: true, isError: nack)
            .encode());
  }

  test(
      'ACK timeout retries same frame twice, reports error, next call succeeds',
      () async {
    await expectLater(link.send(JWProtocolCommands.setLanguage(1)),
        throwsA(code(JWErrorCode.ackTimeout)));
    expect(connection.writes, hasLength(3));
    expect(connection.writes[1], connection.writes.first);
    expect(connection.writes[2], connection.writes.first);
    expect(failures, isEmpty);
    expect(link.isOpen, isTrue);
    connection.onWrite = (bytes) async => ack(bytes);
    await link.send(JWProtocolCommands.setLanguage(2));
  });

  test('NACK retries and remains an operation error', () async {
    connection.onWrite = (bytes) async => ack(bytes, nack: true);
    await expectLater(link.send(JWProtocolCommands.setLanguage(1)),
        throwsA(code(JWErrorCode.nack)));
    expect(connection.writes, hasLength(3));
    expect(failures, isEmpty);
    expect(link.isOpen, isTrue);
  });

  test('matching business reply proves receipt even with missing ACK',
      () async {
    connection.onWrite = (bytes) async {
      if (bytes[1] & 0x10 != 0) return;
      connection.rx
          .add(WatchFrame(seq: 99, payload: [2, 0, 0x50, 0, 1, 2]).encode());
    };
    expect((await link.request(JWProtocolCommands.readLanguage())).value, [2]);
    expect(connection.writes.where((b) => b[1] & 0x10 == 0), hasLength(1));
  });

  test('business reply timeout keeps channel alive and queue proceeds',
      () async {
    connection.onWrite = (bytes) async => ack(bytes);
    await expectLater(
        link.request(const JWProtocolRequest(
            command: 2,
            key: 0x4f,
            responseKey: 0x50,
            replyTimeout: Duration(milliseconds: 15))),
        throwsA(code(JWErrorCode.businessReplyTimeout)));
    await link.send(JWProtocolCommands.setLanguage(2));
    expect(failures, isEmpty);
  });

  test('write failure and timeout are operation errors', () async {
    connection.onWrite = (_) async => throw StateError('write failed');
    await expectLater(link.send(JWProtocolCommands.setLanguage(1)),
        throwsA(code(JWErrorCode.writeFailed)));
    connection.onWrite = (_) => Completer<void>().future;
    await expectLater(link.send(JWProtocolCommands.setLanguage(1)),
        throwsA(code(JWErrorCode.writeTimeout)));
    expect(failures, isEmpty);
    expect(link.isOpen, isTrue);
  });

  test('disconnect during ACK wait fails active and queued operations once',
      () async {
    connection.onWrite = (_) async => connection.remoteDisconnect();
    final active = link.request(JWProtocolCommands.readLanguage());
    final queued = link.send(JWProtocolCommands.setLanguage(2));
    await Future.wait([
      expectLater(active, throwsA(code(JWErrorCode.transportDisconnected))),
      expectLater(queued, throwsA(code(JWErrorCode.transportDisconnected))),
    ]);
    expect(failures, hasLength(1));
  });

  test('dispose cancels a pending unsolicited reply immediately', () async {
    connection.onWrite = (bytes) async => ack(bytes);
    final work = link.sendAndAwaitUnsolicited(
        request: JWProtocolCommands.setLanguage(1),
        responseCommand: 2,
        responseKey: 0x6e);
    final check = expectLater(work, throwsA(isA<JWException>()));
    await Future<void>.delayed(Duration.zero);
    await link.dispose();
    await check;
    expect(connection.state, WatchTransportState.disposed);
  });
}
