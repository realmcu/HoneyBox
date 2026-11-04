import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'fake_backend.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);
Matcher fails(WatchTransportErrorCode code) =>
    throwsA(isA<WatchTransportException>().having((e) => e.code, 'code', code));
Uint8List bytes(int value) => Uint8List.fromList([value]);
void main() {
  late FakeBackend backend;
  late WatchBleCoordinator coordinator;
  WatchBleConnection create({String id = 'a', WatchBleConfig? config}) =>
      WatchBleTransport(
              config: config ?? WatchBleConfig(profile: profile()),
              backend: backend,
              coordinator: coordinator)
          .createConnection(
              WatchDeviceTarget(transportId: 'ble', deviceId: id));
  setUp(() {
    backend = FakeBackend();
    coordinator = WatchBleCoordinator();
  });

  test('subscribe before CCCD; early bytes are copied, ordered and immutable',
      () async {
    final device = backend.device('a');
    device.rx.notifyHook = (enabled) async {
      if (enabled) {
        final data = [1];
        device.rx.data.add(data);
        data[0] = 9;
        device.rx.data.add([2]);
      }
    };
    final connection = create();
    addTearDown(connection.dispose);
    await connection.connect();
    final incoming = <Uint8List>[];
    connection.received.listen(incoming.add);
    await tick();
    expect(incoming, [
      [1],
      [2]
    ]);
    expect(() => incoming[0][0] = 9, throwsUnsupportedError);
    expect(connection.state, WatchTransportState.connected);
    await connection.write(bytes(3));
    expect(device.tx.writes, [
      [3]
    ]);
    expect(device.tx.modes, [false]);
  });
  test('MTU changes update limits and oversized calls do not damage a link',
      () async {
    final device = backend.device('a');
    device.reportedMtu = 247;
    final connection = create();
    addTearDown(connection.dispose);
    await connection.connect();
    expect(connection.writeLimits.maxWriteLength, 244);
    device.mtus.add(23);
    expect(connection.writeLimits.maxWriteLength, 20);
    await expectLater(connection.write(Uint8List(21)),
        fails(WatchTransportErrorCode.writeTooLarge));
    device.mtus.add(517);
    expect(connection.writeLimits.maxWriteLength, 512);
    await connection.write(bytes(1));
  });
  test('writes copy caller data, serialize and use configured write properties',
      () async {
    final device = backend.device('a');
    final gate = Completer<void>();
    device.tx.writeHook = (data) async {
      if (data[0] == 1) await gate.future;
    };
    final connection = create(
        config: WatchBleConfig(
            profile: profile(mode: BleWriteMode.preferWithoutResponse)));
    addTearDown(connection.dispose);
    await connection.connect();
    final input = bytes(1);
    final a = connection.write(input);
    input[0] = 9;
    final b = connection.write(bytes(2));
    await tick();
    expect(device.tx.writes, [
      [1]
    ]);
    gate.complete();
    await Future.wait([a, b]);
    expect(device.tx.writes, [
      [1],
      [2]
    ]);
    expect(device.tx.modes, [true, true]);
  });
  for (final phase in ['connect', 'discover', 'notify']) {
    test('$phase failure releases owned resources and reports stage', () async {
      final device = backend.device('a');
      Future<void> failure() async => throw StateError('failure');
      if (phase == 'connect') device.connectHook = failure;
      if (phase == 'discover') device.discoverHook = failure;
      if (phase == 'notify') device.rx.notifyHook = (_) => failure();
      final connection = create();
      await expectLater(
          connection.connect(), throwsA(isA<WatchBleException>()));
      await connection.dispose();
      expect(device.connected, isFalse);
      coordinator.acquire('a').release();
    });
  }
  test(
      'permission and adapter errors retain neutral codes without touching a device',
      () async {
    backend.readyHook = () async => throw const WatchTransportException(
        WatchTransportErrorCode.permissionDenied, 'denied');
    final c = create();
    await expectLater(
        c.connect(), fails(WatchTransportErrorCode.permissionDenied));
    await c.dispose();
    expect(backend.devices, isEmpty);
    coordinator.acquire('a').release();
  });
  test('invalid GATT profile fails before writes or protocol initialization',
      () async {
    backend.device('a').services = [];
    final c = create();
    await expectLater(
        c.connect(), fails(WatchTransportErrorCode.profileUnavailable));
    await c.dispose();
    expect(backend.device('a').tx.writes, isEmpty);
  });
  test('same device is exclusive, different devices connect in parallel',
      () async {
    final a = create(), b = create(id: 'b'), busy = create();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(busy.dispose);
    await Future.wait([a.connect(), b.connect()]);
    await expectLater(busy.connect(), fails(WatchTransportErrorCode.busy));
    expect(a.state, WatchTransportState.connected);
    expect(b.state, WatchTransportState.connected);
  });
  test('a foreign existing platform connection is never disconnected',
      () async {
    final d = backend.device('a');
    d.connected = true;
    final c = create();
    await expectLater(c.connect(), fails(WatchTransportErrorCode.busy));
    await c.dispose();
    expect(d.disconnects, 0);
    expect(d.connected, isTrue);
  });
  test(
      'cancel returns promptly; late connect keeps lease until physically cleaned',
      () async {
    final d = backend.device('a');
    final gate = Completer<void>();
    d.connectHook = () => gate.future;
    final c = create();
    final connecting =
        expectLater(c.connect(), fails(WatchTransportErrorCode.closed));
    await tick();
    final closing = c.disconnect();
    await connecting;
    expect(() => coordinator.acquire('a'),
        throwsA(isA<WatchTransportException>()));
    gate.complete();
    await closing;
    await c.dispose();
    expect(d.connected, isFalse);
    expect(d.disconnects, greaterThanOrEqualTo(2));
    coordinator.acquire('a').release();
  });
  test('connect timeout does not release lease before late native completion',
      () async {
    final d = backend.device('a');
    final gate = Completer<void>();
    d.connectHook = () => gate.future;
    final c = create(
        config: WatchBleConfig(
            profile: profile(),
            connectTimeout: const Duration(milliseconds: 10)));
    await expectLater(c.connect(), fails(WatchTransportErrorCode.timeout));
    expect(() => coordinator.acquire('a'),
        throwsA(isA<WatchTransportException>()));
    gate.complete();
    await c.dispose();
    expect(d.connected, isFalse);
    coordinator.acquire('a').release();
  });
  test('remote close sends one event; old cleanup cannot release a new owner',
      () async {
    final c = create();
    final down = <WatchDisconnectEvent>[];
    c.disconnected.listen(down.add);
    await c.connect();
    backend.device('a').remoteClose();
    await c.dispose();
    await c.dispose();
    expect(down.single.reason, WatchDisconnectReason.remote);
    final next = create();
    addTearDown(next.dispose);
    await next.connect();
    await c.disconnect();
    expect(() => coordinator.acquire('a'),
        throwsA(isA<WatchTransportException>()));
  });
  test(
      'disconnect aborts writes immediately but waits for physical write cleanup',
      () async {
    final d = backend.device('a');
    final gate = Completer<void>();
    d.tx.writeHook = (_) => gate.future;
    final c = create();
    await c.connect();
    final a =
        expectLater(c.write(bytes(1)), fails(WatchTransportErrorCode.closed));
    final b =
        expectLater(c.write(bytes(2)), fails(WatchTransportErrorCode.closed));
    await tick();
    final closing = c.disconnect();
    await Future.wait([a, b]);
    expect(() => coordinator.acquire('a'),
        throwsA(isA<WatchTransportException>()));
    gate.complete();
    await closing;
    await c.dispose();
    expect(d.tx.writes, [
      [1]
    ]);
  });
  test('write failure does not manufacture a byte disconnect', () async {
    final d = backend.device('a');
    d.tx.writeHook = (_) async => throw StateError('write');
    final c = create();
    await c.connect();
    await expectLater(c.write(bytes(1)), fails(WatchTransportErrorCode.write));
    expect(c.state, WatchTransportState.connected);
    d.tx.writeHook = null;
    await c.write(bytes(2));
    await c.dispose();
    expect(d.connected, isFalse);
  });
  test('receive overflow drops data without terminating connection',
      () async {
    final c =
        create(config: WatchBleConfig(profile: profile(), maxBufferedBytes: 1));
    await c.connect();
    backend.device('a').rx.data.add([1, 2]);
    expect(c.state, WatchTransportState.connected);
    await c.write(bytes(1));
    await c.dispose();
  });
  test(
      'optional GATT reads are copied and validated separately from byte writes',
      () async {
    final c = create();
    addTearDown(c.dispose);
    await c.connect();
    final read = await c.readGatt(service: '1800', characteristic: '2a00');
    backend.device('a').tx.readValue[0] = 9;
    expect(read, [42]);
    await expectLater(c.readGatt(service: '1801', characteristic: '2a00'),
        fails(WatchTransportErrorCode.profileUnavailable));
  });
  test('optional reads share the physical queue and read failure is nonfatal',
      () async {
    final d = backend.device('a');
    final gate = Completer<void>();
    d.tx.readHook = () => gate.future;
    final c = create();
    addTearDown(c.dispose);
    await c.connect();
    final reading = c.readGatt(service: '1800', characteristic: '2a00');
    final writing = c.write(bytes(3));
    await tick();
    expect(d.tx.writes, isEmpty);
    gate.complete();
    await reading;
    await writing;
    expect(d.tx.writes, [
      [3]
    ]);
    d.tx.readHook = () async => throw StateError('read');
    await expectLater(c.readGatt(service: '1800', characteristic: '2a00'),
        fails(WatchTransportErrorCode.read));
    await c.write(bytes(4));
    expect(c.state, WatchTransportState.connected);
  });

  test(
      'failed physical disconnect retains lease and explicit cleanup can retry',
      () async {
    final d = backend.device('a');
    final c = create();
    await c.connect();
    d.disconnectHook = () async => throw StateError('disconnect');
    await expectLater(c.disconnect(), throwsA(isA<WatchBleException>()));
    expect(() => coordinator.acquire('a'),
        throwsA(isA<WatchTransportException>()));
    d.disconnectHook = null;
    await c.dispose();
    coordinator.acquire('a').release();
  });
}
