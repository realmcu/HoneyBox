import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'fake_backend.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test(
      'DFU aliases retain normal identity, stale release cannot affect a new lease',
      () {
    final c = WatchBleCoordinator();
    final lease = c.acquire('AA:BB');
    lease.addDevice('dfu');
    expect(() => c.acquire('aa:bb'), throwsA(isA<WatchTransportException>()));
    expect(() => c.acquire('dfu'), throwsA(isA<WatchTransportException>()));
    c.acquire('other').release();
    lease.release();
    final next = c.acquire('AA:BB');
    lease.release();
    expect(() => c.acquire('aa:bb'), throwsA(isA<WatchTransportException>()));
    next.release();
  });
  test(
      'native exclusive lease blocks other devices and scanning until confirmed release',
      () async {
    final c = WatchBleCoordinator();
    final lease = c.acquire('ota', exclusive: true);
    expect(() => c.acquire('other'), throwsA(isA<WatchTransportException>()));
    await expectLater(c.startScan(start: () async {}, stop: () async {}),
        throwsA(isA<WatchTransportException>()));
    lease.release();
    c.acquire('other').release();
  });
  test(
      'scan takeover retires the old token; old cleanup never stops a newer scan',
      () async {
    final c = WatchBleCoordinator();
    var stops = 0, revoked = 0;
    final old = await c.startScan(
        start: () async {},
        stop: () async {
          stops++;
        },
        onRevoked: () {
          revoked++;
        });
    await c.stopScanning();
    final next = await c.startScan(
        start: () async {},
        stop: () async {
          stops++;
        });
    await old.close();
    expect(stops, 1);
    expect(revoked, 1);
    await next.close();
    expect(stops, 2);
  });
  test('reentrant scan close is idempotent', () async {
    final c = WatchBleCoordinator();
    late BleScanLease lease;
    var stops = 0;
    lease = await c.startScan(
        start: () async {},
        stop: () async {
          stops++;
        },
        onRevoked: () {
          unawaited(lease.close());
        });
    await lease.close();
    expect(stops, 1);
  });
  test('failed scan stop keeps reservation and allows explicit retry',
      () async {
    final c = WatchBleCoordinator();
    var fail = true;
    final old = await c.startScan(
        start: () async {},
        stop: () async {
          if (fail) throw StateError('stop');
        });
    await expectLater(old.close(), throwsStateError);
    await expectLater(c.startScan(start: () async {}, stop: () async {}),
        throwsA(isA<WatchTransportException>()));
    fail = false;
    await old.close();
    final next = await c.startScan(start: () async {}, stop: () async {});
    await next.close();
  });
  test('scanner publishes neutral advertisements and honors timeout', () async {
    final backend = FakeBackend(), c = WatchBleCoordinator();
    final scanner = WatchBleScanner(backend: backend, coordinator: c);
    addTearDown(scanner.dispose);
    await scanner.start(timeout: const Duration(milliseconds: 20));
    backend.scans.add([
      WatchBleAdvertisement(
          deviceId: 'a',
          name: 'Watch',
          rssi: -40,
          manufacturerData: {
            1: [2]
          })
    ]);
    expect(scanner.devices.single.name, 'Watch');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(scanner.isScanning, isFalse);
    expect(backend.scanStops, 1);
  });
  test('scanner cancellation during native start cleans up before another scan',
      () async {
    final backend = FakeBackend(), c = WatchBleCoordinator();
    final gate = Completer<void>();
    backend.scanHook = () => gate.future;
    final old = WatchBleScanner(backend: backend, coordinator: c);
    addTearDown(old.dispose);
    final starting = old.start();
    await tick();
    final stopping = old.stop();
    gate.complete();
    await Future.wait([starting, stopping]);
    backend.scanHook = null;
    final next = WatchBleScanner(backend: backend, coordinator: c);
    addTearDown(next.dispose);
    await next.start();
    await old.stop();
    expect(backend.scanStops, 1);
    await next.stop();
    expect(backend.scanStops, 2);
  });
  test('failed scan start cleans up its own subscription and radio', () async {
    final backend = FakeBackend(), c = WatchBleCoordinator();
    backend.scanHook = () async => throw StateError('start');
    final scanner = WatchBleScanner(backend: backend, coordinator: c);
    addTearDown(scanner.dispose);
    await expectLater(scanner.start(), throwsStateError);
    expect(scanner.isScanning, isFalse);
    expect(backend.scanStops, 1);
    backend.scanHook = null;
    await scanner.start();
    await scanner.stop();
  });
}
