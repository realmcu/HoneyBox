import 'dart:async';

import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import '../storage/jw_history_store.dart';
import 'jw_scan_device.dart';
import 'jw_session.dart';

/// Public JW entry point. It owns scanning, the JW health database, and every
/// [JWWatchSession] owns one single-use connection and must be disposed by its
/// caller.
final class JWWatch {
  /// Optional override for the on-disk database file. When omitted,
  /// [initialize] creates `jw_watch.db` under the application support directory.
  ///
  /// Optional pre-opened store, intended for unit tests. Production apps should
  /// leave this null so [initialize] owns the default database lifecycle.
  JWWatch({
    WatchBleScanner? scanner,
    WatchTransport? transport,
    String? historyDatabasePath,
    JWHistoryStore? historyStore,
  })  : _historyDatabasePath = historyDatabasePath,
        _injectedHistoryStore = historyStore,
        _scanner = scanner ?? WatchBleScanner(),
        _transport = transport ??
            WatchBleTransport(config: WatchBleConfig(profile: jwBleProfile())) {
    _subscriptions.add(_scanner.results.listen((advertisements) {
      if (!_devices.isClosed) {
        _devices.add([
          for (final advertisement in advertisements)
            if (isJWCandidate(advertisement))
              JWScanDevice.fromAdvertisement(advertisement),
        ]);
      }
    }));
    _subscriptions.add(_scanner.errors.listen(_errors.add));
  }

  final String? _historyDatabasePath;
  final JWHistoryStore? _injectedHistoryStore;
  final WatchBleScanner _scanner;
  final WatchTransport _transport;
  final _devices = StreamController<List<JWScanDevice>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  JWHistoryStore? _historyStore;
  bool _initialized = false;
  bool _disposed = false;

  Stream<List<JWScanDevice>> get scanResults => _devices.stream;
  Stream<Object> get scanErrors => _errors.stream;
  bool get isScanning => _scanner.isScanning;
  bool get isInitialized => _initialized;

  /// Opens `jw_watch.db` and marks this SDK instance ready for use.
  ///
  /// Health history is persisted automatically during [JWWatchSession]
  /// synchronization; callers query through [historyStore] and
  /// [JWWatchSession.historyScope] without opening storage themselves.
  Future<void> initialize() async {
    _checkNotDisposed();
    if (_initialized) {
      throw StateError('JW SDK has already been initialized.');
    }
    _historyStore = _injectedHistoryStore ??
        await JWHistoryStore.open(databasePath: _historyDatabasePath);
    _initialized = true;
  }

  /// Local JW health history opened by [initialize].
  JWHistoryStore get historyStore {
    _checkNotDisposed();
    final store = _historyStore;
    if (!_initialized || store == null) {
      throw StateError(
          'JW SDK must be initialized before using history storage.');
    }
    return store;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) {
    _checkNotDisposed();
    if (!_initialized) {
      return Future.error(
          StateError('JW SDK must be initialized before scanning.'));
    }
    return _scanner.start(timeout: timeout);
  }

  Future<void> stopScan() => _scanner.stop();

  /// Creates a single-use session for the scanned JW MAC address.
  JWWatchSession createSession(String deviceMac) {
    _checkNotDisposed();
    if (!_initialized) {
      throw StateError('JW SDK must be initialized before connecting.');
    }
    return JWWatchSession(
      _transport.createConnection(
          WatchDeviceTarget(transportId: 'ble', deviceId: deviceMac)),
      historyStore: historyStore,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _scanner.dispose();
    if (_injectedHistoryStore == null) {
      await _historyStore?.dispose();
    }
    _historyStore = null;
    _initialized = false;
    await _devices.close();
    await _errors.close();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('JWWatch has been disposed');
  }
}
