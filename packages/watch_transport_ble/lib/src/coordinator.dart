import 'dart:async';
import 'package:watch_transport/watch_transport.dart';

/// One coordinator per BLE runtime/isolate. All cooperating entry points use shared.
final class WatchBleCoordinator {
  static final shared = WatchBleCoordinator();
  final _devices = <String, WatchBleLease>{};
  WatchBleLease? _exclusive;
  BleScanLease? _scan;
  Future<void> _scanTail = Future.value();

  static String _key(String id) => id.trim().toLowerCase();
  WatchBleLease acquire(String deviceId, {bool exclusive = false}) {
    if (deviceId.trim().isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
    if (_exclusive != null ||
        (exclusive && _devices.isNotEmpty) ||
        _devices.containsKey(_key(deviceId))) {
      throw const WatchTransportException(
          WatchTransportErrorCode.busy, 'BLE device is in use');
    }
    final lease = WatchBleLease._(this, exclusive);
    _devices[_key(deviceId)] = lease;
    lease._ids.add(_key(deviceId));
    if (exclusive) _exclusive = lease;
    return lease;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final work = _scanTail.then((_) => action());
    _scanTail = work.catchError((Object _) {});
    return work;
  }

  /// Reserves before awaiting platform start. Closing an old token never stops a newer scan.
  Future<BleScanLease> startScan(
      {required Future<void> Function() start,
      required Future<void> Function() stop,
      void Function()? onRevoked}) async {
    if (_scan != null || _exclusive != null) {
      throw const WatchTransportException(
          WatchTransportErrorCode.busy, 'BLE scan is in use');
    }
    final lease = BleScanLease._(this, stop, onRevoked);
    _scan = lease;
    try {
      await _serialize(() async {
        if (!lease._closed) await start();
      });
      return lease;
    } catch (_) {
      await lease.close();
      rethrow;
    }
  }

  /// Intentional connection/OTA takeover; only the captured scan is retired.
  Future<void> stopScanning() async => await _scan?.close();
}

final class WatchBleLease {
  WatchBleLease._(this._runtime, this.exclusive);
  final WatchBleCoordinator _runtime;
  final bool exclusive;
  final _ids = <String>{};
  bool _released = false;

  /// Retain normal identity while adding a DFU/reboot identity atomically.
  void addDevice(String deviceId) {
    if (_released) throw StateError('Lease released');
    if (deviceId.trim().isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
    final key = WatchBleCoordinator._key(deviceId);
    final existing = _runtime._devices[key];
    if (existing != null && !identical(existing, this)) {
      throw const WatchTransportException(
          WatchTransportErrorCode.busy, 'BLE device is in use');
    }
    _runtime._devices[key] = this;
    _ids.add(key);
  }

  void release() {
    if (_released) return;
    _released = true;
    for (final id in _ids) {
      if (identical(_runtime._devices[id], this)) _runtime._devices.remove(id);
    }
    if (identical(_runtime._exclusive, this)) _runtime._exclusive = null;
  }
}

final class BleScanLease {
  BleScanLease._(this._runtime, this._stop, this._onRevoked);
  final WatchBleCoordinator _runtime;
  final Future<void> Function() _stop;
  final void Function()? _onRevoked;
  bool _closed = false;
  Future<void>? _closing;
  Future<void> close() {
    if (_closing != null) return _closing!;
    final done = Completer<void>();
    _closing = done.future;
    _closed = true;
    try {
      _onRevoked?.call();
    } catch (_) {/* Cleanup must still stop the radio. */}
    _runtime._serialize(() async {
      if (!identical(_runtime._scan, this)) return;
      await _stop();
      if (identical(_runtime._scan, this)) _runtime._scan = null;
    }).then((_) => done.complete(), onError: (Object error, StackTrace stack) {
      _closing = null;
      done.completeError(error, stack);
    });
    return done.future;
  }
}
