import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/debug/debug_api.dart';
import 'package:ws_watch_sdk/src/link/link.dart';
import 'package:ws_watch_sdk/src/protocol/cmd_02_settings.dart';
import 'package:ws_watch_sdk/src/protocol/protocol.dart';
import 'package:ws_watch_sdk/src/protocol/registry.dart';
import 'package:ws_watch_sdk/src/session/session.dart';
import 'package:ws_watch_sdk/src/transport/connection_factory.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import '../sim/script_peer.dart';
import '../sim/test_transport.dart';

const config = WSConfig(
    simulationEnabled: true,
    link: WSLinkConfig(ackTimeout: Duration(milliseconds: 40), maxRetries: 0),
    session: WSSessionConfig(replyTimeout: Duration(milliseconds: 35)));

class Fixture {
  Fixture(
      {WSSessionConfig sessionConfig =
          const WSSessionConfig(replyTimeout: Duration(milliseconds: 35)),
      WSProtocolRegistry? registry}) {
    peer = ScriptPeer(transport);
    link = WSLink(transport, config: config.link);
    session = WSSession(link, registry ?? WSSettingsProtocol.registry(),
        config: sessionConfig);
  }
  final transport = TestTransport();
  late final ScriptPeer peer;
  late final WSLink link;
  late final WSSession session;
  Future<void> dispose() async {
    peer.dispose();
    await session.dispose();
  }
}

