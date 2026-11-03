import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart'
    show WatchBleCoordinator, WatchBleLease, BleScanLease;
import 'android_ble_permissions.dart';

import 'ble_chunk_calibrator.dart';
import 'ble_gatt_profile.dart';
import 'ble_link_tuning.dart';
import 'ble_mtu.dart';
import 'ble_write_pacer.dart';
import 'ble_write_queue.dart';
import 'ble_write_stats.dart';
import 'jw/jw_gatt_profile.dart';
import 'jw/jw_raw_channel.dart';
import 'jw/jw_transport.dart';
import 'l1_engine.dart';
import 'l2_file_transfer.dart';

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------

/// High-level BLE connection state.
enum BleState { disconnected, scanning, connecting, connected, disconnecting }

class _JwNotifyBinding {
  StreamSubscription<List<int>>? subscription;
}

class _BleConnectionResources {
  const _BleConnectionResources({
    required this.device,
    this.lease,
    required this.mtu,
    required this.writeQueue,
    required this.connectionStateSub,
    this.commandTx,
    this.commandRx,
    this.streamTx,
    this.streamRx,
    this.commandNotificationSub,
    this.streamNotificationSub,
    this.l1,
    this.session,
    this.jwTransport,
    this.jwNotifyController,
    this.jwDisconnectController,
    this.jwNotify,
    this.naviCtrlTx,
    this.naviCtrlRx,
    this.naviDataTx,
    this.naviDataRx,
    this.naviCtrlSub,
    this.naviDataSub,
    this.naviL1,
  });

  final BluetoothDevice device;
  final WatchBleLease? lease;
  final int mtu;
  final BleWriteQueue writeQueue;
  final StreamSubscription<BluetoothConnectionState> connectionStateSub;
  final BleGattEndpoint<BluetoothCharacteristic>? commandTx;
  final BluetoothCharacteristic? commandRx;
  final BleGattEndpoint<BluetoothCharacteristic>? streamTx;
  final BluetoothCharacteristic? streamRx;
  final StreamSubscription<List<int>>? commandNotificationSub;
  final StreamSubscription<List<int>>? streamNotificationSub;
  final L1Engine? l1;
  final FileTransferSession? session;
  final JwRawChannel? jwTransport;
  final StreamController<Uint8List>? jwNotifyController;
  final StreamController<void>? jwDisconnectController;
  final _JwNotifyBinding? jwNotify;
  final BleGattEndpoint<BluetoothCharacteristic>? naviCtrlTx;
  final BluetoothCharacteristic? naviCtrlRx;
  final BleGattEndpoint<BluetoothCharacteristic>? naviDataTx;
  final BluetoothCharacteristic? naviDataRx;
  final StreamSubscription<List<int>>? naviCtrlSub;
  final StreamSubscription<List<int>>? naviDataSub;
  final L1Engine? naviL1;

  bool get commandReady =>
      commandTx != null && commandRx != null && l1 != null && session != null;

  bool get streamReady =>
      streamTx != null && streamRx != null && streamNotificationSub != null;
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
  FileTransferSession? get session => _connectionOwner.value?.session;

  /// Whether the device exposes the separate Stream Service (FFC4/FFC5) for
  /// real-time video streaming. False → streaming unavailable (old firmware).
  bool get streamAvailable => _streamAvailable;

  /// Fires when a subscribed FFC4/FFC5 pair becomes ready or is cleared.
  Stream<bool> get onStreamAvailabilityChanged =>
      _streamAvailabilityController.stream;

  /// Raw L2 messages received on the Stream Service notify (FFC5).
  Stream<Uint8List> get streamNotifications => _streamNotifyController.stream;

  /// Inbound L2 command-channel frames (FFC2, after L1 de-framing). Carries any
  /// L2 payload not consumed by a file transfer — notably WiFi provisioning
  /// (CMD 0x0D) responses. Each event is one complete L2 frame payload.
  Stream<Uint8List> get commandNotifications => _commandNotifyController.stream;

  /// Whether the command channel (FFC1/FFC2 + L1 engine) is ready. Required for
  /// WiFi provisioning, which rides the command channel.
  bool get commandAvailable => _connectionOwner.value?.commandReady ?? false;

  /// The negotiated ATT MTU (defaults to 23 before connection).
  int get mtu => _connectionOwner.value?.mtu ?? kMinAttMtu;

  /// Bytes of frame data per KS_FRAME write. Derived from the negotiated ATT
  /// MTU where the platform reports one, otherwise discovered by probing.
  int get streamChunkSize =>
      _chunkCalibrator?.chunkSize ?? streamChunkSizeForMtu(mtu);

  /// Report that a stream write was rejected. Returns true when the write
  /// budget was reduced, so the caller should retry the same payload smaller.
  bool shrinkStreamChunk() {
    final calibrator = _chunkCalibrator;
    if (calibrator == null || !calibrator.recordRejection()) return false;
    debugPrint(
      'BleManager: stream write rejected, '
      'chunk shrunk to ${calibrator.chunkSize}',
    );
    return true;
  }

  /// Whether the device exposes the Navigation Projection Service (FFD1-FFD4).
  bool get naviProjAvailable {
    final connection = _connectionOwner.value;
    return connection != null &&
        connection.naviCtrlTx != null &&
        connection.naviCtrlRx != null &&
        connection.naviDataTx != null &&
        connection.naviDataRx != null;
  }

  /// Raw L2 messages received on the navi data notify (FFD4).
  Stream<Uint8List> get naviDataNotifications =>
      _naviDataNotifyController.stream;

