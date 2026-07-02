import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'l1_engine.dart';
import 'l2_file_transfer.dart';

// ---------------------------------------------------------------------------
// BLE UUIDs
// ---------------------------------------------------------------------------

const String _txUuid = 'FFD1';
const String _rxUuid = 'FFD2';

// Separate Stream Service (UUID 484D5354-…): raw L2 video streaming, no L1.
// Write FFD4 (KS_OPEN/FRAME/CLOSE), notify FFD5 (KS_ACK/CREDIT/REPORT).
const String _streamTxUuid = 'FFD4';
const String _streamRxUuid = 'FFD5';

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

  /// Whether the device exposes the separate Stream Service (FFD4/FFD5) for
  /// real-time video streaming. False → streaming unavailable (old firmware).
  bool get streamAvailable => _streamTxChar != null && _streamRxChar != null;

  /// Raw L2 messages received on the Stream Service notify (FFD5).
  Stream<Uint8List> get streamNotifications => _streamNotifyController.stream;

  /// Inbound L2 command-channel frames (FFD2, after L1 de-framing). Carries any
  /// L2 payload not consumed by a file transfer — notably WiFi provisioning
  /// (CMD 0x0D) responses. Each event is one complete L2 frame payload.
  Stream<Uint8List> get commandNotifications => _commandNotifyController.stream;

  /// Whether the command channel (FFD1/FFD2 + L1 engine) is ready. Required for
  /// WiFi provisioning, which rides the command channel.
  bool get commandAvailable => _l1 != null && _txChar != null;

  /// The negotiated ATT MTU (defaults to 23 before connection).
  int get mtu => _mtu;

  /// Bytes of frame data per KS_FRAME write = `(MTU − 3) − 13` (L2 + KS header,
  /// no L1). Floored at 1.
  int get streamChunkSize {
    final cs = (_mtu - 3) - 13;
    return cs < 1 ? 1 : cs;
  }

  // --------------------------------------------------------------------------
  // BLE objects
  // --------------------------------------------------------------------------

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar; // FFD1 - write
  BluetoothCharacteristic? _rxChar; // FFD2 - notify
  BluetoothCharacteristic? _streamTxChar; // FFD4 - stream write
  BluetoothCharacteristic? _streamRxChar; // FFD5 - stream notify
  StreamSubscription<List<int>>? _streamNotificationSub;
  int _mtu = 23;

  /// Broadcasts raw L2 messages received on the Stream Service (FFD5).
  final _streamNotifyController = StreamController<Uint8List>.broadcast();

  /// Broadcasts inbound L2 command-channel frames (FFD2 → L1 → L2 payload).
  final _commandNotifyController = StreamController<Uint8List>.broadcast();

  StreamSubscription<List<int>>? _notificationSub;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<ScanResult>>? _scanErrorSub;

  // --------------------------------------------------------------------------
  // Protocol stack
  // --------------------------------------------------------------------------

  L1Engine? _l1;
  FileTransferSession? _session;

  /// Serial write queue of (characteristic, bytes). GATT writes can't run
  /// concurrently on one connection, so L1 (FFD1) and stream (FFD4) writes
  /// share this single queue.
  final List<(BluetoothCharacteristic, Uint8List)> _writeQueue = [];
  bool _writing = false;

  // --------------------------------------------------------------------------
  // Dispose guard
  // --------------------------------------------------------------------------

  bool _disposed = false;

  /// True only while a scan is meant to be delivering results. Flipped to false
  /// synchronously the instant a scan is stopped or a connect begins — before
  /// the async subscription cancel completes — so buffered `onScanResults`
  /// batches that arrive mid-teardown are dropped instead of mutating providers
  /// whose ScanPage widget is already being disposed (markNeedsBuild crash).
  bool _scanActive = false;

  // --------------------------------------------------------------------------
  // Construction / disposal
  // --------------------------------------------------------------------------

  BleManager() {
    // flutter_blue_plus logs every scan result and BLE operation at its default
    // (verbose) level, flooding logcat during continuous scanning — most
    // noticeably when the scanner resumes right after a disconnect. Silence the
    // plugin's own logger; the app-level debugPrint diagnostics below are kept.
    FlutterBluePlus.setLogLevel(LogLevel.none);
  }

  /// Release all resources. No methods should be called after this.
  void dispose() {
    _disposed = true;
    _cleanup();
    _stateController.close();
    _streamNotifyController.close();
    _commandNotifyController.close();
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
    return location.isGranted || location.isLimited;
  }

  /// Start scanning for BLE devices. Each discovered device is reported via
  /// [onDeviceFound].
  Future<void> startScan(void Function(ScanResult) onDeviceFound) async {
    if (_disposed) return;
    stopScan();

    final allowed = await _ensureBlePermissions();
    if (!allowed) {
      _setState(BleState.disconnected);
      return;
    }

    _setState(BleState.scanning);
    _scanActive = true;

    _scanSub = FlutterBluePlus.onScanResults.listen(
      (results) {
        // Drop late/buffered batches once scanning has stopped or a
        // connect/disconnect started — otherwise onDeviceFound → addDevice
        // would notify a ScanPage element that is already defunct.
        if (!_scanActive || _disposed) return;
        for (final result in results) {
          onDeviceFound(result);
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

    try {
      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
      );
    } catch (e) {
      stopScan();
      _setState(BleState.disconnected);
    }
  }

  /// Stop an ongoing scan.
  void stopScan() {
    _scanActive = false;
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
    stopScan();
    _setState(BleState.connecting);
    _deviceId = deviceId;
    _deviceName = deviceName;

    try {
      debugPrint('BleManager: connecting to $deviceName ($deviceId)');
      _device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

      // Connect with timeout.
      await _device!.connect(
        timeout: const Duration(seconds: 10),
      );
      debugPrint('BleManager: connected, discovering services');

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
        debugPrint('BleManager: service ${s.uuid}');
        for (final c in s.characteristics) {
          final uuid = c.uuid.toString().toUpperCase();
          debugPrint(
            'BleManager: characteristic ${c.uuid} '
            'write=${c.properties.write} '
            'writeWithoutResponse=${c.properties.writeWithoutResponse} '
            'notify=${c.properties.notify} '
            'indicate=${c.properties.indicate}',
          );
          if (uuid.contains(_txUuid)) {
            _txChar = c;
          }
          if (uuid.contains(_rxUuid) &&
              (c.properties.notify || c.properties.indicate)) {
            _rxChar = c;
          }
          // Separate Stream Service characteristics (raw L2 video streaming).
          if (uuid.contains(_streamTxUuid) &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            _streamTxChar = c;
          }
          if (uuid.contains(_streamRxUuid) &&
              (c.properties.notify || c.properties.indicate)) {
            _streamRxChar = c;
          }
        }
      }

      if (_txChar == null || _rxChar == null) {
        debugPrint(
          'BleManager: transfer characteristics not found; '
          'continuing with GATT connection only',
        );
        _setState(BleState.connected);
        return true;
      }

      // Set up notify, MTU, and protocol stack.
      var mtu = 23;
      try {
        mtu = await _device!.requestMtu(512);
      } catch (e) {
        debugPrint('BleManager: requestMtu failed, using default MTU: $e');
      }
      _mtu = mtu;

      await _rxChar!.setNotifyValue(true);
      _notificationSub = _rxChar!.onValueReceived.listen(
        (data) {
          _l1?.onNotified(Uint8List.fromList(data));
        },
      );

      _l1 = L1Engine(writeFn: _enqueueWrite);
      _l1!.setMtu(mtu);
      // Route any inbound command-channel L2 frame not consumed by a file
      // transfer (e.g. WiFi provisioning CMD 0x0D) to command listeners.
      _l1!.onL2Data = (payload) {
        if (!_disposed) _commandNotifyController.add(payload);
      };

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

      // Enable the Stream Service notify (FFD5) if the device exposes it.
      if (_streamTxChar != null && _streamRxChar != null) {
        try {
          await _streamRxChar!.setNotifyValue(true);
          _streamNotificationSub = _streamRxChar!.onValueReceived.listen((data) {
            if (!_disposed) {
              _streamNotifyController.add(Uint8List.fromList(data));
            }
          });
          debugPrint('BleManager: Stream Service ready (FFD4/FFD5)');
        } catch (e) {
          debugPrint('BleManager: Stream Service FFD5 subscribe failed: $e');
          _streamTxChar = null;
          _streamRxChar = null;
        }
      } else {
        _streamTxChar = null;
        _streamRxChar = null;
      }

      _setState(BleState.connected);
      debugPrint('BleManager: ready, mtu=$mtu, '
          'stream=${streamAvailable ? "on" : "off"}');
      return true;
    } catch (e) {
      debugPrint('BleManager: connect failed: $e');
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

  /// Enqueue a raw L1 chunk for delivery over the FFD1 characteristic.
  void _enqueueWrite(Uint8List chunk) {
    if (_disposed || _txChar == null) return;
    _writeQueue.add((_txChar!, chunk));
    if (!_writing) {
      _flushQueue();
    }
  }

  /// Send one raw L2 stream message over the FFD4 characteristic (no L1, no
  /// fragmentation — the caller keeps each message within one ATT write).
  /// Shares the serial queue so it never races other GATT writes.
  Future<void> writeStream(Uint8List l2) {
    final char = _streamTxChar;
    if (_disposed || char == null) {
      return Future.error(StateError('Stream Service 未就绪'));
    }
    final completer = Completer<void>();
    _writeQueue.add((char, l2));
    _streamWriteCompleters[l2] = completer;
    if (!_writing) {
      _flushQueue();
    }
    return completer.future;
  }

  /// Send one L2 command frame over the L1 command channel (FFD1). L1 handles
  /// framing, CRC, and MTU chunking. Returns the assigned L1 sequence number, or
  /// null if the command channel isn't ready. Used by WiFi provisioning
  /// (CMD 0x0D); file transfers use [FileTransferSession] instead.
  int? sendCommand(Uint8List l2) {
    if (_disposed || _l1 == null || _txChar == null) return null;
    return _l1!.sendL2(l2);
  }

  /// Resolves the future returned by [writeStream] once the write completes.
  final Map<Uint8List, Completer<void>> _streamWriteCompleters = {};

  /// Flush queued writes sequentially using `write(withoutResponse: true)`.
  void _flushQueue() {
    if (_disposed || _writeQueue.isEmpty) {
      _writing = false;
      return;
    }

    _writing = true;
    final (char, bytes) = _writeQueue.removeAt(0);
    final completer = _streamWriteCompleters.remove(bytes);

    char.write(bytes, withoutResponse: true).then((_) {
      completer?.complete();
      _flushQueue();
    }).catchError((Object error) {
      completer?.completeError(error);
      // L1 write failed – treat as a dropped connection. Stream-only failures
      // also surface via the completer; tear down to be safe.
      _writing = false;
      _writeQueue.clear();
      _streamWriteCompleters.clear();
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
    _scanActive = false;
    _notificationSub?.cancel();
    _notificationSub = null;
    _streamNotificationSub?.cancel();
    _streamNotificationSub = null;
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
    _streamTxChar = null;
    _streamRxChar = null;
    _device = null;
    _mtu = 23;

    _writeQueue.clear();
    _streamWriteCompleters.clear();
    _writing = false;
    _deviceId = null;
    _deviceName = null;
  }
}
