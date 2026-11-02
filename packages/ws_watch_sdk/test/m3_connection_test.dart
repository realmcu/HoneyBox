import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';

const config = WSConfig(
    simulationEnabled: true,
    session: WSSessionConfig(replyTimeout: Duration(milliseconds: 80)),
    connectTimeouts:
        WSConnectTimeouts(awaitingConfirm: Duration(milliseconds: 600)));
void main() {
  late SimWatchState device;
  late WSDriftDeviceStore store;
  late WSWatch watch;
  late List<WSManagedTransport> transports;
  late List<WSConnectionState> stages;
  WSWatch create(WSConfig cfg) =>
      runZoned(() => WSWatch(config: cfg), zoneValues: {
        wsEnvironmentZoneKey: WSConnectionEnvironment(
            openTransport: (_, c) async {
              final t = await WSConnectionEnvironment.openSimulator(c, device);
              transports.add(t);
              return t;
            },
            openStore: (_) async => store,
            reconnectDelay: (_) => const Duration(milliseconds: 10))
      });
  setUp(() {
    device = SimWatchState();
    store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    transports = [];
    stages = [];
    watch = create(config);
    watch.stateChanges.listen((e) => stages.add(e.current));
  });
  tearDown(() async {
    await watch.dispose();
    await store.close();
  });
  test('bind, initialize, persist before ready', () async {
    final requests = <String>[];
    final subscription = watch.debug.frames.listen((frame) {
      if (frame.direction == WSFrameDirection.tx &&
          frame.kind == WSFrameKind.data) {
        for (final key in frame.keys) {
          requests.add('${key.address.cmd}/${key.address.key}');
        }
      }
    });
    addTearDown(subscription.cancel);

    await watch.connect(kWsWatchSimDeviceId);
    await Future<void>.delayed(Duration.zero);
    expect(stages, [
      WSConnectionState.connecting,
      WSConnectionState.discovering,
      WSConnectionState.authenticating,
      WSConnectionState.awaitingConfirm,
      WSConnectionState.initializing,
      WSConnectionState.ready
    ]);
    expect(requests, ['3/3', '3/1', '2/2', '2/1', '2/49', '2/48']);
    expect(device.boundUserId, watch.userId);
    expect(watch.userId!.length, 32);
    expect(device.phoneSystem, 2);
    expect(device.timeBytes, hasLength(4));
    expect(watch.deviceInfo!.firmwareVersion, '1.2.3+100');
    expect(watch.deviceInfo!.btMac, '11:22:33:44:55:66');
    expect(watch.deviceInfo!.serialNumber, 'WS2026000001');
    expect(watch.capabilities!.supportOf(WSFeature.language),
        WSFeatureSupport.unknown);
    final row = await store.database.select(store.database.devices).getSingle();
    expect(row.userId, watch.userId);
    expect(row.deviceInfoRaw, watch.deviceInfo!.raw);
    expect(row.capabilitiesRaw, hasLength(16));
  });
  test(
      'confirmation uses separate deadline, login skips binding, unbind disconnects',
      () async {
    await watch.connect(kWsWatchSimDeviceId);
    final id = watch.userId;
    await watch.disconnect();
    stages.clear();
    await watch.connect(kWsWatchSimDeviceId);
    expect(watch.userId, id);
    expect(stages, isNot(contains(WSConnectionState.awaitingConfirm)));
    await watch.unbind();
    expect(device.boundUserId, isNull);
    expect(watch.state, WSConnectionState.disconnected);
  });
  for (final result in [1, 2, null]) {
    test('binding failure $result never publishes ready', () async {
      device.bindResult = result;
      await expectLater(
          watch.connect(kWsWatchSimDeviceId),
          throwsA(isA<WSConnectException>().having(
              (e) => e.reason,
              'reason',
              result == 2
                  ? WSConnectFailure.confirmRejected
                  : WSConnectFailure.confirmTimeout)));
      expect(watch.state, WSConnectionState.disconnected);
      expect(watch.deviceInfo, isNull);
      expect(stages, isNot(contains(WSConnectionState.ready)));
      final rows = await store.database.select(store.database.devices).get();
      expect(rows.single.deviceInfoRaw, isNull);
    });
  }
  test('initialization failure retains identity for retry', () async {
    device.failInitializationKey = 0x31;
    await expectLater(
        watch.connect(kWsWatchSimDeviceId,
            userId: 'explicit-before-init-failure'),
        throwsA(isA<WSConnectException>()));
    final uid = device.boundUserId;
    device.failInitializationKey = null;
    await watch.connect(kWsWatchSimDeviceId);
    expect(watch.userId, uid);
  });
  test('cancel confirmation prevents late bind and supports retry', () async {
    final waiting = watch.stateChanges
        .firstWhere((e) => e.current == WSConnectionState.awaitingConfirm);
    final pending = expectLater(
        watch.connect(kWsWatchSimDeviceId), throwsA(isA<WSConnectException>()));
    await waiting;
    await watch.disconnect();
    await pending;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(device.boundUserId, isNull);
    expect(stages, isNot(contains(WSConnectionState.ready)));
    await watch.connect(kWsWatchSimDeviceId);
    expect(watch.state, WSConnectionState.ready);
  });
  test('same device lease prevents concurrent connection', () async {
    await watch.connect(kWsWatchSimDeviceId);
    final other = create(config);
    try {
      await expectLater(other.connect(kWsWatchSimDeviceId),
          throwsA(isA<WSConnectException>()));
      await watch.disconnect();
      await other.connect(kWsWatchSimDeviceId, userId: 'another-user');
      expect(device.boundUserId, 'another-user');
    } finally {
      await other.dispose();
    }
  });
  test('link loss reconnects; explicit disconnect stops retries', () async {
    await watch.dispose();
    await store.close();
    store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    watch =
        create(const WSConfig(simulationEnabled: true, autoReconnect: true));
    await watch.connect(kWsWatchSimDeviceId);
    final again = watch.stateChanges
        .firstWhere((e) => e.current == WSConnectionState.ready);
    await transports.last.close();
    await again.timeout(const Duration(seconds: 3));
    expect(transports.length, 2);
    await watch.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(transports.length, 2);
  });
  test('late factory result is disposed after cancellation', () async {
    await watch.dispose();
    await store.close();
    store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    final gate = Completer<WSManagedTransport>();
    final opened = Completer<void>();
    watch = runZoned(() => WSWatch(config: config), zoneValues: {
      wsEnvironmentZoneKey: WSConnectionEnvironment(
          openTransport: (_, __) {
            opened.complete();
            return gate.future;
          },
          openStore: (_) async => store)
    });
    final pending = expectLater(
        watch.connect(kWsWatchSimDeviceId), throwsA(isA<WSConnectException>()));
    await opened.future;
    await watch.disconnect();
    await pending;
    var released = false;
    final t = await WSConnectionEnvironment.openSimulator(config, device);
    gate.complete(WSManagedTransport(t.connection, release: () async {
      released = true;
      await t.close();
    }));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(released, isTrue);
    expect(watch.state, WSConnectionState.disconnected);
  });
  test('simulator scanning is opt in and does not need BLE', () async {
    final s = WSWatch.scanner(config: config);
    await s.start(includeRealDevices: false);
    expect(s.devices.single.deviceId, kWsWatchSimDeviceId);
    await s.stop();
    await s.dispose();
    final disabled = WSWatch.scanner();
    await disabled.start(includeRealDevices: false);
    expect(disabled.devices, isEmpty);
    await disabled.dispose();
  });
  test('raw is rejected during handshake and works only after ready', () async {
    final waiting = watch.stateChanges
        .firstWhere((e) => e.current == WSConnectionState.awaitingConfirm);
    final connecting = watch.connect(kWsWatchSimDeviceId);
    await waiting;
    final raw =
        WSRawRequest(cmd: 2, version: 0, key: 3, settingOpcode: 0, data: [9]);
    await expectLater(watch.debug.sendRaw(raw),
        throwsA(isA<WSSessionInvalidatedException>()));
    await connecting;
    await watch.debug.sendRaw(raw);
    await watch.disconnect();
    await expectLater(watch.debug.sendRaw(raw),
        throwsA(isA<WSSessionInvalidatedException>()));
  });

  test('dispose while binding cancels confirmation and rejects future connect',
      () async {
    final waiting = watch.stateChanges
        .firstWhere((e) => e.current == WSConnectionState.awaitingConfirm);
    final pending = expectLater(
        watch.connect(kWsWatchSimDeviceId), throwsA(isA<WSConnectException>()));
    await waiting;
    await watch.dispose();
    await pending;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(device.boundUserId, isNull);
    await expectLater(watch.connect(kWsWatchSimDeviceId),
        throwsA(isA<WSDisposedException>()));
    await watch.dispose();
  });

  test('storage opening failure does not poison the next attempt', () async {
    await watch.dispose();
    var attempts = 0;
    watch = runZoned(() => WSWatch(config: config), zoneValues: {
      wsEnvironmentZoneKey: WSConnectionEnvironment(
          openTransport: (_, c) =>
              WSConnectionEnvironment.openSimulator(c, device),
          openStore: (_) async {
            if (attempts++ == 0) throw StateError('disk unavailable');
            return store;
          }),
    });
    await expectLater(
        watch.connect(kWsWatchSimDeviceId),
        throwsA(isA<WSConnectException>().having(
            (e) => e.reason, 'reason', WSConnectFailure.storageFailed)));
    await watch.connect(kWsWatchSimDeviceId);
    expect(watch.state, WSConnectionState.ready);
  });

  test('scanner timeout finishes and permits a new scan', () async {
    final scanner = WSWatch.scanner(config: config);
    await scanner.start(
        includeRealDevices: false, timeout: const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(scanner.isScanning, isFalse);
    await scanner.start(includeRealDevices: false);
    await Future.wait([scanner.stop(), scanner.stop()]);
    await scanner.dispose();
  });

  test(
      'stalled native identity load reports storage step and never opens transport',
      () async {
    await watch.dispose();
    final identity = Completer<String>();
    final blocked = _BlockedIdentityStore(store, identity.future);
    watch = runZoned(
        () => WSWatch(
            config: const WSConfig(
                simulationEnabled: true,
                connectTimeouts:
                    WSConnectTimeouts(connecting: Duration(milliseconds: 20)))),
        zoneValues: {
          wsEnvironmentZoneKey: WSConnectionEnvironment(
              openStore: (_) async => blocked,
              openTransport: (_, c) async {
                final transport =
                    await WSConnectionEnvironment.openSimulator(c, device);
                transports.add(transport);
                return transport;
              }),
        });
    await expectLater(
        watch.connect(kWsWatchSimDeviceId),
        throwsA(isA<WSConnectException>()
            .having((e) => e.stage, 'stage', WSConnectionState.connecting)
            .having((e) => e.reason, 'reason', WSConnectFailure.timeout)
            .having((e) => e.message, 'pending step',
                contains('loading persisted user identity'))));
    expect(transports, isEmpty);
    identity.complete('late-identity');
    await Future<void>.delayed(Duration.zero);
    expect(transports, isEmpty);
  });

  test('user id rejects invalid wire values', () {
    for (final value in ['', '中', 'a\u0000b', 'a' * 33]) {
      expect(() => WSUserId(value), throwsArgumentError);
    }
  });
}

class _BlockedIdentityStore implements WSDeviceStore {
  _BlockedIdentityStore(this.delegate, this.identity);
  final WSDeviceStore delegate;
  final Future<String> identity;
  @override
  Future<String> defaultUserId(String deviceId) => identity;
  @override
  Future<void> rememberUserId(String deviceId, String userId) =>
      delegate.rememberUserId(deviceId, userId);
  @override
  Future<void> saveReady(String deviceId, String userId, WSDeviceInfo info,
          WSCapabilities capabilities) =>
      delegate.saveReady(deviceId, userId, info, capabilities);
  @override
  Future<void> close() => delegate.close();
}
