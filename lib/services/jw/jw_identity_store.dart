import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class JwIdentityException implements Exception {
  final String message;
  const JwIdentityException(this.message);
  @override
  String toString() => 'JW identifier: $message';
}

class JwIdentityRecord {
  final String userId;
  final Uint8List wireUserId;
  JwIdentityRecord._(this.userId)
      : wireUserId = Uint8List.fromList(userId.codeUnits).asUnmodifiableView();
}

/// An installation's protocol string, not a device ownership/authorization list.
class JwIdentityStore {
  final File file;
  final Uint8List Function(int) _randomBytes;
  static final _inflight = <String, Future<JwIdentityRecord>>{};
  JwIdentityStore(this.file, {Uint8List Function(int length)? randomBytes})
      : _randomBytes = randomBytes ?? _secureBytes;
  static Uint8List _secureBytes(int n) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => random.nextInt(256)));
  }

  Future<JwIdentityRecord> loadOrCreate() {
    var key = file.absolute.uri.normalizePath().toString();
    if (Platform.isWindows) key = key.toLowerCase();
    return _inflight.putIfAbsent(
        key,
        () => _load().whenComplete(() {
              _inflight.remove(key);
            }));
  }

  /// Reads only; missing files never allocate a replacement identity or lock file.
  Future<JwIdentityRecord> loadExisting() async {
    try {
      return _decode(await file.readAsString());
    } on FileSystemException {
      throw const JwIdentityException('Existing identifier unavailable');
    }
  }

  JwIdentityRecord _decode(String text) {
    try {
      final value = jsonDecode(text);
      if (value is! Map ||
          value['version'] != 1 ||
          value['userId'] is! String ||
          !RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(value['userId'] as String)) {
        throw const JwIdentityException('Stored identifier format is invalid');
      }
      return JwIdentityRecord._(value['userId'] as String);
    } on FormatException {
      // Never echo JSON fragments containing an existing identifier.
      throw const JwIdentityException('Stored identifier JSON is corrupt');
    }
  }

  Future<JwIdentityRecord> _load() async {
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
      if (bytes.length != 16) {
        throw const JwIdentityException('Invalid random byte count');
      }
      final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      temporary = File(
          '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await temporary.writeAsString(jsonEncode({'version': 1, 'userId': id}),
          flush: true);
      await temporary.rename(file.path);
      temporary = null;
      return JwIdentityRecord._(id);
    } on JwIdentityException {
      rethrow;
    } on FileSystemException {
      throw const JwIdentityException(
          'Cannot lock, read or save the identifier file');
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
}
