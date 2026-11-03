import 'dart:typed_data';

/// Platform ports allow lifecycle tests without a radio or FlutterBluePlus objects.
abstract interface class WatchBleBackend {
  Future<void> ensureReady();
  Stream<List<WatchBleAdvertisement>> get scanResults;
  Future<void> startScan(
      {required List<String> services, required Duration timeout});
  Future<void> stopScan();
  WatchBleDevicePort device(String id);
}

final class WatchBleAdvertisement {
  WatchBleAdvertisement(
      {required this.deviceId,
      required this.name,
      required this.rssi,
      List<String> services = const [],
      Map<int, List<int>> manufacturerData = const {},
      DateTime? at})
      : services = List.unmodifiable(services),
        manufacturerData = Map.unmodifiable(manufacturerData
            .map((k, v) => MapEntry(k, List<int>.unmodifiable(v)))),
        at = at ?? DateTime.now();
  final String deviceId, name;
  final int rssi;
  final List<String> services;
  final Map<int, List<int>> manufacturerData;
  final DateTime at;
}

abstract interface class WatchBleDevicePort {
  bool get isConnected;
  int get mtu;
  Stream<int> get mtuChanges;
  Stream<bool> get connectionChanges;
  Future<void> connect(Duration timeout);
  Future<List<WatchBleGattService>> discoverServices();
  Future<void> disconnect();
}

final class WatchBleGattService {
  const WatchBleGattService(this.uuid, this.characteristics);
  final String uuid;
  final List<WatchBleCharacteristicPort> characteristics;
}

abstract interface class WatchBleCharacteristicPort {
  String get uuid;
  bool get canWrite;
  bool get canWriteWithoutResponse;
  bool get canNotify;
  bool get canIndicate;
  bool get canRead;
  Stream<List<int>> get received;
  Future<void> setNotify(bool enabled);
  Future<void> write(Uint8List bytes, {required bool withoutResponse});
  Future<Uint8List> read();
}
