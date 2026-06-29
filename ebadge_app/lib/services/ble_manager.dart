import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'l1_engine.dart';
import 'l2_file_transfer.dart';

// ---------------------------------------------------------------------------
// BLE UUIDs
// ---------------------------------------------------------------------------

const String _txUuid = 'FFD1';
const String _rxUuid = 'FFD2';

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------

/// High-level BLE connection state.
enum BleState {
  disconnected,
  scanning,
  connecting,
  connected,
  disconnecting,
}

// ---------------------------------------------------------------------------
// BleManager
// ---------------------------------------------------------------------------

/// Manages the BLE connection lifecycle and wires the [L1Engine] /
/// [FileTransferSession] protocol stack to the `flutter_blue_plus` BLE
/// peripheral.
class BleManager {
  // --------------------------------------------------------------------------
  // Observable state
  // --------------------------------------------------------------------------

  BleState _state = BleState.disconnected;
  String? _deviceId;
  String? _deviceName;

  /// Stream controller that fires whenever [_state] changes.
  final _stateController = StreamController<BleState>.broadcast();

  /// Listen to this stream to react to connection state changes.
  Stream<BleState> get onStateChanged => _stateController.stream;

  BleState get state => _state;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  /// The active file-transfer session, if one exists.
  FileTransferSession? get session => _session;

  // --------------------------------------------------------------------------
  // BLE objects
  // --------------------------------------------------------------------------

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar; // FFD1 - write
  BluetoothCharacteristic? _rxChar; // FFD2 - notify
  StreamSubscription<List<int>>? _notificationSub;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<ScanResult>>? _scanErrorSub;

  // --------------------------------------------------------------------------
  // Protocol stack
  // --------------------------------------------------------------------------

  L1Engine? _l1;
  FileTransferSession? _session;

  /// Queue of raw byte chunks to be written to the TX characteristic.
  final List<Uint8List> _writeQueue = [];
  bool _writing = false;

  // --------------------------------------------------------------------------
  // Dispose guard
  // --------------------------------------------------------------------------

  bool _disposed = false;

  // --------------------------------------------------------------------------
  // Construction / disposal
  // --------------------------------------------------------------------------

  BleManager();

  /// Release all resources. No methods should be called after this.
  void dispose() {
    _disposed = true;
    _cleanup();
    _stateController.close();
  }

  // --------------------------------------------------------------------------
  // Scanning
  // --------------------------------------------------------------------------

