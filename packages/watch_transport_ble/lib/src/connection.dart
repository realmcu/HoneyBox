import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';
import 'backend.dart';
import 'coordinator.dart';
import 'flutter_blue_backend.dart';
import 'mtu.dart';
import 'profile.dart';
import 'tuning.dart';
import 'write_queue.dart';

final class WatchBleTransport implements WatchTransport {
  WatchBleTransport(
      {required this.config,
      WatchBleBackend? backend,
      WatchBleCoordinator? coordinator,
      BleLinkTuning? tuning})
      : backend = backend ?? FlutterBlueWatchBackend.shared,
        coordinator = coordinator ?? WatchBleCoordinator.shared,
        tuning = tuning ?? BleLinkTuning();
  final WatchBleConfig config;
  final WatchBleBackend backend;
  final WatchBleCoordinator coordinator;
  final BleLinkTuning tuning;
  @override
  WatchBleConnection createConnection(WatchDeviceTarget target) {
    if (target.transportId != 'ble') {
      throw const WatchTransportException(
          WatchTransportErrorCode.unsupported, 'Expected a BLE target');
    }
    return WatchBleConnection._(target, this);
  }
}

/// Single-use byte connection. SDK owns protocol, ACKs and business initialization.
final class WatchBleConnection implements WatchTransportConnection {
  WatchBleConnection._(this.target, this._transport) {
    _received = StreamController<Uint8List>.broadcast(
        sync: true, onListen: () => scheduleMicrotask(_flush));
    _writes = BleWriteQueue(
        onFatalError: (e, _) => _end(
            WatchDisconnectReason.failed, _error(e, BleConnectionStage.write)));
  }
  @override
  final WatchDeviceTarget target;
  final WatchBleTransport _transport;
  WatchBleConfig get _config => _transport.config;
  late final StreamController<Uint8List> _received;
  final _states = StreamController<WatchTransportState>.broadcast();
  final _down = StreamController<WatchDisconnectEvent>.broadcast();
  final _buffer = Queue<Uint8List>();
  int _bufferSize = 0, _mtu = kMinAttMtu;
  bool _flushing = false,
      _closed = false,
      _ownsPhysical = false,
      _sawConnected = false,
      _notifyEnabled = false;
  WatchTransportState _state = WatchTransportState.idle;
  WatchBleException? _failure;
  final _abort = Completer<void>();
  Future<void>? _connecting, _setup, _cleaning, _disposing;
  final _operations = <Future<void>>{};
  WatchBleLease? _lease;
  WatchBleDevicePort? _device;
  WatchBleCharacteristicPort? _tx, _rx;
  bool _withoutResponse = false;
  List<WatchBleGattService> _services = [];
  final _subscriptions = <StreamSubscription<dynamic>>[];
  late final BleWriteQueue _writes;
  BleConnectionStage _stage = BleConnectionStage.connecting;
  BleConnectionStage get stage => _stage;
  @override
  WatchTransportState get state => _state;
  @override
  Stream<WatchTransportState> get stateChanges => _states.stream;
  @override
  Stream<Uint8List> get received => _received.stream;
  @override
  Stream<WatchDisconnectEvent> get disconnected => _down.stream;
  @override
  WatchWriteLimits get writeLimits =>
      WatchWriteLimits(maxWriteLength: math.min(resolveAttMtu(_mtu) - 3, 512));
  int get mtu => resolveAttMtu(_mtu);

  WatchBleException _error(Object error, BleConnectionStage stage) {
    if (error is WatchBleException) return error;
    final text = error.toString().toLowerCase();
    final code = error is WatchTransportException
        ? error.code
        : error is TimeoutException
            ? WatchTransportErrorCode.timeout
            : text.contains('permission') || text.contains('unauthorized')
                ? WatchTransportErrorCode.permissionDenied
                : stage == BleConnectionStage.read
                    ? WatchTransportErrorCode.read
                    : stage == BleConnectionStage.write
                        ? WatchTransportErrorCode.write
                        : WatchTransportErrorCode.connect;
    return WatchBleException(
        code,
        error is WatchTransportException
            ? error.message
            : 'BLE ${stage.name} failed: $error',
        stage: stage);
  }

  WatchBleException get _closedError =>
      _failure ??
      WatchBleException(
          state == WatchTransportState.disposed
              ? WatchTransportErrorCode.disposed
              : WatchTransportErrorCode.closed,
          'BLE connection ended',
          stage: _stage);
  void _check() {
    if (_closed) throw _closedError;
  }

  void _setState(WatchTransportState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  Future<T> _track<T>(Future<T> work) {
    late final Future<void> settled;
    settled = work
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() => _operations.remove(settled));
    _operations.add(settled);
    return work;
  }

