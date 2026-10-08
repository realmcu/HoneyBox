import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';
import '../../helpers/jw_fixture.dart';

void main() {
  late Directory dir;
  late FakeJwTransport t;
  late JwIdentityStore store;
  late JwDeviceRepository repo;
  Future<void> create(
      {int login = 0,
      int bind = 0,
      String functions = '4dd17dfce34ad83d',
      int language = 0,
      int? readback,
      bool early = false,
      bool corrupt = false,
      bool failRead = false}) async {
    t = FakeJwTransport()..failRead = failRead;
    installJwDeviceScript(t,
        loginResult: login,
        bindResult: bind,
        functions: functions,
        language: language,
        readbackLanguage: readback,
        earlySample: early);
    final file = File('${dir.path}/identity.json');
    if (corrupt) await file.writeAsString('broken');
    store = JwIdentityStore(file);
    repo = JwDeviceRepository(
        session: JwSession(t,
            ackTimeout: const Duration(milliseconds: 20),
            replyTimeout: const Duration(milliseconds: 30)),
        identityStore: store,
        transport: t);
    addTearDown(() async {
      await repo.dispose();
      await t.dispose();
    });
    await repo.initialize();
  }

  List<JwMessage> requests() => t.sent
      .where((f) => !f.ack)
      .map((f) => JwCodec.decodeL2(f.payload))
      .toList();
  List<JwMessage> keys(int cmd, int key) => requests()
      .where((m) => m.command == cmd && m.fields.single.key == key)
      .toList();
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw_repo_');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('ordinary initialization read failure ends loading and disables writes',
      () async {
    await create(failRead: true);
    expect(repo.state.phase, JwDevicePhase.failed);
    expect(repo.state.operationInProgress, isFalse);
    expect(repo.state.canWrite, isFalse);
    expect(repo.state.operationError, contains('GATT read failed'));
    expect(requests(), isEmpty);
  });
  test('negative time ACK cannot publish submitted success', () async {
    await create();
    await Future<void>.delayed(Duration.zero);
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (f.ack) return;
      final nack = JwCodec.encode(seq: f.seq, payload: Uint8List(0), ack: true)
        ..[1] = 0x30;
      t.rx.add(nack);
    };
    await expectLater(
        repo.syncTime(DateTime(2026, 10, 4)),
        throwsA(
            isA<JwLinkException>().having((e) => e.stage, 'stage', 'nack')));
    expect(repo.state.timeSubmitted, isFalse);
    expect(repo.state.phase, JwDevicePhase.failed);
    expect(repo.state.canWrite, isFalse);
    expect(keys(2, 1), hasLength(3));
  });
  test('idle notification ACK failure clears heart and disables controls',
      () async {
    await create(early: true);
    await repo.setHeartRateStreaming(true);
    await Future<void>.delayed(Duration.zero);
    expect(repo.state.lastHeartRate!.bpm, 72);
    final changes = <JwDeviceState>[];
    final sub = repo.changes.listen(changes.add);
    addTearDown(sub.cancel);
    t.failWrite = true;
    t.emitMessage(5, 0x0f, jwHex('3543000104881f49'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.session.isOpen, isFalse);
    expect(repo.state.phase, JwDevicePhase.failed);
    expect(repo.state.operationError, contains('ACK write failed'));
    expect(repo.state.canWrite, isFalse);
    expect(repo.state.heartRateStreaming, isFalse);
    expect(repo.state.lastHeartRate, isNull);
    expect(repo.state.operationInProgress, isFalse);
    expect(changes.where((s) => s.phase == JwDevicePhase.failed), hasLength(1));
    await expectLater(repo.syncTime(DateTime(2026)), throwsStateError);
    expect(keys(2, 1), isEmpty);
  });
  test('fresh identity logs in by actual reply and reuses exact 32 bytes',
      () async {
    await create();
    expect(repo.state.phase, JwDevicePhase.loggedIn);
    expect(repo.state.info!.firmware, 'T005');
    expect(repo.state.info!.battery, 70);
    expect(repo.state.capabilities!.rawHex, '4dd17dfce34ad83d');
    final identity = await store.loadOrCreate();
    await repo.login();
    expect(keys(3, 3), hasLength(2));
    for (final m in keys(3, 3)) {
      expect(m.fields.single.value, identity.wireUserId);
      expect(m.fields.single.value, hasLength(32));
    }
    expect(keys(3, 1), isEmpty);
  });
  test(
      'login refusal retains information and unsolicited success cannot unlock',
      () async {
    await create(login: 1);
    expect(repo.state.phase, JwDevicePhase.loginRejected);
    expect(repo.state.info!.name, 'S200');
    t.emitMessage(3, 4, Uint8List.fromList([0]));
    await Future<void>.delayed(Duration.zero);
    expect(repo.state.phase, JwDevicePhase.loginRejected);
    expect(keys(3, 1), isEmpty);
    await expectLater(repo.syncTime(DateTime(2026, 10, 3)), throwsStateError);
    expect(keys(2, 1), isEmpty);
  });
  test('identity failure leaves readable device without login or bind',
      () async {
    await create(corrupt: true);
    expect(repo.state.phase, JwDevicePhase.identityUnavailable);
    expect(repo.state.capabilities, isNotNull);
    expect(keys(3, 3), isEmpty);
    expect(keys(3, 1), isEmpty);
  });
  test('missing serial is not fabricated and does not block protocol login',
      () async {
    await create();
    await repo.dispose();
    t = FakeJwTransport();
    installJwDeviceScript(t);
    t.readValues.remove('2a25');
    repo = JwDeviceRepository(
        session: JwSession(t), identityStore: store, transport: t);
    await repo.initialize();
    expect(repo.state.info!.deviceKey, isEmpty);
    expect(repo.state.phase, JwDevicePhase.loggedIn);
  });
  test('first bind requires confirmation and uses persisted identity once',
      () async {
    await create(login: 1);
    await expectLater(
        repo.bindFirstTime(confirmedFirstBind: false), throwsStateError);
    expect(keys(3, 1), isEmpty);
    await repo.bindFirstTime(confirmedFirstBind: true);
    expect(repo.state.phase, JwDevicePhase.loggedIn);
    expect(keys(3, 1).single.fields.single.value,
        (await store.loadOrCreate()).wireUserId);
    await expectLater(
        repo.bindFirstTime(confirmedFirstBind: true), throwsStateError);
    expect(keys(3, 1), hasLength(1));
  });
  test('bind rejection cannot enable writes', () async {
    await create(login: 1, bind: 1);
    await expectLater(repo.bindFirstTime(confirmedFirstBind: true),
        throwsA(isA<JwLoginException>()));
    expect(repo.state.phase, JwDevicePhase.loginRejected);
    expect(repo.state.operationInProgress, isFalse);
  });
  test('capability gating rejects unsupported writes before sending', () async {
    await create(functions: '0000000000000000');
    await expectLater(repo.setLanguageVerified(1), throwsStateError);
    await expectLater(repo.setHeartRateStreaming(true), throwsStateError);
    expect(keys(2, 0x4e), isEmpty);
    expect(keys(5, 0x19), isEmpty);
  });
  test('language is read back; mismatch stays visible as failure', () async {
    await create(readback: 0);
    await expectLater(repo.setLanguageVerified(1), throwsStateError);
    expect(repo.state.language, 0);
    expect(repo.state.operationError, contains('readback'));
    expect(keys(2, 0x4e), hasLength(1));
    expect(keys(2, 0x4f), hasLength(2));
  });
  test('unknown language remains raw and cannot be overwritten', () async {
    await create(language: 7);
    expect(repo.state.language, 7);
    await expectLater(repo.setLanguageVerified(1), throwsStateError);
    expect(keys(2, 0x4e), isEmpty);
  });
  test('time submission is ACK evidence and language readback succeeds',
      () async {
    await create();
    await repo.syncTime(DateTime(2026, 10, 3, 19, 20, 30));
    expect(repo.state.timeSubmitted, isTrue);
    expect(keys(2, 1).single.fields.single.value, jwHex('6a87351e'));
    await repo.setLanguageVerified(2);
    expect(repo.state.language, 2);
    expect(repo.state.operationInProgress, isFalse);
  });
  test(
      'early heart sample is published only with confirmed start, stop clears it',
      () async {
    await create(early: true);
    await repo.setHeartRateStreaming(true);
    expect(repo.state.heartRateStreaming, isTrue);
    expect(repo.state.lastHeartRate!.bpm, 72);
    t.emitMessage(5, 0x28, jwHex('35430001aabbccdd04881f49'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.state.lastHeartRate!.bpm, 73);
    await repo.setHeartRateStreaming(false);
    expect(repo.state.heartRateStreaming, isFalse);
    expect(repo.state.lastHeartRate, isNull);
    t.emitMessage(5, 0x0f, jwHex('3543000104881e48'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.state.lastHeartRate, isNull);
  });
  test(
      'timeout cancels operation, disconnect clears state and no control replay',
      () async {
    await create();
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (!f.ack) t.emitAck(f.seq);
    };
    await expectLater(
        repo.setHeartRateStreaming(true), throwsA(isA<JwLinkException>()));
    expect(repo.state.operationInProgress, isFalse);
    expect(repo.state.heartRateStreaming, isFalse);
    expect(keys(5, 0x19), hasLength(1));
    t.emitDisconnect();
    expect(repo.state.phase, JwDevicePhase.disconnected);
    await expectLater(repo.syncTime(DateTime(2026)), throwsStateError);
    final prohibited = requests().where((m) =>
        (m.command == 3 && m.fields.single.key == 5) ||
        (m.command == 5 && [1, 0x1c].contains(m.fields.single.key)));
    expect(prohibited, isEmpty);
  });
}