  /// Bytes of JPEG frame data per NAVI_FRAME write = `(MTU − 3) − 13`.
  int get naviDataChunkSize {
    final cs = (mtu - 3) - 13;
    return cs < 1 ? 1 : cs;
  }

  /// The navi control channel L1 engine (FFD1/FFD2). Non-null when
  /// [naviProjAvailable] is true.
  L1Engine? get naviL1 => _connectionOwner.value?.naviL1;

  /// L2 frames from the navi control channel (FFD2 → L1 de-framing).
  Stream<Uint8List> get naviCtrlNotifications => _naviCtrlL2Controller.stream;

  /// Active JW raw port, when [connect] was asked to own a JW watch.
  JwTransport? get jwTransport => _connectionOwner.value?.jwTransport;

  // --------------------------------------------------------------------------
  // BLE objects
  // --------------------------------------------------------------------------

  final _connectionOwner = BleConnectionOwner<_BleConnectionResources>();
  BluetoothDevice? _connectingDevice;
  int? _connectingGeneration;
  bool _streamAvailable = false;

  /// Per-connection stream write budget. Non-null once a connection resolved
  /// its MTU (or decided to probe for it); cleared when that connection ends.
  BleChunkCalibrator? _chunkCalibrator;

  /// Latency/throughput sampling for FFC4 writes.
  final BleWriteStats _streamWriteStats = BleWriteStats();

  /// Monotonic clock the stream pacer measures against.
  final Stopwatch _streamClock = Stopwatch()..start();

  /// How many FFC5 notifications this connection has delivered.
  int _streamNotifyCount = 0;

  /// Backpressure for platforms whose unacknowledged writes return before the
  /// controller has actually sent anything. Null where the stack paces itself.
  BleWritePacer? _streamPacer;

  /// Host-side connection-interval preference, where the platform offers one.
  final BleLinkTuning _linkTuning = BleLinkTuning();
  String? _tunedRemoteId;

  /// Broadcasts raw L2 messages received on the Stream Service (FFC5).
  final _streamNotifyController = StreamController<Uint8List>.broadcast();

  /// Broadcasts availability only after the FFC5 subscription is active.
  final _streamAvailabilityController = StreamController<bool>.broadcast();

  /// Broadcasts inbound L2 command-channel frames (FFC2 → L1 → L2 payload).
  final _commandNotifyController = StreamController<Uint8List>.broadcast();

  /// Broadcasts raw L2 messages received on the navi data channel (FFD4).
  final _naviDataNotifyController = StreamController<Uint8List>.broadcast();

  /// Broadcasts L2 frames from the navi control channel (FFD2 → L1 → L2 payload).
  final _naviCtrlL2Controller = StreamController<Uint8List>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<ScanResult>>? _scanErrorSub;

  // --------------------------------------------------------------------------
  // Dispose guard
  // --------------------------------------------------------------------------

  bool _disposed = false;

  /// True only while a scan is meant to be delivering results. Flipped to false
  /// synchronously the instant a scan is stopped or a connect begins — before
  /// the async subscription cancel completes — so buffered `onScanResults`
  /// batches that arrive mid-teardown are dropped instead of mutating providers
  /// whose ScanPage widget is already being disposed (markNeedsBuild crash).
  BleScanLease? _scanLease;
  Future<void> _scanCleanup = Future.value();
  bool _scanActive = false;
  int _scanGeneration = 0;
  Completer<BluetoothAdapterState?>? _adapterWait;
  StreamSubscription<BluetoothAdapterState>? _adapterWaitSub;

  // --------------------------------------------------------------------------
  // Construction / disposal
  // --------------------------------------------------------------------------

  final bool _requireJwProfile;

  /// Strict tools can prohibit legacy notification subscriptions entirely.
  BleManager({bool requireJwProfile = false})
      : _requireJwProfile = requireJwProfile {
    // flutter_blue_plus logs every scan result and BLE operation at its default
    // (verbose) level, flooding logcat during continuous scanning — most
    // noticeably when the scanner resumes right after a disconnect. Silence the
    // plugin's own logger; the app-level debugPrint diagnostics below are kept.
    FlutterBluePlus.setLogLevel(LogLevel.none);
  }

  /// Release all resources. No methods should be called after this.
  void dispose() {
    if (_disposed) return;
    _cleanup();
    _disposed = true;
    _stateController.close();
    _streamNotifyController.close();
    _streamAvailabilityController.close();
    _commandNotifyController.close();
    _naviDataNotifyController.close();
    _naviCtrlL2Controller.close();
  }

  // --------------------------------------------------------------------------
  // Scanning
  // --------------------------------------------------------------------------

  /// Request Bluetooth runtime permissions on Android.
  ///
  /// On non-Android platforms (Windows desktop, iOS, etc.) there is no
  /// permission_handler runtime-permission model for BLE, so this is a no-op
  /// that reports success. On Windows the WinRT BLE APIs are accessible
  /// directly from the Win32 process without capability declarations.
  Future<bool> _ensureBlePermissions() async {
    if (!Platform.isAndroid) return true;
    return requestAndroidBlePermissions();
  }

