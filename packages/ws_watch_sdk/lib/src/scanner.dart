import 'dart:async';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'config.dart';
import 'errors.dart';
import 'simulation/sim_watch_session.dart';

class WSScanDevice {
  const WSScanDevice(
      {required this.deviceId,
      required this.name,
      required this.rssi,
      this.isSimulated = false});
  final String deviceId, name;
  final int rssi;
  final bool isSimulated;
}

/// Owns a scan subscription. Real radio failures do not remove the simulator.
class WSScanner {
  WSScanner({this.config = const WSConfig()});
  final WSConfig config;
  final _devices = StreamController<List<WSScanDevice>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final Map<String, WSScanDevice> _found = {};
  StreamSubscription<List<WatchBleAdvertisement>>? _subscription;
  bool _disposed = false, _running = false;
  int _epoch = 0;
  final _radio = WatchBleScanner();
  StreamSubscription<Object>? _radioErrors;
  Timer? _timeout;

  List<WSScanDevice> get devices => List.unmodifiable(_found.values);
  Stream<List<WSScanDevice>> get results => _devices.stream;
  Stream<Object> get errors => _errors.stream;
  bool get isScanning => _running;
  Future<void>? _disposing, _stopping;

  Future<void> start(
      {bool includeRealDevices = true,
      Duration timeout = const Duration(seconds: 10)}) async {
    if (_disposed) throw const WSDisposedException();
    if (_running || _stopping != null) {
      throw StateError('scan or cleanup is already running');
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError('scan timeout must be positive');
    }
    final epoch = ++_epoch;
    _running = true;
    _found.clear();
    if (config.simulationEnabled) {
      _found[kWsWatchSimDeviceId] = const WSScanDevice(
          deviceId: kWsWatchSimDeviceId,
          name: 'WS Watch Simulator',
          rssi: 0,
          isSimulated: true);
    }
    _publish();
    _timeout = Timer(timeout, () => unawaited(stop()));
    if (!includeRealDevices) return;
    try {
      _subscription = _radio.results.listen((results) {
        if (_disposed || !_running || epoch != _epoch) return;
        for (final result in results) {
          final id = result.deviceId;
          if (id == kWsWatchSimDeviceId) continue;
          _found[id] =
              WSScanDevice(deviceId: id, name: result.name, rssi: result.rssi);
        }
        _publish();
      });
      _radioErrors = _radio.errors.listen((error) {
        if (!_disposed && epoch == _epoch) _errors.add(error);
      });
      await _radio.start(timeout: timeout);
      if (_disposed || epoch != _epoch) await _radio.stop();
    } catch (error) {
      if (!_disposed && epoch == _epoch) _errors.add(error);
      await _subscription?.cancel();
      _subscription = null;
      await _radioErrors?.cancel();
      _radioErrors = null;
    }
  }

  void _publish() {
    if (!_disposed) _devices.add(devices);
  }

  Future<void> stop() =>
      _stopping ??= _stop().whenComplete(() => _stopping = null);

  Future<void> _stop() async {
    _running = false;
    _epoch++;
    _timeout?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _radioErrors?.cancel();
    _radioErrors = null;
    await _radio.stop();
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    await stop();
    await _radio.dispose();
    await _devices.close();
    await _errors.close();
  }
}
