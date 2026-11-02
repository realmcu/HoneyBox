import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
  StreamSubscription<List<ScanResult>>? _subscription;
  bool _disposed = false, _running = false;
  int _epoch = 0;
  static WSScanner? _radioOwner;
  static Future<void> _radioTail = Future.value();
  Timer? _timeout;
  static Future<void> _radio(Future<void> Function() action) {
    final work = _radioTail.then((_) => action());
    _radioTail = work.catchError((Object _) {});
    return work;
  }

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
    if (_radioOwner != null) {
      _errors.add(StateError('another WSScanner owns the BLE radio scan'));
      return;
    }
    _radioOwner = this;
    try {
      _subscription = FlutterBluePlus.onScanResults.listen((results) {
        if (_disposed || !_running || epoch != _epoch) return;
        for (final result in results) {
          final id = result.device.remoteId.str;
          // Physical advertisements never gain the reserved simulator identity.
          if (id == kWsWatchSimDeviceId) continue;
          _found[id] = WSScanDevice(
              deviceId: id,
              name: result.advertisementData.advName,
              rssi: result.rssi);
        }
        _publish();
      }, onError: (Object error) {
        if (!_disposed && epoch == _epoch) _errors.add(error);
      });
      await _radio(() async {
        if (_disposed || epoch != _epoch) return;
        await FlutterBluePlus.startScan(timeout: timeout);
      });
    } catch (error) {
      if (epoch != _epoch) return;
      if (!_disposed && epoch == _epoch) _errors.add(error);
      await _subscription?.cancel();
      _subscription = null;
      if (identical(_radioOwner, this)) _radioOwner = null;
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
    if (identical(_radioOwner, this)) {
      try {
        await _radio(() async {
          if (identical(_radioOwner, this)) {
            await FlutterBluePlus.stopScan();
          }
        });
      } catch (_) {/* local subscription still released */}
      if (identical(_radioOwner, this)) _radioOwner = null;
    }
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    await stop();
    await _devices.close();
    await _errors.close();
  }
}
