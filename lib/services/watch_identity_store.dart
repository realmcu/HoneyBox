import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'watch_bind_protocol.dart';

/// Persists the 32-byte ASCII HoneyProtocol user identifier.
class WatchIdentityStore {
  WatchIdentityStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'honeyprotocol.watch.user_id';
  static final _valid = RegExp(r'^[0-9a-f]{32}$');
  static Future<Uint8List>? _inflight;

  final FlutterSecureStorage _storage;

  Future<Uint8List> loadOrCreate() {
    return _inflight ??= _loadOrCreate().whenComplete(() => _inflight = null);
  }

  Future<Uint8List> _loadOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && _valid.hasMatch(existing)) {
      return Uint8List.fromList(existing.codeUnits);
    }

    final generated = WatchBindProtocol.generateUserId();
    await _storage.write(key: _key, value: String.fromCharCodes(generated));
    return generated;
  }
}
