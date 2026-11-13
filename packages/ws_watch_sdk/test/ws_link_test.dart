import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/ws_link.dart';
import 'package:ws_watch_sdk/src/wire/ws_settings_command.dart';
import 'package:ws_watch_sdk/src/wire/ws_l2_message.dart';
import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport/watch_transport.dart';
import 'support/fake_connection.dart';

const quick = WSLinkConfig(
  ackTimeout: Duration(milliseconds: 15),
  maxRetries: 3,
  chunkWriteTimeout: Duration(milliseconds: 20),
  maxPayloadLength: 236,
);
Matcher code(WSErrorCode code) =>
    isA<WSException>().having((e) => e.code, 'code', code);

void main() {
  late FakeConnection connection;
  late WSLink link;
  late List<WSException> failures;
  setUp(() async {
    connection =
        FakeConnection(WatchDeviceTarget(transportId: 'ble', deviceId: 'a'));
    link = WSLink(connection, config: quick);
    failures = [];
    link.failures.listen(failures.add);
    await link.open();
  });
  tearDown(() => link.close());

  void ack(Uint8List bytes, {bool nack = false}) {
    if (bytes[1] & 0x10 != 0) return;
    connection.rx.add(
        WatchFrame(seq: (bytes[6] << 8) | bytes[7], isAck: true, isError: nack)
            .encode());
  }

  test(
      'ACK timeout retries same frame three times, reports error, next call succeeds',
      () async {
    await expectLater(link.send(WSSettingsCommand.setPhoneSystem(1)),
        throwsA(code(WSErrorCode.ackTimeout)));
    expect(connection.writes, hasLength(4));
    expect(connection.writes[1], connection.writes.first);
    expect(connection.writes[2], connection.writes.first);
    expect(failures, isEmpty);
    expect(link.isOpen, isTrue);
    connection.onWrite = (bytes) async => ack(bytes);
    await link.send(WSSettingsCommand.setPhoneSystem(2));
  });

  test('NACK retries and remains an operation error', () async {
    connection.onWrite = (bytes) async => ack(bytes, nack: true);
    await expectLater(link.send(WSSettingsCommand.setPhoneSystem(1)),
        throwsA(code(WSErrorCode.nack)));
    expect(connection.writes, hasLength(4));
    expect(failures, isEmpty);
    expect(link.isOpen, isTrue);
  });

  test('WS business reply does not replace L1 ACK', () async {
    connection.onWrite = (bytes) async {
      if (bytes[1] & 0x10 != 0) return;
      connection.rx.add(WatchFrame(
              seq: 99,
              payload: WSL2Message(
                  command: 2,
                  version: 0,
                  key: 3,
                  value: Uint8List.fromList([2, 1])).encode())
          .encode());
    };
    await expectLater(
        link.request(WSSettingsCommand.readLanguage(), replyKey: 3),
        throwsA(code(WSErrorCode.ackTimeout)));
    expect(connection.writes.where((b) => b[1] & 0x10 == 0), hasLength(4));
    expect(link.isOpen, isTrue);
  });

  test('business reply timeout keeps channel alive and queue proceeds',
      () async {
    connection.onWrite = (bytes) async => ack(bytes);
    await expectLater(
        link.request(WSSettingsCommand.readLanguage(),
            replyKey: 3, timeout: const Duration(milliseconds: 15)),
        throwsA(code(WSErrorCode.businessReplyTimeout)));
    await link.send(WSSettingsCommand.setPhoneSystem(2));
    expect(failures, isEmpty);
  });

  test('write failure and timeout are operation errors', () async {
    connection.onWrite = (_) async => throw StateError('write failed');
    await expectLater(link.send(WSSettingsCommand.setPhoneSystem(1)),
        throwsA(code(WSErrorCode.writeFailed)));
    connection.onWrite = (_) => Completer<void>().future;
    await expectLater(link.send(WSSettingsCommand.setPhoneSystem(1)),
        throwsA(code(WSErrorCode.writeTimeout)));
    expect(failures, isEmpty);
    expect(link.isOpen, isTrue);
  });

  test('disconnect during ACK wait fails active and queued operations once',
      () async {
    connection.onWrite = (_) async => connection.remoteDisconnect();
    final active = link.request(WSSettingsCommand.readLanguage(), replyKey: 3);
    final queued = link.send(WSSettingsCommand.setPhoneSystem(2));
    await Future.wait([
      expectLater(active, throwsA(code(WSErrorCode.transportDisconnected))),
      expectLater(queued, throwsA(code(WSErrorCode.transportDisconnected))),
    ]);
    expect(failures, hasLength(1));
  });

  test('close cancels pending reply immediately', () async {
    connection.onWrite = (bytes) async => ack(bytes);
    final work = link.request(WSSettingsCommand.readLanguage(), replyKey: 3);
    final check = expectLater(work, throwsA(isA<WSException>()));
    await Future<void>.delayed(Duration.zero);
    await link.close();
    await check;
    expect(connection.state, WatchTransportState.disposed);
  });
}