  Future<T> _operation<T>(Future<T> work) =>
      _track(work).timeout(_config.operationTimeout);
  Future<T> _untilClosed<T>(Future<T> work) {
    if (_closed) {
      work.ignore();
      return Future.error(_closedError);
    }
    return Future.any([work, _abort.future.then<T>((_) => throw _closedError)]);
  }

  @override
  Future<void> connect() {
    if (_closed) return Future.error(_closedError);
    return _connecting ??= _connect();
  }

  Future<void> _connect() async {
    _setState(WatchTransportState.connecting);
    _setup = _prepare();
    try {
      await _untilClosed(_setup!);
      _check();
      _stage = BleConnectionStage.ready;
      _setState(WatchTransportState.connected);
    } catch (error, stack) {
      _end(WatchDisconnectReason.failed, _error(error, _stage));
      Error.throwWithStackTrace(_closedError, stack);
    }
  }

  Future<void> _prepare() async {
    _lease = _transport.coordinator.acquire(target.deviceId);
    await _transport.coordinator.stopScanning();
    _check();
    await _operation(_transport.backend.ensureReady());
    _check();
    final device = _device = _transport.backend.device(target.deviceId);
    if (device.isConnected) {
      throw const WatchTransportException(WatchTransportErrorCode.busy,
          'Device is already connected outside this runtime');
    }
    _subscriptions.add(device.connectionChanges.listen((connected) {
      if (connected) _sawConnected = true;
      if (!connected && _sawConnected && !_closed) {
        _end(WatchDisconnectReason.remote);
      }
    },
        onError: (Object error) =>
            _end(WatchDisconnectReason.failed, _error(error, _stage))));
    _subscriptions.add(device.mtuChanges.listen((value) {
      if (!_closed) _mtu = resolveAttMtu(value);
    },
        onError: (Object error) =>
            _end(WatchDisconnectReason.failed, _error(error, _stage))));
    _ownsPhysical = true;
    await _track(device.connect(_config.connectTimeout))
        .timeout(_config.connectTimeout);
    _check();
    _sawConnected = true;
    _mtu = resolveAttMtu(device.mtu);
    _stage = BleConnectionStage.discovering;
    _services = await _operation(device.discoverServices());
    _check();
    final profile = _config.profile;
    final services = _services
        .where((s) => normalizeBleUuid(s.uuid) == profile.service)
        .toList();
    if (services.length != 1) {
      throw _profileError('Expected one matching GATT service');
    }
    final txs = services.single.characteristics
        .where((c) => normalizeBleUuid(c.uuid) == profile.tx)
        .toList();
    final rxs = services.single.characteristics
        .where((c) => normalizeBleUuid(c.uuid) == profile.rx)
        .toList();
    if (txs.length != 1 || rxs.length != 1) {
      throw _profileError('Expected unique TX and RX characteristics');
    }
    _tx = txs.single;
    _rx = rxs.single;
    _withoutResponse = switch (profile.writeMode) {
      BleWriteMode.withResponse => false,
      BleWriteMode.withoutResponse => true,
      BleWriteMode.preferWithoutResponse => _tx!.canWriteWithoutResponse,
    };
    if ((_withoutResponse ? !_tx!.canWriteWithoutResponse : !_tx!.canWrite) ||
        (!_rx!.canNotify && !_rx!.canIndicate)) {
      throw _profileError(
          'GATT properties do not support the configured profile');
    }
    _stage = BleConnectionStage.subscribing;
    _subscriptions.add(_rx!.received.listen(_receive,
        onError: (Object error) =>
            _end(WatchDisconnectReason.failed, _error(error, _stage))));
    _notifyEnabled = true;
    await _operation(_rx!.setNotify(true));
    _check();
    if (_config.requestThroughput) {
      await _operation(_transport.tuning.requestThroughput(target.deviceId));
      _check();
    }
  }

  WatchBleException _profileError(String message) =>
      WatchBleException(WatchTransportErrorCode.profileUnavailable, message,
          stage: _stage);

  @override
  Future<void> write(Uint8List bytes) => writeGatt(bytes);

  /// Optional BLE side port; ordinary transports do not expose GATT read/modes.
  Future<void> writeGatt(Uint8List bytes, {bool? withoutResponse}) {
    if (_closed) return Future.error(_closedError);
    if (state != WatchTransportState.connected) {
      return Future.error(const WatchTransportException(
          WatchTransportErrorCode.notConnected, 'BLE is not connected'));
    }
    final copy = Uint8List.fromList(bytes);
    final mode = withoutResponse ?? _withoutResponse;
    if (mode ? !_tx!.canWriteWithoutResponse : !_tx!.canWrite) {
      return Future.error(_profileError('Unsupported write mode'));
    }
    // Oversize is a caller error and must not tear down an otherwise healthy connection.
    if (copy.length > writeLimits.maxWriteLength) {
      return Future.error(const WatchTransportException(
          WatchTransportErrorCode.writeTooLarge,
          'BLE write exceeds current limit'));
    }
    return _writes.enqueue(() async {
      _check();
      if (copy.length > writeLimits.maxWriteLength) {
        throw const WatchTransportException(
            WatchTransportErrorCode.writeTooLarge, 'MTU changed before write');
      }
      try {
        await _operation(_tx!.write(copy, withoutResponse: mode));
        _check();
      } catch (error) {
        throw _error(error, BleConnectionStage.write);
      }
    });
  }

