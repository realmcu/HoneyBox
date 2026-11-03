import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/protocol/core_registry.dart';

void main() {
  late WSWatch watch;
  late WSDriftDeviceStore store;
  setUp(() {
    store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    watch = runZoned(
        () => WSWatch(config: const WSConfig(simulationEnabled: true)),
        zoneValues: {
          wsEnvironmentZoneKey: WSConnectionEnvironment(
              openStore: (_) async => store,
              openTransport: (_, c) async {
                // Obtain the simulator instance without exporting it to the Demo.
                final managed = await WSConnectionEnvironment.openSimulator(
                    c, SimWatchState()..confirmationDelay = Duration.zero);
                return managed;
              })
        });
  });
  tearDown(() async {
    await watch.dispose();
    await store.close();
  });
  test('catalog is immutable and browsable before and after connection',
      () async {
    final initial = watch.debug.protocols;
    expect(initial.length, greaterThan(350));
    expect(
        initial.any((p) =>
            p.address.cmd == 5 &&
            p.address.version == 1 &&
            p.address.key == 1 &&
            p.status == WSProtocolStatus.active),
        isTrue);
    expect(
        initial.any((p) =>
            p.address.cmd == 0x11 &&
            p.status == WSProtocolStatus.unimplemented),
        isTrue);
    expect(
        initial.any(
            (p) => p.address.cmd == 7 && p.status == WSProtocolStatus.reserved),
        isTrue);
    expect(() => initial.clear(), throwsUnsupportedError);
    expect(initial.map((p) => p.address).toSet(), hasLength(initial.length));
    await watch.connect(kWsWatchSimDeviceId);
    expect(watch.debug.protocols.length, initial.length);
    await watch.disconnect();
    expect(watch.debug.protocols.length, initial.length);
  });
  test('reserved ranges reject every version, key and opcode before writing',
      () async {
    await watch.connect(kWsWatchSimDeviceId);
    final frames = <WSFrameEvent>[];
    final sub = watch.debug.frames.listen(frames.add);
    for (final cmd in [7, 11, 14, 15]) {
      await expectLater(
          watch.debug
              .sendRaw(WSRawRequest(cmd: cmd, version: 15, key: 255, data: [])),
          throwsA(isA<WSDroppedProtocolException>()));
    }
    await expectLater(
        watch.debug.sendRaw(WSRawRequest(
            cmd: 2, version: 0, key: 0x43, settingOpcode: 7, data: [])),
        throwsA(isA<WSDroppedProtocolException>()));
    expect(frames, isEmpty);
    await sub.cancel();
  });
  test(
      'Raw exchange has trace/request/generation; notifications remain unassociated',
      () async {
    await watch.connect(kWsWatchSimDeviceId);
    final frames = <WSFrameEvent>[], reports = <WSDeviceReport>[];
    final a = watch.debug.frames.listen(frames.add),
        b = watch.debug.reports.listen(reports.add);
    final result = await watch.debug.trace(
        'raw-read',
        () => watch.debug.sendRaw(WSRawRequest(
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
                direction: WSWireDirection.deviceToPhone))));
    expect(result, [1]);
    final dataFrames = frames.where((f) =>
        f.kind == WSFrameKind.data && f.keys.any((k) => k.address.key == 3));
    expect(dataFrames, hasLength(2));
    expect(
        dataFrames.every((f) =>
            f.traceId == 'raw-read' &&
            f.requestId != null &&
            f.connectionGeneration > 0),
        isTrue);
    expect(reports, isEmpty);
    await watch.debug.trace(
        'raw-write',
        () => watch.debug.sendRaw(WSRawRequest(
            cmd: 2, version: 0, key: 3, settingOpcode: 0, data: [7])));
    await Future<void>.delayed(Duration.zero);
    expect(reports.single.kind, WSReportKind.notification);
    expect(reports.single.connectionGeneration, greaterThan(0));
    expect(
        frames
            .where((f) =>
                f.direction == WSFrameDirection.rx &&
                f.keys.any((k) => k.address.settingOpcode == 3))
            .every((f) => f.traceId == null && f.requestId == null),
        isTrue);
    await a.cancel();
    await b.cancel();
  });
  test('range classification covers unlisted reserved addresses', () {
    final registry = WSInitializationProtocol.registry();
    expect(
        registry
            .lookup(const WSProtocolAddress(
                cmd: 7,
                version: 3,
                key: 85,
                direction: WSWireDirection.deviceToPhone))!
            .status,
        WSProtocolStatus.reserved);
    expect(
        registry
            .lookup(const WSProtocolAddress(
                cmd: 2,
                version: 0,
                key: 0x47,
                settingOpcode: 3,
                direction: WSWireDirection.deviceToPhone))!
            .status,
        WSProtocolStatus.reserved);
  });
}
