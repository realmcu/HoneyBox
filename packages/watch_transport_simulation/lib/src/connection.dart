import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';

/// One side of a duplex memory connection. It never decodes frames or L2.
final class WatchSimulationConnection implements WatchTransportConnection {
  WatchSimulationConnection._(this.target, int maxWriteLength,
      this.maxBufferedBytes, this.connectTimeout)
      : writeLimits = WatchWriteLimits(maxWriteLength: maxWriteLength) {
    if (maxBufferedBytes <= 0) {
      throw ArgumentError.value(maxBufferedBytes, 'maxBufferedBytes');
    }
    if (connectTimeout != null && connectTimeout! <= Duration.zero) {
      throw ArgumentError.value(connectTimeout, 'connectTimeout');
    }
    _received = StreamController<Uint8List>.broadcast(
        sync: true, onListen: () => scheduleMicrotask(_flushReceived));
  }

  static (WatchSimulationConnection, WatchSimulationConnection) pair({
    required WatchDeviceTarget target,
    int maxWriteLength = 244,
    int maxBufferedBytes = 64 * 1024,
    Duration? connectTimeout,
  }) {
    final host = WatchSimulationConnection._(
        target, maxWriteLength, maxBufferedBytes, connectTimeout);
    final peer = WatchSimulationConnection._(
        target, maxWriteLength, maxBufferedBytes, connectTimeout);
    host._peer = peer;
    peer._peer = host;
    return (host, peer);
  }

  @override
  final WatchDeviceTarget target;
  @override
  final WatchWriteLimits writeLimits;
  final int maxBufferedBytes;
  final Duration? connectTimeout;
  late final WatchSimulationConnection _peer;
  late final StreamController<Uint8List> _received;
  final _states = StreamController<WatchTransportState>.broadcast();
  final _down = StreamController<WatchDisconnectEvent>.broadcast();
  final _ended = Completer<void>();
  final _abortWaiters = <void Function(WatchTransportException)>{};
  final _buffer = Queue<Uint8List>();
  int _bufferedBytes = 0;
  bool _flushing = false;
  WatchTransportState _state = WatchTransportState.idle;
  WatchTransportException? _terminalError;
  Future<void>? _connecting, _disposing, _cleanup;
  Future<void> _writes = Future.value();

  /// Deterministic byte fault hook. Call deliver to forward, or return to drop.
  /// Disconnect cancels the caller's wait; late deliver calls are discarded.
  Future<void> Function(Uint8List bytes)? interceptWrite;

  /// Runtime hooks, intended for transport factories rather than protocol code.
  Future<void> Function()? onConnect;
  Future<void> Function()? onDisconnect;

  @override
  WatchTransportState get state => _state;
  @override
  Stream<WatchTransportState> get stateChanges => _states.stream;
  @override
  Stream<Uint8List> get received => _received.stream;
  @override
  Stream<WatchDisconnectEvent> get disconnected => _down.stream;

  bool get _closed => _ended.isCompleted;

