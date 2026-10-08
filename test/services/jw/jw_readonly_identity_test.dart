import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw_existing_');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test('loadExisting cannot create missing identity or sidecar', () async {
    final dynamic store = JwIdentityStore(File('${dir.path}/id.json'));
    await expectLater(
        store.loadExisting() as Future, throwsA(isA<JwIdentityException>()));
    expect(await dir.list().toList(), isEmpty);
  });
  test('loadExisting returns exact persisted record without random allocation',
      () async {
    final file = File('${dir.path}/id.json');
    await file.writeAsString(
        '{"version":1,"userId":"0123456789abcdef0123456789abcdef"}');
    final dynamic store = JwIdentityStore(file,
        randomBytes: (_) => throw StateError('no create'));
    expect((await store.loadExisting()).userId,
        '0123456789abcdef0123456789abcdef');
    expect(await dir.list().toList(), hasLength(1));
  });
  for (final present in [false, true]) {
    test(
        'initialization rejects ${present ? 'changed' : 'missing'} identity before login',
        () async {
      final file = File('${dir.path}/id.json');
      if (present) {
        await file.writeAsString('{"version":1,"userId":"${'1' * 32}"}');
      }
      final t = FakeJwTransport();
      installJwDeviceScript(t);
      final repository = JwDeviceRepository(
          session: JwSession(t),
          identityStore: JwIdentityStore(file),
          transport: t);
      addTearDown(() async {
        await repository.dispose();
        await t.dispose();
      });
      final dynamic r = repository;
      await r.initialize(
          expectedExistingIdentitySha256:
              sha256.convert(('0' * 32).codeUnits).toString());
      expect(repository.state.phase, JwDevicePhase.identityUnavailable);
      expect(
          t.sent
              .where((f) => !f.ack)
              .map((f) => JwCodec.decodeL2(f.payload))
              .where((m) => m.command == 3),
          isEmpty);
      expect(await file.exists(), present);
    });
  }
}
