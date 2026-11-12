import 'dart:async';
import 'backend.dart';
import 'coordinator.dart';
import 'flutter_blue_backend.dart';

final class WatchBleScanner {
  WatchBleScanner({WatchBleBackend? backend, WatchBleCoordinator? coordinator})
      : backend = backend ?? FlutterBlueWatchBackend.shared,
        coordinator = coordinator ?? WatchBleCoordinator.shared;
  final WatchBleBackend backend;
  final WatchBleCoordinator coordinator;
  final _results = StreamController<List<WatchBleAdvertisement>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _found = <String, WatchBleAdvertisement>{};
  StreamSubscription<List<WatchBleAdvertisement>>? _subscription;
  BleScanLease? _lease;
  Timer? _timer;
  int _epoch = 0;
  bool _disposed = false, _running = false;
  Future<void>? _starting, _stopping, _disposing;
  bool get isScanning => _running;
  List<WatchBleAdvertisement> get devices => List.unmodifiable(_found.values);
  Stream<List<WatchBleAdvertisement>> get results => _results.stream;
  Stream<Object> get errors => _errors.stream;

  /// [services] is for low-level diagnostics only; JW/WS watch SDKs pass fixed
  /// profile UUIDs internally and app code should not customize them.
  Future<void> start(
      {List<String> services = const [],
      Duration timeout = const Duration(seconds: 10)}) {
    if (_disposed) throw StateError('Scanner disposed');
    if (_running || _starting != null || _stopping != null) {
      throw StateError('Scan or cleanup already running');
    }
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    final epoch = ++_epoch;
    _running = true;
    _found.clear();
    _results.add(devices);
    return _starting =
        _start(epoch, services, timeout).whenComplete(() => _starting = null);
  }

  Future<void> _start(
      int epoch, List<String> services, Duration timeout) async {
    try {
      await backend.ensureReady();
      if (_disposed || epoch != _epoch) return;
      _subscription = backend.scanResults.listen((batch) {
        if (_disposed || epoch != _epoch || !_running) return;
        for (final device in batch) {
          _found[device.deviceId] = device;
        }
        _results.add(devices);
      }, onError: (Object error) {
        if (!_disposed && epoch == _epoch) {
          _errors.add(error);
          stop().ignore();
        }
      });
      final lease = await coordinator.startScan(
          start: () => backend.startScan(services: services, timeout: timeout),
          stop: backend.stopScan,
          onRevoked: () {
            if (epoch == _epoch) {
              _running = false;
              _epoch++;
              _timer?.cancel();
              _subscription?.cancel();
              _subscription = null;
            }
          });
      _lease = lease;
      if (_disposed || epoch != _epoch) {
        await lease.close();
        return;
      }
      _timer = Timer(timeout, () => stop().ignore());
    } catch (_) {
      _running = false;
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
  }

  Future<void> stop() =>
      _stopping ??= _stop().whenComplete(() => _stopping = null);
  Future<void> _stop() async {
    _running = false;
    _epoch++;
    _timer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _starting;
    } catch (_) {}
    await _lease?.close();
    _lease = null;
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    await stop();
    await _results.close();
    await _errors.close();
  }
}
