import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw-id-test-');
    file = File('${dir.path}/jw_identity_v1.json');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
      'first creation persists exactly 32 ASCII bytes and new instance reuses it',
      () async {
    final a = await JwIdentityStore(file,
            randomBytes: (n) => Uint8List.fromList(List.generate(n, (i) => i)))
        .loadOrCreate();
    final b = await JwIdentityStore(file).loadOrCreate();
    expect(a.userId, '000102030405060708090a0b0c0d0e0f');
    expect(a.wireUserId.length, 32);
    expect(b.wireUserId, a.wireUserId);
    expect(jsonDecode(await file.readAsString()),
        {'version': 1, 'userId': a.userId});
    expect(await dir.list().where((e) => e.path.endsWith('.tmp')).length, 0);
  });
  test('concurrent stores including normalized aliases generate one identifier',
      () async {
    var generated = 0;
    Uint8List random(int n) {
      generated++;
      return Uint8List.fromList(List.filled(n, generated));
    }

    final stores = List.generate(
        10,
        (i) => JwIdentityStore(
            File('${dir.path}/${i.isEven ? './' : ''}jw_identity_v1.json'),
            randomBytes: random));
    final values = await Future.wait(stores.map((s) => s.loadOrCreate()));
    expect(generated, 1);
    expect(values.map((v) => v.userId).toSet().length, 1);
  });
  test(
      'corruption after successful load is detected rather than hidden by a cache',
      () async {
    final store = JwIdentityStore(file);
    await store.loadOrCreate();
    await file.writeAsString('{broken');
    await expectLater(
        store.loadOrCreate(), throwsA(isA<JwIdentityException>()));
    expect(await file.readAsString(), '{broken');
  });
  test(
      'bad JSON, version, length and non-ASCII values never regenerate or overwrite',
      () async {
    for (final text in [
      'not json',
      jsonEncode({'version': 2, 'userId': '0' * 32}),
      jsonEncode({'version': 1, 'userId': '0' * 31}),
      jsonEncode({'version': 1, 'userId': '中' * 32})
    ]) {
      await file.writeAsString(text);
      var generated = false;
      await expectLater(
          JwIdentityStore(file, randomBytes: (n) {
            generated = true;
            return Uint8List(n);
          }).loadOrCreate(),
          throwsA(isA<JwIdentityException>()));
      expect(generated, isFalse);
      expect(await file.readAsString(), text);
    }
  });
  test(
      'unwritable parent and invalid entropy fail without a partial identifier',
      () async {
    final parent = File('${dir.path}/blocked');
    await parent.writeAsString('original');
    await expectLater(
        JwIdentityStore(File('${parent.path}/id.json')).loadOrCreate(),
        throwsA(isA<JwIdentityException>()));
    expect(await parent.readAsString(), 'original');
    await expectLater(
        JwIdentityStore(file, randomBytes: (n) => Uint8List(15)).loadOrCreate(),
        throwsA(isA<JwIdentityException>()));
    expect(await file.exists(), isFalse);
  });
  test(
      'lock failure preserves the existing identifier and exposes no complete ID',
      () async {
    const original = 'abcdef0123456789abcdef0123456789';
    await file.writeAsString(jsonEncode({'version': 1, 'userId': original}));
    await Directory('${dir.path}/jw_identity_v1.lock').create();
    try {
      await JwIdentityStore(file).loadOrCreate();
      fail('Lock acquisition should fail');
    } on JwIdentityException catch (e) {
      expect(e.toString(), isNot(contains(original)));
    }
    expect(jsonDecode(await file.readAsString())['userId'], original);
  });
  test('Windows exclusive lock cannot be bypassed by another handle', () async {
    final lock = await File('${dir.path}/jw_identity_v1.lock')
        .open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    try {
      await expectLater(JwIdentityStore(file).loadOrCreate(),
          throwsA(isA<JwIdentityException>()));
      expect(await file.exists(), isFalse);
    } finally {
      await lock.unlock();
      await lock.close();
    }
    expect((await JwIdentityStore(file).loadOrCreate()).wireUserId.length, 32);
  }, skip: !Platform.isWindows);
}
