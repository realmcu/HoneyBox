import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../helpers/fake_jw_transport.dart';
import '../helpers/jw_device_script.dart';

void main() {
  late Directory dir;
  late FakeJwTransport t;
  late JwDeviceNotifier n;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw_notifier_');
    t = FakeJwTransport();
    installJwDeviceScript(t);
    n = JwDeviceNotifier(
        repository: JwDeviceRepository(
            session: JwSession(t),
            identityStore: JwIdentityStore(File('${dir.path}/id.json')),
            transport: t));
  });
  tearDown(() async {
    n.dispose();
    await Future<void>.delayed(Duration.zero);
    await t.dispose();
    await dir.delete(recursive: true);
  });
  test('idle notification stream failure reaches notifier without an action',
      () async {
    await n.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(n.state.phase, JwDevicePhase.loggedIn);
    t.rx.addError(StateError('notification channel failed'));
    await Future<void>.delayed(Duration.zero);
    expect(n.state.phase, JwDevicePhase.failed);
    expect(n.state.operationError, contains('Notification stream failed'));
    expect(n.state.canWrite, isFalse);
    expect(n.state.operationInProgress, isFalse);
    expect(n.state.heartRateStreaming, isFalse);
    expect(n.state.lastHeartRate, isNull);
    final writes = t.writes.length;
    await n.syncTime(DateTime(2026));
    expect(t.writes, hasLength(writes));
    expect(n.state.operationError, contains('Notification stream failed'));
  });
  test('initialize once and duplicate operations cannot write twice', () async {
    await Future.wait([n.initialize(), n.initialize()]);
    expect(n.state.phase, JwDevicePhase.loggedIn);
    final gate = t.onWrite;
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (!f.ack && JwCodec.decodeL2(f.payload).command == 5) return;
      gate!(bytes);
    };
    final op = n.setHeartRateStreaming(true);
    await n.setHeartRateStreaming(true);
    final sent = t.sent
        .where((f) => !f.ack)
        .map((f) => JwCodec.decodeL2(f.payload))
        .where((m) => m.command == 5)
        .toList();
    expect(sent, hasLength(1));
    t.emitAck(t.sent.where((f) => !f.ack).last.seq);
    t.emitMessage(5, 0x1a, sent.single.fields.single.value);
    await op;
    expect(n.state.heartRateStreaming, isTrue);
  });
  test(
      'dispose while reply pending cancels session without late notifier state',
      () async {
    await n.initialize();
    t.onWrite = (_) {};
    final op = n.setHeartRateStreaming(true);
    n.dispose();
    await op;
    await n.repository!.dispose();
    expect(t.connected, isFalse);
  });
}