  Future<BluetoothAdapterState?> _waitForAppleAdapter() async {
    final wait = Completer<BluetoothAdapterState?>();
    _adapterWait = wait;
    _adapterWaitSub = FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.unknown &&
          state != BluetoothAdapterState.turningOn &&
          !wait.isCompleted) {
        wait.complete(state);
      }
    }, onError: (Object error, StackTrace stack) {
      if (!wait.isCompleted) wait.completeError(error, stack);
    });
    try {
      return await wait.future;
    } finally {
      if (identical(_adapterWait, wait)) _cancelAdapterWait();
    }
  }

  void _cancelAdapterWait() {
    _adapterWaitSub?.cancel();
    _adapterWaitSub = null;
    final wait = _adapterWait;
    _adapterWait = null;
    if (wait != null && !wait.isCompleted) wait.complete(null);
  }

  /// Start scanning for BLE devices. Each discovered device is reported via
  /// [onDeviceFound].
  Future<void> startScan(
    void Function(ScanResult) onDeviceFound, {
    String? serviceUuid,
  }) async {
    if (_disposed) return;
    stopScan();
    final generation = _scanGeneration;
    await _scanCleanup;

    final allowed = await _ensureBlePermissions();
    if (_disposed || generation != _scanGeneration) return;
    if (!allowed) {
      // Report failed startup even if the manager was already disconnected.
      if (_state == BleState.disconnected && !_disposed) {
        _stateController.add(BleState.disconnected);
      } else {
        _setState(BleState.disconnected);
      }
      return;
    }

    _setState(BleState.scanning);
    _scanActive = true;

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        final wait = _waitForAppleAdapter();
        final adapterState = defaultTargetPlatform == TargetPlatform.macOS
            ? await wait.timeout(const Duration(seconds: 10))
            : await wait;
        if (_disposed || generation != _scanGeneration) return;
        if (adapterState != BluetoothAdapterState.on) {
          stopScan();
          return;
        }
      } catch (error) {
        if (!_disposed && generation == _scanGeneration) {
          debugPrint('BLE adapter initialization failed: $error');
          stopScan();
        }
        return;
      }
    }

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
        debugPrint('BLE scan stream failed: $error');
        _setState(BleState.disconnected);
      },
    );

    // Also handle errors on the scan stream itself.
    _scanErrorSub = FlutterBluePlus.scanResults.listen(
      (_) {},
      onError: (Object error) {
        debugPrint('BLE scan stream failed: $error');
        _setState(BleState.disconnected);
      },
    );

    try {
      // Android-only scan tuning (androidScanMode / androidUsesFineLocation)
      // is not applicable on Windows desktop, so branch the call by platform.
      final withServices =
          serviceUuid == null ? const <Guid>[] : [Guid(serviceUuid)];
      final lease = await WatchBleCoordinator.shared.startScan(
          start: () async {
            if (_disposed || generation != _scanGeneration) return;
            if (Platform.isAndroid) {
              await FlutterBluePlus.startScan(
                  withServices: withServices,
                  oneByOne: true,
                  androidScanMode: AndroidScanMode.lowLatency,
                  androidUsesFineLocation: true);
            } else {
              await FlutterBluePlus.startScan(
                  withServices: withServices, oneByOne: true);
            }
          },
          stop: FlutterBluePlus.stopScan,
          onRevoked: () {
            if (generation == _scanGeneration) stopScan();
          });
      if (_disposed || generation != _scanGeneration) {
        await lease.close();
      } else {
        _scanLease = lease;
      }
    } catch (e) {
      if (_disposed || generation != _scanGeneration) return;
      debugPrint('BLE scan failed: $e');
      stopScan();
      _setState(BleState.disconnected);
    }
  }

  /// Stop an ongoing scan.
  void stopScan() {
    _scanGeneration++;
    _cancelAdapterWait();
    _scanActive = false;
    _scanSub?.cancel();
    _scanSub = null;
    _scanErrorSub?.cancel();
    _scanErrorSub = null;
    final lease = _scanLease;
    _scanLease = null;
    if (lease != null) {
      _scanCleanup = lease.close().catchError((Object error) {
        debugPrint('BLE scan cleanup failed: $error');
      });
    }
    if (_state == BleState.scanning) {
      _setState(BleState.disconnected);
    }
  }

  // --------------------------------------------------------------------------
  // Connection
  // --------------------------------------------------------------------------

  /// Connect to a BLE device and show the UI. Returns true on success.
  Future<bool> connect(
    String deviceId,
    String deviceName, {
    bool allowJw = false,
  }) async {
    if (_disposed) return false;
    stopScan();
    final connectionGeneration = _connectionOwner.replace(
      _retireConnectionResources,
    );
    _setState(BleState.connecting);
    _deviceId = deviceId;
    _deviceName = deviceName;
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    WatchBleLease? lease;
    var ownsDevice = false;

    StreamSubscription<BluetoothConnectionState>? connectionStateSub;
    StreamSubscription<List<int>>? commandNotificationSub;
    StreamSubscription<List<int>>? streamNotificationSub;
    L1Engine? l1;
    FileTransferSession? transferSession;
    var setupReleased = false;
    var published = false;

    late final BleWriteQueue writeQueue;
    writeQueue = BleWriteQueue(
      onFatalError: (Object _, StackTrace __) {
        _connectionOwner.runIfCurrent(
          connectionGeneration,
          () => _onDisconnected(connectionGeneration),
        );
      },
    );

    Future<void> releaseSetup() async {
      if (setupReleased || published) return;
      setupReleased = true;
      await commandNotificationSub?.cancel();
      await streamNotificationSub?.cancel();
      await connectionStateSub?.cancel();
      l1?.reset();
      writeQueue.dispose();
    }

    Future<bool> keepCurrent() async {
      if (_connectionOwner.isCurrent(connectionGeneration)) return true;
      await releaseSetup();
      try {
        if (ownsDevice) await device.disconnect();
        if (!device.isConnected) lease?.release();
      } catch (e) {
        debugPrint('BleManager: stale connection disconnect failed: $e');
      }
      return false;
    }

    try {
      lease = WatchBleCoordinator.shared.acquire(deviceId);
      if (device.isConnected) throw StateError('设备已被其他功能连接');
      ownsDevice = true;
      _connectingDevice = device;
      _connectingGeneration = connectionGeneration;
      await WatchBleCoordinator.shared.stopScanning();
      if (!await keepCurrent()) return false;
      debugPrint('BleManager: connecting to $deviceName ($deviceId)');

      // Connect with timeout.
      // flutter_blue_plus 2.x requires an explicit License declaration.
      // HoneyBox is an internal debugging tool and uses the nonprofit tier.
      await device.connect(
        license: License.nonprofit,
        timeout: Duration(seconds: allowJw ? 20 : 10),
      );
      if (!await keepCurrent()) {
        return false;
      }
      debugPrint('BleManager: connected, discovering services');

      // Listen for disconnection (AFTER connect succeeds, skip initial state).
      connectionStateSub = device.connectionState.skip(1).listen((
        BluetoothConnectionState cs,
      ) {
        if (!_connectionOwner.isCurrent(connectionGeneration)) return;
        if (cs == BluetoothConnectionState.disconnected) {
          debugPrint(
            'BleManager: link dropped after '
            '$_streamNotifyCount FFC5 notifications',
          );
          _onDisconnected(connectionGeneration);
        }
      });

      // Discover services and try to find BLE characteristics
      await device.discoverServices();
      if (!await keepCurrent()) {
        return false;
      }

      final characteristics =
          <BleGattCharacteristic<BluetoothCharacteristic>>[];
      final services = device.servicesList;
      final jwConnected = await _attachJw(
        services: services,
        lease: lease,
        allowJw: allowJw || _requireJwProfile,
        device: device,
        connectionGeneration: connectionGeneration,
        connectionStateSub: connectionStateSub,
        writeQueue: writeQueue,
        keepCurrent: keepCurrent,
        onPublished: () => published = true,
      );
      if (jwConnected != null) return jwConnected;
      if (_requireJwProfile) {
        throw StateError('完整 JW 服务不可用，拒绝回退至旧协议');
      }
      for (final s in services) {
        debugPrint('BleManager: service ${s.uuid}');
        for (final c in s.characteristics) {
          debugPrint(
            'BleManager: characteristic ${c.uuid} '
            'write=${c.properties.write} '
            'writeWithoutResponse=${c.properties.writeWithoutResponse} '
            'notify=${c.properties.notify} '
            'indicate=${c.properties.indicate}',
          );
          characteristics.add(
            BleGattCharacteristic<BluetoothCharacteristic>(
              c,
              c.uuid.toString(),
              write: c.properties.write,
              writeWithoutResponse: c.properties.writeWithoutResponse,
              notify: c.properties.notify,
              indicate: c.properties.indicate,
            ),
          );
        }
      }

      final profile = BleGattProfile.select(characteristics);
      final commandTx = profile.commandReady ? profile.commandTx : null;
      final commandRx = profile.commandReady ? profile.commandRx : null;
      var streamTx = profile.streamReady ? profile.streamTx : null;
      var streamRx = profile.streamReady ? profile.streamRx : null;

      // Resolve the MTU exactly once after discovery, regardless of which pair
      // is available. Both protocols use the actual negotiated value.
      var mtu = kMinAttMtu;
      if (Platform.isAndroid) {
        try {
          mtu = await device.requestMtu(512);
        } catch (e) {
          debugPrint('BleManager: requestMtu failed, using default MTU: $e');
        }
      } else {
        // flutter_blue_plus gates BluetoothDevice.requestMtu to Android, so
        // asking through it here would throw and pin the link at 23 bytes —
        // seven bytes of frame payload per write, which stalls projection.
        mtu = await negotiatePlatformMtu(device.remoteId);
      }
      // A platform that reports nothing usable leaves the MTU at the spec
      // floor even though the link almost certainly negotiated more. Probe
      // upward from an optimistic chunk and let rejected writes calibrate it.
      final reportedChunk = streamChunkSizeForMtu(mtu);
      final probing = mtu <= kMinAttMtu;
      _chunkCalibrator = BleChunkCalibrator(
        initial: probing ? kProbeStreamChunk : reportedChunk,
      );
      // Android's stack blocks each unacknowledged write until the controller
      // has room; Windows accepts them in ~1.5ms and silently drops whatever
      // the connection event cannot carry. Measured against this link, a 60ms
      // connection event carries a handful of packets, so space the writes to
      // a rate the radio can actually sustain.
      final pacingBitrate = resolveStreamPacingBitrate(Platform.environment);
      _streamPacer = Platform.isAndroid
          ? null
          : BleWritePacer(
              minSpacing: spacingForBitrate(
                chunkBytes: streamChunkSize,
                bitsPerSecond: pacingBitrate,
              ),
            );
      debugPrint(
        'BleManager: mtu=$mtu streamChunk=$streamChunkSize'
        '${probing ? ' (probing; platform reported no MTU)' : ''}'
        '${_streamPacer == null ? '' : ' pacing=${_streamPacer!.minSpacing.inMicroseconds / 1000}ms@${pacingBitrate}bps'}',
      );

      // Windows leaves the link on a 30-60ms interval by default, which caps
      // projection well below the encoder's budget. Ask for the fast profile;
      // a refusal only means the link stays at the system default.
      if (_linkTuning.isSupported) {
        final remoteId = device.remoteId.str;
        if (await _linkTuning.requestThroughput(remoteId)) {
          _tunedRemoteId = remoteId;
          debugPrint('BleManager: requested throughput-optimized link');
        }
        if (!await keepCurrent()) {
          return false;
        }
      }
      if (!await keepCurrent()) {
        return false;
      }

      if (commandTx != null && commandRx != null) {
        await commandRx.setNotifyValue(true);
        if (!await keepCurrent()) {
          return false;
        }

        final engine = L1Engine(
          writeFn: (Uint8List chunk) =>
              _enqueueWrite(connectionGeneration, writeQueue, commandTx, chunk),
        )..setMtu(mtu);
        l1 = engine;
        // Route any inbound command-channel L2 frame not consumed by a file
        // transfer (e.g. WiFi provisioning CMD 0x0D) to command listeners.
        engine.onL2Data = (payload) {
          if (!_disposed && _connectionOwner.isCurrent(connectionGeneration)) {
            _commandNotifyController.add(payload);
          }
        };

        commandNotificationSub = commandRx.onValueReceived.listen((data) {
          if (_connectionOwner.isCurrent(connectionGeneration)) {
            engine.onNotified(Uint8List.fromList(data));
          }
        });

        transferSession = FileTransferSession(
          sendL2: (Uint8List frame) => engine.sendL2(frame),
          attachToL1: (FileTransferSession s) {
            engine.attach(s);
            engine.onAck = (int seq, bool ok) => s.onL1Ack(seq, ok);
          },
          detachFromL1: () {
            engine.detach();
            engine.onAck = null;
          },
          onLog: (String message) => debugPrint('L2: $message'),
        );
      } else {
        debugPrint(
          'BleManager: command characteristics not found; '
          'continuing without L1/file transfer',
        );
      }

      // Enable the Stream Service notify (FFC5) if the device exposes it.
      if (streamTx != null && streamRx != null) {
        try {
          await streamRx.setNotifyValue(true);
          if (!await keepCurrent()) {
            return false;
          }
          streamNotificationSub = streamRx.onValueReceived.listen((data) {
            if (!_disposed &&
                _connectionOwner.isCurrent(connectionGeneration)) {
              // Counting every FFC5 notification separates "the device went
              // quiet" from "only some message types stopped arriving".
              _streamNotifyCount++;
              if (_streamNotifyCount <= 4 || _streamNotifyCount % 10 == 0) {
                final key = data.length > 2 ? data[2] : -1;
                debugPrint(
                  'BleManager: FFC5 #$_streamNotifyCount '
                  'len=${data.length} key=0x${key.toRadixString(16)}',
                );
              }
              _streamNotifyController.add(Uint8List.fromList(data));
            }
          });
          debugPrint('BleManager: Stream Service ready (FFC4/FFC5)');
        } catch (e) {
          // A stale setup may only release its own local resources. It must not
          // cancel or clear a replacement connection's published stream pair.
          if (!await keepCurrent()) return false;
          debugPrint('BleManager: Stream Service FFC5 subscribe failed: $e');
          await streamNotificationSub?.cancel();
          streamNotificationSub = null;
          streamTx = null;
          streamRx = null;
        }
      }

      BluetoothCharacteristic? naviCtrlTxChar;
      BluetoothCharacteristic? naviCtrlRxChar;
      BluetoothCharacteristic? naviDataTxChar;
      BluetoothCharacteristic? naviDataRxChar;
      for (final characteristic in characteristics) {
        final uuid = characteristic.uuid.toUpperCase();
        if (uuid.contains('FFD1') &&
            (characteristic.write || characteristic.writeWithoutResponse)) {
          naviCtrlTxChar = characteristic.value;
        }
        if (uuid.contains('FFD2') &&
            (characteristic.notify || characteristic.indicate)) {
          naviCtrlRxChar = characteristic.value;
        }
        if (uuid.contains('FFD3') && characteristic.writeWithoutResponse) {
          naviDataTxChar = characteristic.value;
        }
        if (uuid.contains('FFD4') &&
            (characteristic.notify || characteristic.indicate)) {
          naviDataRxChar = characteristic.value;
        }
      }

      BleGattEndpoint<BluetoothCharacteristic>? naviCtrlTx;
      BleGattEndpoint<BluetoothCharacteristic>? naviDataTx;
      StreamSubscription<List<int>>? naviCtrlSub;
      StreamSubscription<List<int>>? naviDataSub;
      L1Engine? naviL1;
      if (naviCtrlTxChar != null &&
          naviCtrlRxChar != null &&
          naviDataTxChar != null &&
          naviDataRxChar != null) {
        try {
          final ctrlTx = BleGattEndpoint<BluetoothCharacteristic>(
            naviCtrlTxChar,
            withoutResponse: true,
          );
          final dataTx = BleGattEndpoint<BluetoothCharacteristic>(
            naviDataTxChar,
            withoutResponse: true,
          );
          await naviCtrlRxChar.setNotifyValue(true);
          if (!await keepCurrent()) return false;
          naviCtrlSub = naviCtrlRxChar.onValueReceived.listen((data) {
            if (_connectionOwner.isCurrent(connectionGeneration)) {
              naviL1?.onNotified(Uint8List.fromList(data));
            }
          });
          final engine = L1Engine(
            writeFn: (Uint8List chunk) => _enqueueWrite(
              connectionGeneration,
              writeQueue,
              ctrlTx,
              chunk,
              fatal: false,
            ),
          )..setMtu(mtu);
          naviL1 = engine;
          engine.onL2Data = (payload) {
            if (!_disposed &&
                _connectionOwner.isCurrent(connectionGeneration)) {
              _naviCtrlL2Controller.add(payload);
            }
          };
          await naviDataRxChar.setNotifyValue(true);
          if (!await keepCurrent()) return false;
          naviDataSub = naviDataRxChar.onValueReceived.listen((data) {
            if (!_disposed &&
                _connectionOwner.isCurrent(connectionGeneration)) {
              _naviDataNotifyController.add(Uint8List.fromList(data));
            }
          });
          naviCtrlTx = ctrlTx;
          naviDataTx = dataTx;
          debugPrint('BleManager: Navi Projection ready (FFD1-FFD4)');
        } catch (e) {
          if (!await keepCurrent()) return false;
          debugPrint('BleManager: Navi Projection setup failed: $e');
          await naviCtrlSub?.cancel();
          await naviDataSub?.cancel();
          naviCtrlSub = null;
          naviDataSub = null;
          naviCtrlTx = null;
          naviDataTx = null;
          naviCtrlRxChar = null;
          naviDataRxChar = null;
          naviL1 = null;
        }
      }

      if (!await keepCurrent()) return false;
      final resources = _BleConnectionResources(
        device: device,
        lease: lease,
        mtu: mtu,
        writeQueue: writeQueue,
        connectionStateSub: connectionStateSub,
        commandTx: commandTx,
        commandRx: commandRx,
        streamTx: streamTx,
        streamRx: streamRx,
        commandNotificationSub: commandNotificationSub,
        streamNotificationSub: streamNotificationSub,
        l1: l1,
        session: transferSession,
        naviCtrlTx: naviCtrlTx,
        naviCtrlRx: naviCtrlRxChar,
        naviDataTx: naviDataTx,
        naviDataRx: naviDataRxChar,
        naviCtrlSub: naviCtrlSub,
        naviDataSub: naviDataSub,
        naviL1: naviL1,
      );
      if (!_connectionOwner.publish(connectionGeneration, resources)) {
        await keepCurrent();
        return false;
      }
      published = true;

      var connected = false;
      _connectionOwner.runIfCurrent(connectionGeneration, () {
        if (_connectingGeneration == connectionGeneration &&
            identical(_connectingDevice, device)) {
          _connectingGeneration = null;
          _connectingDevice = null;
        }
        _setStreamAvailable(resources.streamReady);
        _setState(BleState.connected);
        final streamState = resources.streamReady ? 'on' : 'off';
        final naviState = naviProjAvailable ? 'on' : 'off';
        debugPrint(
          'BleManager: ready, mtu=$mtu, stream=$streamState, '
          'naviProj=$naviState',
        );
        connected = true;
      });
      return connected;
    } catch (e) {
      debugPrint('BleManager: connect failed: $e');
      await releaseSetup();
      try {
        if (ownsDevice) await device.disconnect();
        if (!ownsDevice || !device.isConnected) lease?.release();
      } catch (disconnectError) {
        debugPrint(
          'BleManager: failed connection disconnect error: '
          '$disconnectError',
        );
      }
      final cleared = _connectionOwner.clearIfCurrent(
        connectionGeneration,
        (resources) =>
            _releaseConnectionResources(resources, disconnectLink: false),
      );
      if (cleared) {
        _clearConnectingDevice(connectionGeneration, device);
        _deviceId = null;
        _deviceName = null;
        _setState(BleState.disconnected);
      }
      return false;
    }
  }

  /// Gracefully disconnect and clean up.
  Future<void> disconnect() async {
    if (_state == BleState.disconnected || _state == BleState.disconnecting) {
      return;
    }
    final connectionGeneration = _connectionOwner.generation;
    final device = _connectionOwner.value?.device ??
        (_connectingGeneration == connectionGeneration
            ? _connectingDevice
            : null);
    _setState(BleState.disconnecting);
    await device?.disconnect();
    _onDisconnected(connectionGeneration);
  }

  // --------------------------------------------------------------------------
  // Write queue (L1 → characteristic)
  // --------------------------------------------------------------------------

  Future<void> _write(
    BleWriteQueue writeQueue,
    BleGattEndpoint<BluetoothCharacteristic> endpoint,
    Uint8List bytes, {
    bool fatal = true,
  }) {
    return writeQueue.enqueue(
      () => endpoint.value.write(
        bytes,
        withoutResponse: endpoint.withoutResponse,
      ),
      fatal: fatal,
    );
  }

  /// Enqueue a raw L1 chunk for delivery over a command characteristic.
  void _enqueueWrite(
    int connectionGeneration,
    BleWriteQueue writeQueue,
    BleGattEndpoint<BluetoothCharacteristic> endpoint,
    Uint8List chunk, {
    bool fatal = true,
  }) {
    if (_disposed || !_connectionOwner.isCurrent(connectionGeneration)) {
      return;
    }
    // L1 exposes a synchronous writer. The queue owns fatal-error teardown, so
    // suppress this mirrored Future error after enqueueing it.
    unawaited(
      _write(
        writeQueue,
        endpoint,
        chunk,
        fatal: fatal,
      ).catchError((Object _) {}),
    );
  }

  /// Send one raw L2 stream message over the FFC4 characteristic (no L1, no
  /// fragmentation — the caller keeps each message within one ATT write).
  /// Shares the serial queue so it never races other GATT writes.
  Future<void> writeStream(Uint8List l2) {
    final connection = _connectionOwner.value;
    final endpoint = connection?.streamTx;
    if (_disposed || connection == null || !connection.streamReady) {
      return Future.error(StateError('Stream Service 未就绪'));
    }
    return _writeStreamPaced(connection.writeQueue, endpoint!, l2);
  }

  Future<void> _writeStreamPaced(
    BleWriteQueue writeQueue,
    BleGattEndpoint<BluetoothCharacteristic> endpoint,
    Uint8List l2,
  ) async {
    final pacer = _streamPacer;
    if (pacer != null) {
      final delay = pacer.delayBefore(_streamClock.elapsed);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      pacer.recordWrite(_streamClock.elapsed);
    }
    final started = Stopwatch()..start();
    return _write(writeQueue, endpoint, l2).then((_) {
      started.stop();
      // Only a write that filled the probed chunk confirms it; KS_OPEN and
      // friends are far smaller and succeed on any link.
      _chunkCalibrator?.recordSuccess(l2.length);
      // The queue is serial, so each write's wall time is the link's
      // per-packet cost; the window report says whether the controller is
      // pushing one packet per connection event or several.
      final report = _streamWriteStats.record(
        bytes: l2.length,
        elapsed: started.elapsed,
      );
      if (report != null) debugPrint('BleManager: stream write $report');
    });
  }

  /// Send one L2 command frame over the L1 command channel (FFC1). L1 handles
  /// framing, CRC, and MTU chunking. Returns the assigned L1 sequence number, or
  /// null if the command channel isn't ready. Used by WiFi provisioning
  /// (CMD 0x0D); file transfers use [FileTransferSession] instead.
  int? sendCommand(Uint8List l2) {
    final connection = _connectionOwner.value;
    if (_disposed || connection == null || !connection.commandReady) {
      return null;
    }
    return connection.l1!.sendL2(l2);
  }

  /// Send one L2 command frame over the navi control channel (FFD1/FFD2, with
  /// L1 framing). Returns the assigned L1 sequence number, or null if the navi
  /// control channel isn't ready.
  int? sendNaviControl(Uint8List l2) {
    final connection = _connectionOwner.value;
    if (_disposed || connection == null || connection.naviL1 == null) {
      return null;
    }
    return connection.naviL1!.sendL2(l2);
  }

  /// Send one raw L2 data message over the FFD3 characteristic (no L1).
  /// Shares the serial write queue with all other GATT writes.
  Future<void> writeNaviData(Uint8List l2) {
    final connection = _connectionOwner.value;
    final endpoint = connection?.naviDataTx;
    if (_disposed || connection == null || endpoint == null) {
      return Future.error(StateError('导航投屏数据通道未就绪'));
    }
    return _write(connection.writeQueue, endpoint, l2, fatal: false);
  }

  // --------------------------------------------------------------------------
  // Internal
  // --------------------------------------------------------------------------

  /// Returns true when a JW watch was adopted, false when that attempt failed,
  /// and null when [services] is not a JW target (caller continues with media).
  Future<bool?> _attachJw({
    required List<BluetoothService> services,
    required WatchBleLease? lease,
    required bool allowJw,
    required BluetoothDevice device,
    required int connectionGeneration,
    required StreamSubscription<BluetoothConnectionState>? connectionStateSub,
    required BleWriteQueue writeQueue,
    required Future<bool> Function() keepCurrent,
    required void Function() onPublished,
  }) async {
    if (!allowJw || connectionStateSub == null) return null;

    BluetoothCharacteristic? tx;
    BluetoothCharacteristic? rx;
    for (final service in services) {
      final chars = {
        for (final c in service.characteristics)
          JwGattProfile.normalize(c.uuid.toString()): c,
      };
      final candidateTx = chars[JwGattProfile.tx];
      final candidateRx = chars[JwGattProfile.rx];
      if (!JwGattProfile.matches(
        service.uuid.toString(),
        chars.keys.toSet(),
        txWrite: candidateTx?.properties.write ?? false,
        rxNotify: candidateRx?.properties.notify ?? false,
        allowJw: allowJw,
      )) {
        continue;
      }
      tx = candidateTx;
      rx = candidateRx;
      break;
    }
    if (tx == null || rx == null) return null;

    var jwMtu = kMinAttMtu;
    try {
      jwMtu = await device.requestMtu(247);
    } catch (_) {
      jwMtu = kMinAttMtu;
    }
    if (!await keepCurrent()) return false;

    final notifications = StreamController<Uint8List>.broadcast(sync: true);
    final disconnected = StreamController<void>.broadcast(sync: true);
    final binding = _JwNotifyBinding();
    BluetoothCharacteristic? alert;
    for (final service in services) {
      if (JwGattProfile.normalize(service.uuid.toString()) !=
          JwGattProfile.normalize('1802')) {
        continue;
      }
      for (final c in service.characteristics) {
        if (JwGattProfile.normalize(c.uuid.toString()) ==
                JwGattProfile.normalize('2a06') &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          alert = c;
        }
      }
    }
    final alertEndpoint = alert;
    final txChar = tx;
    final rxChar = rx;
    late final JwRawChannel port;
    port = JwRawChannel(
      mtu: jwMtu,
      notifications: notifications.stream,
      disconnected: disconnected.stream,
      subscribeFn: () async {
        binding.subscription = rxChar.onValueReceived.listen((bytes) {
          final current = _connectionOwner.value;
          if (!_disposed &&
              current?.jwTransport == port &&
              !notifications.isClosed) {
            notifications.add(Uint8List.fromList(bytes));
          }
        });
        try {
          if (!await rxChar.setNotifyValue(true)) {
            throw StateError('FF03 subscription refused');
          }
        } catch (_) {
          await binding.subscription?.cancel();
          binding.subscription = null;
          rethrow;
        }
      },
      writeFn: (bytes, {required bool withResponse}) async {
        await txChar.write(bytes, withoutResponse: !withResponse);
      },
      readFn: (uuid) async {
        for (final s in services) {
          for (final c in s.characteristics) {
            if (JwGattProfile.normalize(c.uuid.toString()) ==
                JwGattProfile.normalize(uuid)) {
              return Uint8List.fromList(await c.read());
            }
          }
        }
        return null;
      },
      disconnectFn: () async {
        final current = _connectionOwner.value;
        if (current?.jwTransport != port ||
            !identical(current?.device, device)) {
          return;
        }
        await disconnect();
      },
      immediateAlertWithResponse: alertEndpoint?.properties.write ?? false,
      immediateAlertWriteFn: alertEndpoint == null
          ? null
          : (bytes) async {
              await alertEndpoint.write(
                bytes,
                withoutResponse: !alertEndpoint.properties.write,
              );
            },
    );

    final resources = _BleConnectionResources(
      device: device,
      lease: lease,
      mtu: jwMtu,
      writeQueue: writeQueue,
      connectionStateSub: connectionStateSub,
      jwTransport: port,
      jwNotifyController: notifications,
      jwDisconnectController: disconnected,
      jwNotify: binding,
    );
    if (!_connectionOwner.publish(connectionGeneration, resources)) {
      await notifications.close();
      await disconnected.close();
      await keepCurrent();
      return false;
    }
    onPublished();
    await port.subscribe();
    if (!await keepCurrent()) return false;

    var connected = false;
    _connectionOwner.runIfCurrent(connectionGeneration, () {
      if (_connectingGeneration == connectionGeneration &&
          identical(_connectingDevice, device)) {
        _connectingGeneration = null;
        _connectingDevice = null;
      }
      _setState(BleState.connected);
      debugPrint('BleManager: JW FF03 ready; FF02 response writes, MTU=$jwMtu');
      connected = true;
    });
    return connected;
  }

  void _setState(BleState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_disposed) {
      _stateController.add(newState);
    }
  }

  void _setStreamAvailable(bool available) {
    if (_streamAvailable == available) return;
    _streamAvailable = available;
    if (!_disposed) {
      _streamAvailabilityController.add(available);
    }
  }

  void _clearConnectingDevice(
    int connectionGeneration,
    BluetoothDevice device,
  ) {
    if (_connectingGeneration == connectionGeneration &&
        identical(_connectingDevice, device)) {
      _connectingGeneration = null;
      _connectingDevice = null;
    }
  }

  void _retireConnectionResources(_BleConnectionResources? resources) {
    _releaseConnectionResources(resources, disconnectLink: true);
  }

  void _releaseConnectionResources(
    _BleConnectionResources? resources, {
    bool disconnectLink = false,
  }) {
    if (resources == null) return;
    // The owner invokes retirement before clearing its active value, so stream
    // consumers observe false before the active pair disappears.
    if (resources.streamReady) _setStreamAvailable(false);
    // The probed write budget, its sampling and its pacing belong to the
    // retired link.
    _chunkCalibrator = null;
    _streamWriteStats.reset();
    _streamPacer?.reset();
    _streamPacer = null;
    _streamNotifyCount = 0;
    final tuned = _tunedRemoteId;
    if (tuned != null) {
      _tunedRemoteId = null;
      unawaited(_linkTuning.release(tuned));
    }
    final jwDown = resources.jwDisconnectController;
    if (jwDown != null && !jwDown.isClosed) {
      jwDown.add(null);
    }
    resources.jwTransport?.invalidate();
    unawaited(resources.jwNotifyController?.close() ?? Future<void>.value());
    unawaited(
      resources.jwDisconnectController?.close() ?? Future<void>.value(),
    );
    unawaited(resources.jwNotify?.subscription?.cancel());
    resources.session?.abort();
    resources.writeQueue.abort(StateError('BLE connection ended'));
    resources.writeQueue.dispose();
    unawaited(resources.commandNotificationSub?.cancel());
    unawaited(resources.streamNotificationSub?.cancel());
    unawaited(resources.naviCtrlSub?.cancel());
    unawaited(resources.naviDataSub?.cancel());
    unawaited(resources.connectionStateSub.cancel());
    resources.l1?.reset();
    resources.naviL1?.reset();
    if (disconnectLink || resources.device.isConnected) {
      unawaited(resources.device.disconnect().then((_) {
        if (!resources.device.isConnected) resources.lease?.release();
      }).catchError((Object error) {
        debugPrint(
            'BLE disconnect not confirmed; device lease retained: $error');
      }));
    } else {
      resources.lease?.release();
    }
  }

  void _onDisconnected(int connectionGeneration) {
    final cleared = _connectionOwner.clearIfCurrent(
      connectionGeneration,
      (resources) => _releaseConnectionResources(resources),
    );
    if (!cleared) return;
    final connectingDevice = _connectingDevice;
    if (connectingDevice != null) {
      _clearConnectingDevice(connectionGeneration, connectingDevice);
    }
    _deviceId = null;
    _deviceName = null;
    _setState(BleState.disconnected);
  }

  void _cleanup() {
    stopScan();
    _scanGeneration++;
    _cancelAdapterWait();
    _scanActive = false;
    final connectionGeneration = _connectionOwner.generation;
    _connectionOwner.clearIfCurrent(
      connectionGeneration,
      _retireConnectionResources,
    );

    final connectingDevice = _connectingDevice;
    if (_connectingGeneration == connectionGeneration &&
        connectingDevice != null) {
      _clearConnectingDevice(connectionGeneration, connectingDevice);
      unawaited(connectingDevice.disconnect().catchError((Object _) {}));
    }

    _scanSub?.cancel();
    _scanSub = null;
    _scanErrorSub?.cancel();
    _scanErrorSub = null;

    _deviceId = null;
    _deviceName = null;
  }
}
