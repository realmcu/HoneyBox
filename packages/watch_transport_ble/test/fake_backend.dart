import 'dart:async';
import 'dart:typed_data';
import 'package:watch_transport_ble/watch_transport_ble.dart';

WatchBleProfile profile({BleWriteMode mode = BleWriteMode.withResponse}) =>
    WatchBleProfile(service: '1800', tx: '2a00', rx: '2a01', writeMode: mode);

class FakeBackend implements WatchBleBackend {
  final scans =
      StreamController<List<WatchBleAdvertisement>>.broadcast(sync: true);
  final devices = <String, FakeDevice>{};
  Future<void> Function()? readyHook, scanHook, stopHook;
  int scanStarts = 0, scanStops = 0;
  @override
  Stream<List<WatchBleAdvertisement>> get scanResults => scans.stream;
  @override
  Future<void> ensureReady() async {
    await readyHook?.call();
  }

  @override
  Future<void> startScan(
      {required List<String> services, required Duration timeout}) async {
    scanStarts++;
    await scanHook?.call();
  }

  @override
  Future<void> stopScan() async {
    scanStops++;
    await stopHook?.call();
  }

  @override
  FakeDevice device(String id) => devices.putIfAbsent(id, FakeDevice.new);
}

class FakeDevice implements WatchBleDevicePort {
  bool connected = false;
  int reportedMtu = 23, connects = 0, disconnects = 0;
  final changes = StreamController<bool>.broadcast(sync: true);
  final mtus = StreamController<int>.broadcast(sync: true);
  final tx = FakeCharacteristic('2a00'), rx = FakeCharacteristic('2a01');
  Future<void> Function()? connectHook, discoverHook, disconnectHook;
  List<WatchBleGattService>? services;
  @override
  bool get isConnected => connected;
  @override
  int get mtu => reportedMtu;
  @override
  Stream<int> get mtuChanges => mtus.stream;
  @override
  Stream<bool> get connectionChanges => changes.stream;
  @override
  Future<void> connect(Duration timeout) async {
    connects++;
    await connectHook?.call();
    connected = true;
    changes.add(true);
  }

  @override
  Future<List<WatchBleGattService>> discoverServices() async {
    await discoverHook?.call();
    return services ??
        [
          WatchBleGattService('1800', [tx, rx])
        ];
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    await disconnectHook?.call();
    connected = false;
    changes.add(false);
  }

  void remoteClose() {
    connected = false;
    changes.add(false);
  }
}

class FakeCharacteristic implements WatchBleCharacteristicPort {
  FakeCharacteristic(this.uuid);
  @override
  final String uuid;
  @override
  bool canWrite = true,
      canWriteWithoutResponse = true,
      canNotify = true,
      canIndicate = true,
      canRead = true;
  final data = StreamController<List<int>>.broadcast(sync: true);
  final writes = <List<int>>[];
  final modes = <bool>[];
  final enabled = <bool>[];
  Future<void> Function(bool)? notifyHook;
  Future<void> Function(Uint8List)? writeHook;
  Future<void> Function()? readHook;
  Uint8List readValue = Uint8List.fromList([42]);
  @override
  Stream<List<int>> get received => data.stream;
  @override
  Future<void> setNotify(bool enable) async {
    enabled.add(enable);
    await notifyHook?.call(enable);
  }

  @override
  Future<void> write(Uint8List bytes, {required bool withoutResponse}) async {
    writes.add(bytes.toList());
    modes.add(withoutResponse);
    await writeHook?.call(bytes);
  }

  @override
  Future<Uint8List> read() async {
    await readHook?.call();
    return readValue;
  }
}