  /// Request Bluetooth runtime permissions on Android.
  Future<bool> _ensureBlePermissions() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) return true;

    final location = await Permission.locationWhenInUse.request();
    return location.isGranted;
  }

  /// Start scanning for BLE devices. Each discovered device is reported via
  /// [onDeviceFound].
  Future<void> startScan(void Function(ScanResult) onDeviceFound) async {
    if (_disposed) return;

    final allowed = await _ensureBlePermissions();
    if (!allowed) {
      _setState(BleState.disconnected);
      return;
    }

    _setState(BleState.scanning);

    _scanSub = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          onDeviceFound(results.last);
        }
      },
      onError: (Object error) {
        _setState(BleState.disconnected);
      },
    );

    // Also handle errors on the scan stream itself.
    _scanErrorSub = FlutterBluePlus.scanResults.listen(
      (_) {},
      onError: (Object error) {
        _setState(BleState.disconnected);
      },
    );
  }

  /// Stop an ongoing scan.
  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    _scanErrorSub?.cancel();
    _scanErrorSub = null;
    FlutterBluePlus.stopScan();
    if (_state == BleState.scanning) {
      _setState(BleState.disconnected);
    }
  }

  // --------------------------------------------------------------------------
  // Connection
  // --------------------------------------------------------------------------

  /// Connect to a BLE device and show the UI. Returns true on success.
  Future<bool> connect(String deviceId, String deviceName) async {
    if (_disposed) return false;
    _setState(BleState.connecting);
    _deviceId = deviceId;
    _deviceName = deviceName;

    try {
      _device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

      // Connect with timeout.
      await _device!.connect(
        timeout: const Duration(seconds: 10),
      );

      // Listen for disconnection (AFTER connect succeeds, skip initial state).
      _connectionStateSub = _device!.connectionState.skip(1).listen(
        (BluetoothConnectionState cs) {
          if (cs == BluetoothConnectionState.disconnected) {
            _onDisconnected();
          }
        },
      );

      // Discover services and try to find BLE characteristics
      await _device!.discoverServices();

      final services = _device!.servicesList;
      for (final s in services) {
        for (final c in s.characteristics) {
          final uuid = c.uuid.toString().toUpperCase();
          if (uuid.contains(_txUuid)) _txChar = c;
          if (uuid.contains(_rxUuid) &&
              (c.properties.notify || c.properties.indicate)) _rxChar = c;
        }
      }

      if (_txChar == null || _rxChar == null) {
        throw StateError('设备不支持此功能');
      }

      // Set up notify, MTU, and protocol stack.
      final mtu = await _device!.requestMtu(512);

      await _rxChar!.setNotifyValue(true);
      _notificationSub = _rxChar!.onValueReceived.listen(
        (data) {
          _l1?.onNotified(Uint8List.fromList(data));
        },
      );

      _l1 = L1Engine(writeFn: _enqueueWrite);
      _l1!.setMtu(mtu);

      _session = FileTransferSession(
        sendL2: (Uint8List frame) => _l1!.sendL2(frame),
        attachToL1: (FileTransferSession s) {
          _l1!.attach(s);
          _l1!.onAck = (int seq, bool ok) => s.onL1Ack(seq, ok);
        },
        detachFromL1: () {
          _l1!.detach();
          _l1!.onAck = null;
        },
      );

      _setState(BleState.connected);
      return true;
    } catch (e) {
      await _device?.disconnect();
      _cleanup();
      _setState(BleState.disconnected);
      return false;
    }
  }

  /// Gracefully disconnect and clean up.
  Future<void> disconnect() async {
    if (_state == BleState.disconnected || _state == BleState.disconnecting) {
      return;
    }
    _setState(BleState.disconnecting);
    await _device?.disconnect();
    _onDisconnected();
  }

  // --------------------------------------------------------------------------
  // Write queue (L1 → characteristic)
  // --------------------------------------------------------------------------

  /// Enqueue a raw byte chunk for delivery over the TX characteristic.
  void _enqueueWrite(Uint8List chunk) {
    if (_disposed || _txChar == null) return;
    _writeQueue.add(chunk);
    if (!_writing) {
      _flushQueue();
    }
  }

  /// Flush queued writes sequentially using `write(withoutResponse: true)`.
  void _flushQueue() {
    if (_disposed || _txChar == null || _writeQueue.isEmpty) {
      _writing = false;
      return;
    }

    _writing = true;
    final chunk = _writeQueue.removeAt(0);

    _txChar!.write(chunk, withoutResponse: true).then((_) {
      // Success – continue flushing.
      _flushQueue();
    }).catchError((Object error) {
      // Write failed – reset queue.
      _writing = false;
      _writeQueue.clear();
      _onDisconnected();
    });
  }

  // --------------------------------------------------------------------------
  // Internal
  // --------------------------------------------------------------------------

  void _setState(BleState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_disposed) {
      _stateController.add(newState);
    }
  }

  void _onDisconnected() {
    if (_state == BleState.disconnected) return;
    _session?.abort();
    _cleanup();
    _setState(BleState.disconnected);
  }

  void _cleanup() {
    _notificationSub?.cancel();
    _notificationSub = null;
    _connectionStateSub?.cancel();
    _connectionStateSub = null;
    _scanSub?.cancel();
    _scanSub = null;
    _scanErrorSub?.cancel();
    _scanErrorSub = null;

    _session = null;
    _l1?.reset();
    _l1 = null;
    _txChar = null;
    _rxChar = null;
    _device = null;

    _writeQueue.clear();
    _writing = false;
    _deviceId = null;
    _deviceName = null;
  }
}