  Future<Uint8List> readGatt(
      {required String service, required String characteristic}) {
    if (_closed) return Future.error(_closedError);
    if (state != WatchTransportState.connected) {
      return Future.error(const WatchTransportException(
          WatchTransportErrorCode.notConnected, 'BLE is not connected'));
    }
    final matches = [
      for (final s in _services)
        if (normalizeBleUuid(s.uuid) == normalizeBleUuid(service))
          ...s.characteristics.where((c) =>
              normalizeBleUuid(c.uuid) == normalizeBleUuid(characteristic) &&
              c.canRead)
    ];
    if (matches.length != 1) {
      return Future.error(
          _profileError('Expected one readable GATT characteristic'));
    }
    late Uint8List value;
    return _writes.enqueue(() async {
      _check();
      try {
        value = Uint8List.fromList(await _operation(matches.single.read()))
            .asUnmodifiableView();
        _check();
      } catch (error) {
        final failure = _error(error, BleConnectionStage.read);
        if (error is TimeoutException) {
          _end(WatchDisconnectReason.failed, failure);
        }
        throw failure;
      }
    }, fatal: false).then((_) => value);
  }

  void _receive(List<int> data) {
    if (_closed || data.isEmpty) return;
    if (_bufferSize + data.length > _config.maxBufferedBytes) {
      _end(
          WatchDisconnectReason.failed,
          WatchBleException(WatchTransportErrorCode.receiveOverflow,
              'BLE receive buffer full',
              stage: _stage));
      return;
    }
    _buffer.add(Uint8List.fromList(data).asUnmodifiableView());
    _bufferSize += data.length;
    _flush();
  }

  void _flush() {
    if (_flushing) return;
    _flushing = true;
    try {
      while (!_closed && _received.hasListener && _buffer.isNotEmpty) {
        final data = _buffer.removeFirst();
        _bufferSize -= data.length;
        _received.add(data);
      }
    } finally {
      _flushing = false;
    }
  }

  void _end(WatchDisconnectReason reason, [WatchBleException? error]) {
    if (_closed) return;
    _closed = true;
    _failure = error;
    _abort.complete();
    _setState(WatchTransportState.disconnecting);
    _writes.abort(_closedError);
    _buffer.clear();
    _bufferSize = 0;
    _setState(WatchTransportState.disconnected);
    _down.add(WatchDisconnectEvent(reason, error: error));
    // Defer until _setup has been assigned even when setup fails synchronously.
    scheduleMicrotask(() {
      _cleanup().ignore();
    });
  }

  Future<void> _cleanup() =>
      _cleaning ??= _release().catchError((Object error) {
        _cleaning =
            null; // The lease stays held; explicit disconnect/dispose may retry.
        throw _error(error, BleConnectionStage.cleanup);
      });
  Future<void> _release() async {
    final device = _device;
    // First disconnect cancels a pending native connect; second handles late success.
    if (_ownsPhysical) {
      try {
        await device!.disconnect();
      } catch (_) {}
    }
    try {
      await _setup;
    } catch (_) {}
    while (_operations.isNotEmpty) {
      await Future.wait(_operations.toList());
    }
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    if (_ownsPhysical) {
      if (_notifyEnabled && device!.isConnected) {
        try {
          await _rx?.setNotify(false);
        } catch (_) {}
      }
      if (_config.requestThroughput) {
        await _transport.tuning.release(target.deviceId);
      }
      await device!.disconnect();
      if (device.isConnected) {
        throw StateError('BLE disconnect not confirmed; lease retained');
      }
      _ownsPhysical = false;
    }
    _lease?.release();
    _lease = null;
  }

  @override
  Future<void> disconnect() async {
    _end(WatchDisconnectReason.requested);
    await _cleanup();
  }

  @override
  Future<void> dispose() =>
      _disposing ??= _dispose().catchError((Object error) {
        _disposing = null;
        throw error;
      });
  Future<void> _dispose() async {
    _end(WatchDisconnectReason.disposed);
    await _cleanup();
    _writes.dispose();
    if (state == WatchTransportState.disposed) return;
    _setState(WatchTransportState.disposed);
    await Future.wait([_received.close(), _states.close(), _down.close()]);
  }
}
