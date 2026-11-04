import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

final target = WatchDeviceTarget(transportId: 'simulation', deviceId: 'test');
Uint8List bytes(int value) => Uint8List.fromList([value]);
Matcher fails(WatchTransportErrorCode code) =>
    throwsA(isA<WatchTransportException>().having((e) => e.code, 'code', code));
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('duplex opaque bytes are copied and immutable; early push is buffered',
      () async {
    final (host, peer) =
        WatchSimulationConnection.pair(target: target, maxWriteLength: 3);
    addTearDown(host.dispose);
    addTearDown(peer.dispose);
    await host.connect();
    await peer.connect();
    final input = bytes(7);
    final writing = host.write(input);
    input[0] = 9;
    await writing;
    final received = await peer.received.first;
    expect(received, [7]);
    expect(() => received[0] = 4, throwsUnsupportedError);
    await peer.write(bytes(8));
    expect(await host.received.first, [8]);
    await expectLater(
        host.write(Uint8List(4)), fails(WatchTransportErrorCode.writeTooLarge));
  });

  test('writes serialize and hook failures use neutral errors', () async {
    final (host, peer) = WatchSimulationConnection.pair(target: target);
    addTearDown(host.dispose);
    addTearDown(peer.dispose);
    await host.connect();
    await peer.connect();
    final gate = Completer<void>();
    final calls = <int>[];
    host.interceptWrite = (data) async {
      calls.add(data[0]);
      if (data[0] == 1) await gate.future;
      if (data[0] == 3) throw StateError('script failure');
    };
    final first = host.write(bytes(1));
    final second = host.write(bytes(2));
    await tick();
    expect(calls, [1]);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, [1, 2]);
    await expectLater(
        host.write(bytes(3)), fails(WatchTransportErrorCode.write));
    await host.write(bytes(4));
  });

  test('disconnect aborts active and queued writes, late delivery stays closed',
      () async {
    final (host, peer) = WatchSimulationConnection.pair(target: target);
    addTearDown(host.dispose);
    addTearDown(peer.dispose);
    await expectLater(
        host.write(bytes(1)), fails(WatchTransportErrorCode.notConnected));
    await host.connect();
    await peer.connect();
    final gate = Completer<void>();
    host.interceptWrite = (_) => gate.future;
    final received = <Uint8List>[];
    peer.received.listen(received.add);
    final down = <WatchDisconnectEvent>[];
    host.disconnected.listen(down.add);
    final a = expectLater(
        host.write(bytes(1)), fails(WatchTransportErrorCode.closed));
    final b = expectLater(
        host.write(bytes(2)), fails(WatchTransportErrorCode.closed));
    await tick();
    await host.disconnect();
    await Future.wait([a, b]);
    host.deliver(bytes(5));
    gate.completeError(StateError('late'));
    await tick();
    await host.disconnect();
    expect(received, isEmpty);
    expect(down, hasLength(1));
    await expectLater(host.connect(), fails(WatchTransportErrorCode.closed));
  });

  test('unsubscribed buffer overflow drops bytes without disconnecting', () async {
    final (host, peer) =
        WatchSimulationConnection.pair(target: target, maxBufferedBytes: 2);
    addTearDown(host.dispose);
    addTearDown(peer.dispose);
    await host.connect();
    await peer.connect();
    await host.write(bytes(1));
    await host.write(bytes(2));
    await host.write(bytes(3));
    expect(host.state, WatchTransportState.connected);
    expect(peer.state, WatchTransportState.connected);
  });

  test('state listeners can close a connection without reentrant stream errors',
      () async {
    final (host, peer) = WatchSimulationConnection.pair(target: target);
    addTearDown(host.dispose);
    addTearDown(peer.dispose);
    host.stateChanges.listen((state) {
      if (state == WatchTransportState.connected) unawaited(host.disconnect());
    });
    await host.connect();
    await tick();
    expect(host.state, WatchTransportState.disconnected);
  });

  test('registry has no default device and checks targets', () {
    final registry = WatchSimulationTransport();
    expect(registry.devices, isEmpty);
    expect(() => registry.createConnection(target),
        throwsA(isA<WatchTransportException>()));
    expect(
        () => registry.createConnection(
            WatchDeviceTarget(transportId: 'ble', deviceId: 'test')),
        throwsA(isA<WatchTransportException>()));
  });

  test('factory owns behavior, persists state and releases exclusive lease',
      () async {
    final registry = WatchSimulationTransport();
    var attaches = 0;
    var cleanups = 0;
    final device = WatchSimulationDevice(
        id: 'test',
        name: 'test',
        maxWriteLength: 3,
        attach: (peer) async {
          attaches++;
          peer.received.listen(
              (data) => unawaited(peer.write(data).catchError((Object error) {
                    if (error is! WatchTransportException ||
                        error.code != WatchTransportErrorCode.closed) {
                      throw error;
                    }
                  })));
          await peer.write(bytes(attaches));
          return WatchSimulationDeviceSession(dispose: () async {
            cleanups++;
          });
        });
    registry.register(device);
    expect(() => registry.register(device), throwsArgumentError);
    final host = registry.createConnection(target);
    addTearDown(host.dispose);
    await host.connect();
    expect(await host.received.first, [1]);
    final busy = registry.createConnection(target);
    addTearDown(busy.dispose);
    await expectLater(busy.connect(), fails(WatchTransportErrorCode.busy));
    await host.write(bytes(9));
    expect(await host.received.first, [9]);
    await host.disconnect();
    expect(cleanups, 1);
    final next = registry.createConnection(target);
    addTearDown(next.dispose);
    await next.connect();
    expect(await next.received.first, [2]);
  });

  test(
      'different devices connect independently; remote close cleans both ends once',
      () async {
    final registry = WatchSimulationTransport();
    final peers = <WatchSimulationConnection>[];
    var cleanups = 0;
    for (final id in ['a', 'b']) {
      registry.register(WatchSimulationDevice(
          id: id,
          name: id,
          attach: (peer) {
            peers.add(peer);
            return WatchSimulationDeviceSession(dispose: () async {
              cleanups++;
            });
          }));
    }
    final hosts = registry.devices
        .map((d) => registry.createConnection(d.target))
        .toList();
    for (final host in hosts) {
      addTearDown(host.dispose);
    }
    await Future.wait(hosts.map((h) => h.connect()));
    final down = <WatchDisconnectEvent>[];
    hosts.first.disconnected.listen(down.add);
    await peers.first.disconnect();
    await tick();
    expect(hosts.first.state, WatchTransportState.disconnected);
    expect(hosts.last.state, WatchTransportState.connected);
    expect(cleanups, 1);
    expect(down.single.reason, WatchDisconnectReason.remote);
    await hosts.first.dispose();
    await hosts.first.dispose();
    await hosts.last.dispose();
    expect(cleanups, 2);
    expect(hosts.every((h) => h.state == WatchTransportState.disposed), isTrue);
  });

  test('canceled attach disposes late behavior without releasing newer owner',
      () async {
    final registry = WatchSimulationTransport();
    final gate = Completer<WatchSimulationDeviceSession>();
    var calls = 0;
    var lateCleanup = 0;
    registry.register(WatchSimulationDevice(
        id: 'test',
        name: 'test',
        attach: (_) {
          calls++;
          return calls == 1
              ? gate.future
              : WatchSimulationDeviceSession(dispose: () async {});
        }));
    final old = registry.createConnection(target);
    addTearDown(old.dispose);
    final connecting =
        expectLater(old.connect(), fails(WatchTransportErrorCode.closed));
    await tick();
    await old.disconnect();
    await connecting;
    final next = registry.createConnection(target);
    addTearDown(next.dispose);
    await next.connect();
    gate.complete(WatchSimulationDeviceSession(dispose: () async {
      lateCleanup++;
    }));
    await tick();
    expect(lateCleanup, 1);
    final busy = registry.createConnection(target);
    addTearDown(busy.dispose);
    await expectLater(busy.connect(), fails(WatchTransportErrorCode.busy));
  });

  test('attachment timeout closes connection and disposes late behavior',
      () async {
    final registry = WatchSimulationTransport();
    final gate = Completer<WatchSimulationDeviceSession>();
    var disposed = 0;
    registry.register(WatchSimulationDevice(
        id: 'test',
        name: 'test',
        connectTimeout: const Duration(milliseconds: 10),
        attach: (_) => gate.future));
    final host = registry.createConnection(target);
    addTearDown(host.dispose);
    await expectLater(host.connect(), fails(WatchTransportErrorCode.timeout));
    await host.dispose();
    gate.complete(WatchSimulationDeviceSession(dispose: () async {
      disposed++;
    }));
    await tick();
    expect(disposed, 1);
  });

  test('peer cleanup failure cannot retain the device lease', () async {
    final registry = WatchSimulationTransport();
    registry.register(WatchSimulationDevice(
        id: 'test',
        name: 'test',
        attach: (peer) {
          peer.onDisconnect = () async {
            throw StateError('peer cleanup');
          };
          return WatchSimulationDeviceSession(dispose: () async {});
        }));
    final first = registry.createConnection(target);
    await first.connect();
    await expectLater(first.disconnect(), throwsStateError);
    await expectLater(first.dispose(), throwsStateError);
    final second = registry.createConnection(target);
    await second.connect();
    await expectLater(second.dispose(), throwsStateError);
  });

  test('attach and cleanup failures still release the lease', () async {
    final registry = WatchSimulationTransport();
    var count = 0;
    registry.register(WatchSimulationDevice(
        id: 'test',
        name: 'test',
        attach: (_) {
          if (++count == 1) throw StateError('attach');
          return WatchSimulationDeviceSession(dispose: () async {
            throw StateError('cleanup');
          });
        }));
    final failed = registry.createConnection(target);
    await expectLater(failed.connect(), fails(WatchTransportErrorCode.connect));
    await failed.dispose();
    final host = registry.createConnection(target);
    await host.connect();
    await expectLater(host.disconnect(), throwsStateError);
    await expectLater(host.dispose(), throwsStateError);
    final next = registry.createConnection(target);
    await next.connect();
    await expectLater(next.dispose(), throwsStateError);
  });
}
