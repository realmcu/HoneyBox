import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_manager.dart' as manager;

// BLE state enum
enum BleState { disconnected, scanning, connecting, connected, disconnecting }

// Scan device data class
class ScanDevice {
  final String deviceId;
  final String name;
  final int rssi;
  final bool connectable;

  ScanDevice({
    required this.deviceId,
    required this.name,
    required this.rssi,
    this.connectable = true,
  });
}

// Connected device info
class ConnectedDeviceInfo {
  final String deviceId;
  final String name;
  final int mtu;

  ConnectedDeviceInfo({
    required this.deviceId,
    required this.name,
    required this.mtu,
  });
}

// Singleton BleManager with auto-dispose
final bleManagerProvider = Provider<manager.BleManager>((ref) {
  final bleManager = manager.BleManager();
  ref.onDispose(bleManager.dispose);
  return bleManager;
});

// BLE notifier provider — manages scan state, device list, connection state
final bleNotifierProvider = StateNotifierProvider<BleNotifier, BleState>((ref) {
  final bleManager = ref.read(bleManagerProvider);
  return BleNotifier(bleManager, ref);
});

// Scanned devices list
final scannedDevicesProvider =
    StateNotifierProvider<ScannedDevicesNotifier, List<ScanDevice>>((ref) {
  return ScannedDevicesNotifier();
});

// Connected device info
final connectedDeviceProvider =
    StateProvider<ConnectedDeviceInfo?>((ref) => null);

class BleNotifier extends StateNotifier<BleState> {
  final manager.BleManager _bleManager;
  final Ref _ref;
  StreamSubscription<manager.BleState>? _managerStateSub;

  BleNotifier(this._bleManager, this._ref) : super(BleState.disconnected) {
    // Subscribe to manager-level disconnect events so unexpected BLE
    // disconnections are reflected in the Riverpod state.
    _managerStateSub = _bleManager.onStateChanged.listen((next) {
      if (next == manager.BleState.disconnected) {
        _ref.read(connectedDeviceProvider.notifier).state = null;
        if (state != BleState.disconnected) state = BleState.disconnected;
      }
    });
  }

  @override
  void dispose() {
    _managerStateSub?.cancel();
    super.dispose();
  }

  Future<void> startScan() async {
    state = BleState.scanning;
    final devicesNotifier = _ref.read(scannedDevicesProvider.notifier);
    devicesNotifier.clear();

    await _bleManager.startScan((result) {
      final device = result.device;
      // Prefer the advertised name, falling back to the OS-cached platform name
      // (`localName` was removed/deprecated in newer flutter_blue_plus).
      final advName = result.advertisementData.advName.trim();
      final name = advName.isNotEmpty ? advName : device.platformName.trim();
      final displayName = name.isEmpty ? '未知设备' : name;
      devicesNotifier.addDevice(ScanDevice(
        deviceId: device.remoteId.toString(),
        name: displayName,
        rssi: result.rssi,
        connectable: result.advertisementData.connectable,
      ));
    });
  }

  void stopScan() {
    _bleManager.stopScan();
    // Only fall back to disconnected if we were actually scanning. ScanPage's
    // dispose() calls this even when it's being torn down *because* a connect
    // succeeded — without this guard we'd clobber the fresh connected state.
    if (state == BleState.scanning) {
      state = BleState.disconnected;
    }
  }

  Future<bool> connect(String deviceId, String deviceName) async {
    state = BleState.connecting;
    final success = await _bleManager.connect(deviceId, deviceName);
    if (success) {
      _ref.read(connectedDeviceProvider.notifier).state = ConnectedDeviceInfo(
        deviceId: deviceId,
        name: deviceName,
        mtu: 512,
      );
      state = BleState.connected;
    } else {
      state = BleState.disconnected;
    }
    return success;
  }

  Future<void> disconnect() async {
    state = BleState.disconnecting;
    await _bleManager.disconnect();
    _ref.read(connectedDeviceProvider.notifier).state = null;
    state = BleState.disconnected;
  }
}

class ScannedDevicesNotifier extends StateNotifier<List<ScanDevice>> {
  ScannedDevicesNotifier() : super([]);

  void addDevice(ScanDevice device) {
    final index = state.indexWhere((d) => d.deviceId == device.deviceId);
    if (index >= 0) {
      final updated = [...state];
      updated[index] = device;
      state = updated;
    } else {
      state = [...state, device];
    }
  }

  void clear() => state = [];
}