void main() {
  for (final mtu in [23, 247]) {
    test('full M2 simulator raw/typed exchange at MTU $mtu', () async {
      final h = await WSPreparedSimulation.open(config: config, mtu: mtu);
      final events = <WSFrameEvent>[];
      final reports = <WSDeviceReport>[];
      h.debug.frames.listen(events.add);
      h.debug.reports.listen(reports.add);
      await h.debug.trace('language-read', () async {
        final raw = await h.debug.sendRaw(WSRawRequest(
            cmd: 2,
            version: 0,
            key: 3,
            settingOpcode: 1,
            data: [],
            replyAddress: const WSReplyAddress(
                cmd: 2,
                version: 0,
                key: 3,
                settingOpcode: 2,
                direction: WSWireDirection.deviceToPhone)));
        expect(raw, [1]);
      });
      await h.session.send(WSSettingsProtocol.setLanguage, 250);
      expect(await h.session.query(WSSettingsProtocol.getLanguage, null), 250);
      await tick();
      expect(
          reports.any(
              (r) => r.kind == WSReportKind.notification && r.value == 250),
          isTrue);
      expect(
          events.any((e) =>
              e.traceId == 'language-read' &&
              e.requestId != null &&
              e.keys.isNotEmpty),
          isTrue);
      expect(h.debug.protocols, hasLength(4));
      expect(() => h.debug.protocols.clear(), throwsUnsupportedError);
      await h.dispose();
      await h.dispose();
    });
  }
  test('simulation is opt-in; plain watch has no prepared session', () async {
    await expectLater(
        WSPreparedSimulation.open(config: const WSConfig()), throwsStateError);
    final watch = WSWatch();
    final raw =
        WSRawRequest(cmd: 2, version: 0, key: 3, settingOpcode: 1, data: []);
    await expectLater(watch.debug.sendRaw(raw),
        throwsA(isA<WSSessionInvalidatedException>()));
    await watch.dispose();
    await expectLater(
        watch.debug.sendRaw(raw), throwsA(isA<WSDisposedException>()));
  });
  test('response before ACK is retained but cannot complete until ACK',
      () async {
    final f = Fixture();
    f.peer.onData = (_) {
      f.peer.language(2, [8]);
    };
    var completed = false;
    final query =
        f.session.query(WSSettingsProtocol.getLanguage, null).then((v) {
      completed = true;
      return v;
    });
    await tick();
    expect(completed, isFalse);
    f.peer.ack(f.peer.commands.single);
    expect(await query, 8);
    await f.dispose();
  });
  test('business response cannot stand in for missing L1 ACK', () async {
    final f = Fixture();
    f.peer.onData = (_) {
      f.peer.language(2, [8]);
    };
    await expectLater(
        f.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSTimeoutException>()
            .having((e) => e.kind, 'kind', WSTimeoutKind.ack)));
    await f.dispose();
  });
  test('notifications and other versions never satisfy pending read', () async {
    final f = Fixture();
    final reports = <WSDeviceReport>[];
    f.session.reports.listen(reports.add);
    f.peer.onData = (frame) {
      f.peer.ack(frame);
      f.peer.language(3, [7]);
      f.peer.language(2, [9], version: 1);
    };
    var completed = false;
    final pending =
        f.session.query(WSSettingsProtocol.getLanguage, null).then((v) {
      completed = true;
      return v;
    });
    await tick();
    expect(completed, isFalse);
    expect(reports.map((r) => r.kind),
        [WSReportKind.notification, WSReportKind.unknown]);
    f.peer.language(2, [4]);
    expect(await pending, 4);
    await f.dispose();
  });
  test('FIFO queue does not send next query until first reply', () async {
    final f = Fixture();
    f.peer.onData = f.peer.ack;
    final first = f.session.query(WSSettingsProtocol.getLanguage, null);
    final second = f.session.query(WSSettingsProtocol.getLanguage, null);
    await tick();
    expect(f.peer.commands, hasLength(1));
    f.peer.language(2, [1]);
    expect(await first, 1);
    await tick();
    expect(f.peer.commands, hasLength(2));
    f.peer.language(2, [2]);
    expect(await second, 2);
    await f.dispose();
  });
  test(
      'query timeout closes old generation and fails queue; reconnect uses fresh generation',
      () async {
    final h = await WSPreparedSimulation.open(config: config);
    h.device.suppressReplies = true;
    final a = expectLater(
        h.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSTimeoutException>()
            .having((e) => e.kind, 'kind', WSTimeoutKind.reply)));
    final b = expectLater(h.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSSessionInvalidatedException>()));
    await Future.wait([a, b]);
    expect(h.session.isClosed, isTrue);
    await expectLater(h.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSSessionInvalidatedException>()));
    final next = await WSPreparedSimulation.open(config: config);
    expect(
        next.session.link.generation, greaterThan(h.session.link.generation));
    await h.device.notifyLanguage(99).catchError((Object _) {});
    expect(await next.session.query(WSSettingsProtocol.getLanguage, null), 1);
    await h.dispose();
    await next.dispose();
  });
  test('matching malformed value fails immediately; other keys still routed',
      () async {
    final f = Fixture();
    final reports = <WSDeviceReport>[];
    f.session.reports.listen(reports.add);
    f.peer.onData = (frame) {
      f.peer.ack(frame);
      f.peer.payload(Uint8List.fromList([2, 0, 3, 0, 1, 2, 3, 0, 2, 3, 7]));
    };
    await expectLater(f.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSProtocolDecodeException>()));
    expect(reports.single.value, 7);
    expect(f.session.isClosed, isFalse);
    await f.dispose();
  });
  test(
      'unknown, unsolicited, unimplemented, reserved, dropped and decode failures observable',
      () async {
    WSProtocolEntry inbound(int key, WSProtocolStatus status) =>
        WSProtocolEntry(
            address: WSProtocolAddress(
                cmd: 2,
                version: 0,
                key: key,
                settingOpcode: 3,
                direction: WSWireDirection.deviceToPhone),
            name: 'status',
            specRef: 'test',
            status: status);
    final defaults = WSSettingsProtocol.registry();
    final registry = WSProtocolRegistry([
      ...defaults.entries,
      inbound(4, WSProtocolStatus.unimplemented),
      inbound(5, WSProtocolStatus.reserved),
      inbound(6, WSProtocolStatus.dropped)
    ], reports: [
      WSReport<int>(
          entry: WSSettingsProtocol.languageNotify,
          decodeData: WSSettingsProtocol.decodeLanguage)
    ]);
    final f = Fixture(registry: registry);
    final reports = <WSDeviceReport>[];
    f.session.reports.listen(reports.add);
    f.peer.language(2, [3]);
    f.peer.language(3, []);
    for (final key in [4, 5, 6, 7]) {
      f.peer.payload(Uint8List.fromList([2, 0, key, 0, 1, 3]));
    }
    f.peer.payload(Uint8List.fromList([2, 0, 3, 0]));
    expect(reports.map((r) => r.kind), [
      WSReportKind.unsolicitedReply,
      WSReportKind.decodeError,
      WSReportKind.unimplemented,
      WSReportKind.reserved,
      WSReportKind.dropped,
      WSReportKind.unknown,
      WSReportKind.decodeError
    ]);
    await f.dispose();
  });
  test('queue capacity bounds waiting requests and disconnect rejects all',
      () async {
    final f = Fixture(sessionConfig: const WSSessionConfig(queueCapacity: 1));
    final a = expectLater(f.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSDisconnectedException>()));
    final b = expectLater(f.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSDisconnectedException>()));
    await expectLater(f.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSQueueFullException>()));
    await f.transport.disconnect();
    await Future.wait([a, b]);
    await f.dispose();
  });
  test('query can override default reply deadline', () async {
    final f = Fixture(
        sessionConfig:
            const WSSessionConfig(replyTimeout: Duration(milliseconds: 5)));
    f.peer.onData = f.peer.ack;
    final query = WSQuery<void, int>(
        request: WSSettingsProtocol.getLanguageEntry,
        reply: WSSettingsProtocol.languageReply,
        encodeData: (_) => Uint8List(0),
        decodeData: WSSettingsProtocol.decodeLanguage,
        replyTimeout: const Duration(milliseconds: 100));
    final pending = f.session.query(query, null);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    f.peer.language(2, [12]);
    expect(await pending, 12);
    await f.dispose();
  });
  test(
      'raw rejects reserved ranges, validates direction, snapshots input and suppresses unknown retries',
      () async {
    final registry = WSProtocolRegistry(WSSettingsProtocol.registry().entries,
        blockedCommands: {8});
    final f = Fixture(registry: registry);
    f.peer.onData = f.peer.ack;
    await expectLater(
        f.session.sendRaw(
            address: const WSProtocolAddress(
                cmd: 8,
                version: 0,
                key: 0,
                direction: WSWireDirection.phoneToDevice),
            data: Uint8List(0)),
        throwsA(isA<WSDroppedProtocolException>()));
    await expectLater(
        f.session.sendRaw(
            address: const WSProtocolAddress(
                cmd: 3,
                version: 0,
                key: 1,
                direction: WSWireDirection.deviceToPhone),
            data: Uint8List(0)),
        throwsArgumentError);
    final bytes = Uint8List.fromList([77]);
    await f.session.sendRaw(
        address: WSSettingsProtocol.setLanguageEntry.address, data: bytes);
    expect(f.peer.commands.single.payload, [2, 0, 3, 0, 2, 0, 77]);
    await f.dispose();
  });
  test('debug gate prevents external raw during authentication', () async {
    final f = Fixture();
    final debug = WSDebugController()..attach(f.session, allowRaw: () => false);
    await expectLater(
        debug.sendRaw(WSRawRequest(
            cmd: 2, version: 0, key: 3, settingOpcode: 1, data: [])),
        throwsA(isA<WSSessionInvalidatedException>()));
    expect(f.peer.commands, isEmpty);
    await debug.dispose();
    await f.dispose();
  });
  test('simulator clears delayed responses on disposal', () async {
    final h = await WSPreparedSimulation.open(config: config);
    h.device.replyDelay = const Duration(seconds: 30);
    final pending = expectLater(
        h.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSDisconnectedException>()));
    await tick();
    await h.dispose();
    await pending;
  });
  test('ACK timeout invalidates queued queries as well as active query',
      () async {
    final f = Fixture();
    final first = expectLater(
        f.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSTimeoutException>()));
    final queued = expectLater(
        f.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSSessionInvalidatedException>()));
    await Future.wait([first, queued]);
    expect(f.session.isClosed, isTrue);
    expect(f.peer.commands, hasLength(1));
    await f.dispose();
  });

  test('raw snapshots bytes at enqueue, before its predecessor completes',
      () async {
    final f = Fixture();
    f.peer.onData = f.peer.ack;
    final read = f.session.query(WSSettingsProtocol.getLanguage, null);
    final bytes = Uint8List.fromList([77]);
    final write = f.session.sendRaw(
        address: WSSettingsProtocol.setLanguageEntry.address, data: bytes);
    bytes[0] = 99;
    await tick();
    f.peer.language(2, [1]);
    await read;
    await write;
    expect(f.peer.commands.last.payload.last, 77);
    await f.dispose();
  });

  test('unknown raw command has no automatic retry despite link retry defaults',
      () async {
    final t = TestTransport();
    final peer = ScriptPeer(t);
    final link = WSLink(t,
        config: const WSLinkConfig(
            ackTimeout: Duration(milliseconds: 15), maxRetries: 3));
    final session = WSSession(link, WSSettingsProtocol.registry());
    await expectLater(
        session.sendRaw(
            address: const WSProtocolAddress(
                cmd: 3,
                version: 0,
                key: 99,
                direction: WSWireDirection.phoneToDevice),
            data: Uint8List(0)),
        throwsA(isA<WSTimeoutException>()));
    expect(peer.commands, hasLength(1));
    peer.dispose();
    await session.dispose();
  });

  test(
      'debug correlation includes matching reply and ACK, excludes unrelated notification',
      () async {
    final f = Fixture();
    final debug = WSDebugController()..attach(f.session, allowRaw: () => true);
    final events = <WSFrameEvent>[];
    debug.frames.listen(events.add);
    f.peer.onData = (frame) {
      f.peer.ack(frame);
      f.peer.language(3, [9]);
      f.peer.language(2, [5]);
    };
    expect(
        await debug.trace('trace',
            () => f.session.query(WSSettingsProtocol.getLanguage, null)),
        5);
    final incoming = events.where((e) => e.direction == WSFrameDirection.rx);
    expect(incoming.where((e) => e.kind == WSFrameKind.ack).single.traceId,
        'trace');
    expect(
        incoming
            .where((e) => e.keys.any((k) => k.address.settingOpcode == 2))
            .single
            .traceId,
        'trace');
    expect(
        incoming
            .where((e) => e.keys.any((k) => k.address.settingOpcode == 3))
            .single
            .traceId,
        isNull);
    await debug.dispose();
    await f.dispose();
  });
}
