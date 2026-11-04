import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'jw_identity.dart';

/// Persistent JW installation identity. Applications choose the file location.
final class JWIdentityStore {
  JWIdentityStore(this.file, {Uint8List Function(int)? randomBytes})
      : _randomBytes = randomBytes ?? _secureBytes;

  final File file;
  final Uint8List Function(int) _randomBytes;
  static final _inflight = <String, Future<JWIdentity>>{};

  Future<JWIdentity> loadOrCreate() {
    final key = file.absolute.uri.normalizePath().toString();
    final existing = _inflight[key];
    if (existing != null) return existing;

    final future = _loadOrCreate();
    _inflight[key] = future;
    future.then(
      (_) => _removeInflight(key, future),
      onError: (_, __) => _removeInflight(key, future),
    );
    return future;
  }

  static void _removeInflight(String key, Future<JWIdentity> future) {
    if (identical(_inflight[key], future)) _inflight.remove(key);
  }

  /// Reads an existing identity only; never silently replaces it.
  Future<JWIdentity> loadExisting() async {
    try {
      return _decode(await file.readAsString());
    } on FileSystemException {
      throw StateError('JW identity is unavailable');
    }
  }

  Future<JWIdentity> _loadOrCreate() async {
    RandomAccessFile? lock;
    File? temporary;
    var locked = false;
    try {
      await file.parent.create(recursive: true);
      final lockPath = file.path.endsWith('.json')
          ? '${file.path.substring(0, file.path.length - 5)}.lock'
          : '${file.path}.lock';
      lock = await File(lockPath).open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      locked = true;
      if (await file.exists()) return _decode(await file.readAsString());
      final bytes = _randomBytes(16);
      if (bytes.length != 16) throw StateError('Invalid JW identity entropy');
      final identity = JWIdentity(
          bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join());
      temporary =
          File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await temporary.writeAsString(
          jsonEncode({'version': 1, 'userId': identity.value}),
          flush: true);
      await temporary.rename(file.path);
      temporary = null;
      return identity;
    } on FileSystemException {
      throw StateError('Cannot read or store JW identity');
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      if (lock != null) {
        try {
          if (locked) await lock.unlock();
        } finally {
          await lock.close();
        }
      }
    }
  }

  JWIdentity _decode(String source) {
    try {
      final value = jsonDecode(source);
      if (value is! Map ||
          value['version'] != 1 ||
          value['userId'] is! String) {
        throw const FormatException('JW identity record');
      }
      return JWIdentity(value['userId'] as String);
    } on FormatException {
      throw StateError('JW identity record is malformed');
    }
  }

  static Uint8List _secureBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => random.nextInt(256)));
  }
}
