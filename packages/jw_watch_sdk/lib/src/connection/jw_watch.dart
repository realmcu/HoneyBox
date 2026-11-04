import 'dart:async';

import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import 'jw_scan_device.dart';
import 'jw_session.dart';

/// Public JW entry point. It owns scanning but every [JWWatchSession] owns one
/// single-use connection and must be disposed by its caller.
final class JWWatch {
  JWWatch({
    WatchBleScanner? scanner,
    WatchTransport? transport,
  })  : _scanner = scanner ?? WatchBleScanner(),
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

  final WatchBleScanner _scanner;
  final WatchTransport _transport;
  final _devices = StreamController<List<JWScanDevice>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _initialized = false;
  bool _disposed = false;

  Stream<List<JWScanDevice>> get scanResults => _devices.stream;
  Stream<Object> get scanErrors => _errors.stream;
  bool get isScanning => _scanner.isScanning;
  bool get isInitialized => _initialized;

  /// Marks this SDK instance ready for use.
  ///
  /// Configuration belongs to construction; initialization is intentionally
  /// explicit so applications can place it in their own onboarding flow.
  Future<void> initialize() async {
    _checkNotDisposed();
    if (_initialized) {
      throw StateError('JW SDK has already been initialized.');
    }
    _initialized = true;
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

  JWWatchSession createSession(JWScanDevice device) {
    _checkNotDisposed();
    if (!_initialized) {
      throw StateError('JW SDK must be initialized before connecting.');
    }
    return JWWatchSession(_transport.createConnection(
        WatchDeviceTarget(transportId: 'ble', deviceId: device.id)));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _scanner.dispose();
    await _devices.close();
    await _errors.close();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('JWWatch has been disposed');
  }
}
