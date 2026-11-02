import 'dart:async';
import 'dart:typed_data';

import '../errors.dart';
import '../transport/connection.dart';

const kWsWatchSimDeviceId = 'ws-watch-sim';

/// Internal duplex memory wire. Test hooks never appear in the public SDK API.
class SimWatchSession implements WSTransportConnection {
  SimWatchSession._(this.maxWriteLength);
  static (SimWatchSession, SimWatchSession) pair({int mtu = 247}) {
    RangeError.checkValueInInterval(mtu, 23, 517, 'mtu');
    final host = SimWatchSession._(mtu - 3),
        device = SimWatchSession._(mtu - 3);
    host._peer = device;
    device._peer = host;
    return (host, device);
  }

  late final SimWatchSession _peer;
  final _received = StreamController<Uint8List>.broadcast(sync: true);
  final _disconnected = StreamController<void>.broadcast(sync: true);
  bool _closed = false, _prepared = false, _disposed = false;
  Future<void> Function(Uint8List bytes)? interceptWrite;
  @override
  String get deviceId => kWsWatchSimDeviceId;
  @override
  final int maxWriteLength;
  @override
  Stream<Uint8List> get received => _received.stream;
  @override
  Stream<void> get disconnected => _disconnected.stream;
  @override
  Future<void> prepare() async {
    if (_closed) throw const WSDisconnectedException('simulator closed');
    _prepared = true;
  }

  @override
  Future<void> write(Uint8List chunk) async {
    if (!_prepared || _closed || _peer._closed) {
      throw const WSDisconnectedException('simulator not connected');
    }
    if (chunk.length > maxWriteLength) throw ArgumentError('chunk exceeds MTU');
    final copy = Uint8List.fromList(chunk);
    if (interceptWrite != null) {
      await interceptWrite!(copy);
    } else {
      deliver(copy);
    }
  }

  /// Device-side fault scripts can drop, mutate or delay bytes before delivery.
  void deliver(Uint8List bytes) {
    if (!_closed && !_peer._closed) {
      _peer._received.add(Uint8List.fromList(bytes));
    }
  }

  @override
  Future<void> disconnect() async {
    _close();
    _peer._close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _disconnected.add(null);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _received.close();
    await _disconnected.close();
  }
}
