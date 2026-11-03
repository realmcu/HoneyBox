import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:watch_transport/watch_transport.dart';
import 'backend.dart';
import 'mtu.dart';

/// Permissions are requested by the host. The adapter only reports radio state/errors.
final class FlutterBlueWatchBackend implements WatchBleBackend {
  FlutterBlueWatchBackend({this.license = License.nonprofit});
  static final shared = FlutterBlueWatchBackend();
  final License license;
  @override
  Future<void> ensureReady() async {
    if (!await FlutterBluePlus.isSupported) {
      throw const WatchTransportException(
          WatchTransportErrorCode.unsupported, 'BLE is unsupported');
    }
    final state = await FlutterBluePlus.adapterState
        .firstWhere((s) =>
            s != BluetoothAdapterState.unknown &&
            s != BluetoothAdapterState.turningOn)
        .timeout(const Duration(seconds: 10));
    if (state == BluetoothAdapterState.unauthorized) {
      throw const WatchTransportException(
          WatchTransportErrorCode.permissionDenied,
          'Bluetooth permission denied');
    }
    if (state != BluetoothAdapterState.on) {
      throw const WatchTransportException(
          WatchTransportErrorCode.adapterOff, 'Bluetooth is off');
    }
  }

  @override
  Stream<List<WatchBleAdvertisement>> get scanResults =>
      FlutterBluePlus.onScanResults.map((batch) => [
            for (final r in batch)
              WatchBleAdvertisement(
                  deviceId: r.device.remoteId.str,
                  name: r.advertisementData.advName.isEmpty
                      ? r.device.platformName
                      : r.advertisementData.advName,
                  rssi: r.rssi,
                  services: r.advertisementData.serviceUuids
                      .map((g) => g.str128)
                      .toList(),
                  manufacturerData: r.advertisementData.manufacturerData,
                  at: r.timeStamp)
          ]);
  @override
  Future<void> startScan(
          {required List<String> services, required Duration timeout}) =>
      FlutterBluePlus.startScan(
          withServices: services.map(Guid.new).toList(),
          timeout: timeout,
          oneByOne: true,
          androidScanMode: AndroidScanMode.lowLatency);
  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();
  @override
  WatchBleDevicePort device(String id) =>
      _Device(BluetoothDevice.fromId(id), license);
}

final class _Device implements WatchBleDevicePort {
  _Device(this.device, this.license);
  final BluetoothDevice device;
  final License license;
  int? _platformMtu;
  @override
  bool get isConnected => device.isConnected;
  @override
  int get mtu => _platformMtu ?? device.mtuNow;
  @override
  Stream<int> get mtuChanges => device.mtu.map((m) {
        _platformMtu = null;
        return m;
      });
  @override
  Stream<bool> get connectionChanges => device.connectionState
      .map((s) => s == BluetoothConnectionState.connected);
  @override
  Future<void> connect(Duration timeout) async {
    await device.connect(license: license, timeout: timeout);
    if (Platform.isWindows) {
      _platformMtu = await negotiatePlatformMtu(device.remoteId);
    }
  }

  @override
  Future<List<WatchBleGattService>> discoverServices() async {
    final services = await device.discoverServices();
    final flattened = <BluetoothService>{};
    void add(BluetoothService service) {
      if (!flattened.add(service)) return;
      for (final included in service.includedServices) {
        add(included);
      }
    }

    for (final service in services) {
      add(service);
    }
    return [
      for (final service in flattened)
        WatchBleGattService(service.uuid.str128,
            [for (final c in service.characteristics) _Characteristic(c)])
    ];
  }

  @override
  Future<void> disconnect() => device.disconnect();
}

final class _Characteristic implements WatchBleCharacteristicPort {
  _Characteristic(this.characteristic);
  final BluetoothCharacteristic characteristic;
  @override
  String get uuid => characteristic.uuid.str128;
  @override
  bool get canWrite => characteristic.properties.write;
  @override
  bool get canWriteWithoutResponse =>
      characteristic.properties.writeWithoutResponse;
  @override
  bool get canNotify => characteristic.properties.notify;
  @override
  bool get canIndicate => characteristic.properties.indicate;
  @override
  bool get canRead => characteristic.properties.read;
  @override
  Stream<List<int>> get received => characteristic.onValueReceived;
  @override
  Future<void> setNotify(bool enabled) async {
    if (!await characteristic.setNotifyValue(enabled)) {
      throw StateError('CCCD subscription refused');
    }
  }

  @override
  Future<void> write(Uint8List bytes, {required bool withoutResponse}) =>
      characteristic.write(bytes, withoutResponse: withoutResponse);
  @override
  Future<Uint8List> read() async =>
      Uint8List.fromList(await characteristic.read());
}