  void _setState(WatchTransportState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  WatchTransportException get _closedError =>
      _terminalError ??
      WatchTransportException(
          state == WatchTransportState.disposed
              ? WatchTransportErrorCode.disposed
              : WatchTransportErrorCode.closed,
          'Connection ended');

  Future<T> _untilClosed<T>(Future<T> work) async {
    if (_closed) {
      work.ignore();
      throw _closedError;
    }
    final interrupted = Completer<T>();
    void abort(WatchTransportException error) =>
        interrupted.completeError(error);
    _abortWaiters.add(abort);
    try {
      return await Future.any([work, interrupted.future]);
    } finally {
      _abortWaiters.remove(abort);
    }
  }

  @override
  Future<void> connect() {
    if (_closed) return Future.error(_closedError);
    return _connecting ??= _connect();
  }

  Future<void> _connect() async {
    _setState(WatchTransportState.connecting);
    try {
      if (_closed) throw _closedError;
      var attachment = Future<void>.sync(() => onConnect?.call());
      if (connectTimeout case final timeout?) {
        attachment = attachment.timeout(timeout, onTimeout: () {
          throw const WatchTransportException(
              WatchTransportErrorCode.timeout, 'Connection timed out');
        });
      }
      await _untilClosed(attachment);
      if (_closed) throw _closedError;
      _setState(WatchTransportState.connected);
    } catch (error, stack) {
      if (!_closed) {
        final failure = error is WatchTransportException
            ? error
            : const WatchTransportException(
                WatchTransportErrorCode.connect, 'Device attachment failed');
        _terminate(WatchDisconnectReason.failed, failure);
        _peer._terminate(WatchDisconnectReason.remote, failure);
      }
      Error.throwWithStackTrace(_closedError, stack);
    }
  }

  void _checkWrite() {
    if (_closed || _peer._closed) throw _closedError;
    if (state != WatchTransportState.connected ||
        (_peer.state != WatchTransportState.connected &&
            _peer.state != WatchTransportState.connecting)) {
      throw const WatchTransportException(
          WatchTransportErrorCode.notConnected, 'Both endpoints must connect');
    }
  }

  @override
  Future<void> write(Uint8List bytes) {
    try {
      _checkWrite();
      if (bytes.length > writeLimits.maxWriteLength) {
        throw const WatchTransportException(
            WatchTransportErrorCode.writeTooLarge, 'Write exceeds limit');
      }
      final copy = Uint8List.fromList(bytes);
      final work = _writes.then((_) async {
        _checkWrite();
        final hook = interceptWrite;
        if (hook == null) {
          deliver(copy);
        } else {
          try {
            await hook(copy);
          } catch (error) {
            if (error is WatchTransportException) rethrow;
            throw const WatchTransportException(
                WatchTransportErrorCode.write, 'Device write failed');
          }
        }
        _checkWrite();
      });
      _writes = work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
      return _untilClosed(work);
    } catch (error, stack) {
      return Future.error(error, stack);
    }
  }

  /// Fault scripts can forward/split/mutate bytes. Old connections never revive.
  void deliver(Uint8List bytes) {
    if (_closed || _peer._closed) return;
    if (state != WatchTransportState.connected ||
        (_peer.state != WatchTransportState.connected &&
            _peer.state != WatchTransportState.connecting)) {
      return;
    }
    _peer._receive(Uint8List.fromList(bytes));
  }

  void _receive(Uint8List bytes) {
    if (bytes.isEmpty) return;
    if (_bufferedBytes + bytes.length > maxBufferedBytes) {
      // Buffer pressure is a local receive failure, not a simulated radio
      // disconnect. Drop the buffered bytes and leave both endpoints live.
      _buffer.clear();
      _bufferedBytes = 0;
      return;
    }
    _buffer.add(bytes);
    _bufferedBytes += bytes.length;
    _flushReceived();
  }

  void _flushReceived() {
    if (_flushing) return;
    _flushing = true;
    try {
      while (!_closed && _received.hasListener && _buffer.isNotEmpty) {
        final bytes = _buffer.removeFirst();
        _bufferedBytes -= bytes.length;
        _received.add(bytes.asUnmodifiableView());
      }
    } finally {
      _flushing = false;
    }
  }

  void _terminate(WatchDisconnectReason reason,
      [WatchTransportException? error]) {
    if (_closed) return;
    _terminalError = error;
    final cleanup = Completer<void>();
    _cleanup = cleanup.future;
    _cleanup!.ignore();
    _ended.complete();
    for (final abort in _abortWaiters.toList()) {
      abort(_closedError);
    }
    _setState(WatchTransportState.disconnecting);
    _buffer.clear();
    _bufferedBytes = 0;
    _setState(WatchTransportState.disconnected);
    _down.add(WatchDisconnectEvent(reason, error: error));
    // Cleanup begins immediately, even on remote disconnect/receive overflow.
    Future<void>.sync(() => onDisconnect?.call()).then(
        (_) => cleanup.complete(),
        onError: (Object error, StackTrace stack) =>
            cleanup.completeError(error, stack));
  }

  @override
  Future<void> disconnect() async {
    if (_closed) {
      await _cleanup;
      return;
    }
    _terminate(WatchDisconnectReason.requested);
    _peer._terminate(WatchDisconnectReason.remote);
    await Future.wait([_cleanup!, _peer._cleanup!]);
  }

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    if (!_closed) {
      _terminate(WatchDisconnectReason.disposed);
      _peer._terminate(WatchDisconnectReason.remote);
    }
    try {
      await _cleanup;
    } finally {
      interceptWrite = null;
      _setState(WatchTransportState.disposed);
      await Future.wait([_received.close(), _down.close(), _states.close()]);
    }
  }
}
