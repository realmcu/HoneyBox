import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/storage/jw_database.dart';
import 'support/fake_connection.dart';

Future<void> turn() => Future<void>.delayed(Duration.zero);
void main() {
  late JWHistoryStore store;
  late FakeTransport transport;
  late JWWatch watch;
  setUp(() async {
    store = JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));
    transport = FakeTransport();
    watch = JWWatch(
        transport: transport, historyStore: store, maxConnectedDevices: 2);
    await watch.initialize();
  });
  tearDown(() async {
    for (final c in transport.connections) {
      c.failDispose = false;
      if (c.disposeGate != null && !c.disposeGate!.isCompleted) {
        c.disposeGate!.complete();
      }
      if (c.connectGate != null && !c.connectGate!.isCompleted) {
        c.connectGate!.complete();
      }
    }
    await watch.dispose();
    await store.dispose();
  });

  test('attached object limit is separate from connection capacity', () async {
    final limited = JWWatch(
        transport: FakeTransport(),
        historyStore: store,
        maxAttachedSessions: 1);
    await limited.initialize();
    final a = await limited.openSession('a');
    expect(limited.createSession('a'), same(a));
    await expectLater(
        limited.openSession('b'),
        throwsA(isA<JWException>()
            .having((e) => e.code, 'code', JWErrorCode.sessionLimit)));
    await limited.closeSession('a');
    await limited.openSession('b');
    await limited.dispose();
  });

  test('Hub stream supports closing a session from its state callback',
      () async {
    final a = await watch.openSession('a');
    final closed = Completer<void>();
    final subscription = watch.attachedSessions.listen((entries) {
      if (entries.any((entry) => entry.state.isConnected && !entry.isClosing)) {
        watch.closeSession('a').then((_) {
          if (!closed.isCompleted) closed.complete();
        });
      }
    });
    await a.connect();
    await closed.future;
    await subscription.cancel();
    expect(watch.attachedSessionsSnapshot, isEmpty);
  });

  test('canonical ID, concurrent opens and legacy create share one instance',
      () async {
    final sessions = await Future.wait(
        [watch.openSession(' AA:BB '), watch.openSession('aa:bb')]);
    expect(identical(sessions[0], sessions[1]), isTrue);
    expect(watch.createSession('Aa:Bb'), same(sessions[0]));
    expect(transport.connections, hasLength(1));
    expect(sessions[0].state.phase, JWSessionPhase.idle);
    expect(watch.attachedSessionsSnapshot.single.deviceId, 'AA:BB');
    expect(sessions[0].connection.target.deviceId, 'AA:BB');
  });

  test('two connections coexist, limit counts connecting and releases on close',
      () async {
    final a = await watch.openSession('a');
    final b = await watch.openSession('b');
    final c = await watch.openSession('c');
    transport.connections[0].connectGate = Completer<void>();
    final openingA = a.connect();
    await b.connect();
    await expectLater(
        c.connect(),
        throwsA(isA<JWException>()
            .having((e) => e.code, 'code', JWErrorCode.sessionLimit)));
    transport.connections[0].connectGate!.complete();
    await openingA;
    await watch.closeSession('a');
    await c.connect();
    expect(b.state.isConnected, isTrue);
    expect(watch.sessionOf('a'), isNull);
    expect(watch.sessionOf('c'), same(c));
  });

  test('close then reopen waits for cleanup and creates a new generation',
      () async {
    final old = await watch.openSession('a');
    await old.connect();
    final gate = transport.connections.single.disposeGate = Completer<void>();
    final closing = watch.closeSession('a');
    final opening = watch.openSession('a');
    expect(watch.sessionOf('a'), isNull);
    expect(watch.attachedSessionsSnapshot.single.isClosing, isTrue);
    expect(transport.connections, hasLength(1));
    gate.complete();
    await closing;
    final next = await opening;
    expect(next, isNot(same(old)));
    await expectLater(old.connect(), throwsA(isA<JWException>()));
    await next.connect();
    expect(watch.sessionOf('a'), same(next));
  });

  test('direct disposal and remote disconnect retire only their own entry',
      () async {
    final a = await watch.openSession('a');
    final b = await watch.openSession('b');
    await Future.wait([a.connect(), b.connect()]);
    await a.dispose();
    await turn();
    expect(watch.sessionOf('a'), isNull);
    transport.connections[1].remoteDisconnect();
    await turn();
    await watch.closeSession('b');
    final next = await watch.openSession('b');
    expect(next, isNot(same(b)));
    await next.connect();
  });

  test('failed connect retires entry and allows retry with a fresh connection',
      () async {
    transport.configure = (c) => c.failConnect = true;
    final old = await watch.openSession('a');
    await expectLater(old.connect(), throwsStateError);
    await turn();
    transport.configure = null;
    final next = await watch.openSession('a');
    expect(next, isNot(same(old)));
    await next.connect();
  });

  test('close during connect never resurrects disposed state', () async {
    final session = await watch.openSession('a');
    final gate = transport.connections.single.connectGate = Completer<void>();
    final opening = session.connect();
    final check = expectLater(opening, throwsA(anything));
    final closing = watch.closeSession('a');
    gate.complete();
    await Future.wait([closing, check]);
    expect(session.state.phase, JWSessionPhase.disposed);
    expect(watch.attachedSessionsSnapshot, isEmpty);
  });

  test('batch attempts all, retains failed cleanup and blocks new opens',
      () async {
    final a = await watch.openSession('a');
    final b = await watch.openSession('b');
    await Future.wait([a.connect(), b.connect()]);
    transport.connections[0].failDispose = true;
    final gate = transport.connections[1].disposeGate = Completer<void>();
    final close = watch.closeAllSessions();
    final check = expectLater(
        close,
        throwsA(isA<JWSessionCloseException>()
            .having((e) => e.failures.keys, 'devices', ['a'])));
    await expectLater(watch.openSession('c'), throwsA(isA<JWException>()));
    gate.complete();
    await check;
    expect(watch.attachedSessionsSnapshot.single.closeError, isNotNull);
    expect(watch.attachedSessionsSnapshot.single.deviceId, 'a');
    transport.connections[0].failDispose = false;
    await watch.closeAllSessions();
    expect(watch.attachedSessionsSnapshot, isEmpty);
  });

  test('watch disposal closes all sessions before releasing owned resources',
      () async {
    final a = await watch.openSession('a');
    final b = await watch.openSession('b');
    await Future.wait([a.connect(), b.connect()]);
    await watch.dispose();
    expect(a.state.phase, JWSessionPhase.disposed);
    expect(b.state.phase, JWSessionPhase.disposed);
    await expectLater(watch.openSession('c'), throwsStateError);
    expect(watch.isInitialized, isFalse);
  });
}
