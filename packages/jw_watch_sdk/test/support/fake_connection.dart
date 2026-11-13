import 'dart:async';
import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';

class FakeConnection implements WatchTransportConnection {
  FakeConnection(this.target);
  @override
  final WatchDeviceTarget target;
  final rx = StreamController<Uint8List>.broadcast(sync: true);
  final down = StreamController<WatchDisconnectEvent>.broadcast(sync: true);
  final states = StreamController<WatchTransportState>.broadcast(sync: true);
  final writes = <Uint8List>[];
  Future<void> Function(Uint8List)? onWrite;
  Completer<void>? connectGate;
  Completer<void>? disposeGate;
  bool failDispose = false;
  bool failConnect = false;
  int disposeCalls = 0;
  @override
  WatchTransportState state = WatchTransportState.idle;
  @override
  Stream<Uint8List> get received => rx.stream;
  @override
  Stream<WatchDisconnectEvent> get disconnected => down.stream;
  @override
  Stream<WatchTransportState> get stateChanges => states.stream;
  @override
  WatchWriteLimits get writeLimits => WatchWriteLimits(maxWriteLength: 244);
  @override
  Future<void> connect() async {
    if (failConnect) throw StateError('connect failed');
    await connectGate?.future;
    if (state == WatchTransportState.disposed) throw StateError('closed');
    state = WatchTransportState.connected;
  }

  @override
  Future<void> write(Uint8List bytes) async {
    writes.add(Uint8List.fromList(bytes));
    await onWrite?.call(bytes);
  }

  @override
  Future<void> disconnect() async {
    if (state == WatchTransportState.disposed) return;
    state = WatchTransportState.disconnected;
  }

  void remoteDisconnect() {
    state = WatchTransportState.disconnected;
    down.add(const WatchDisconnectEvent(WatchDisconnectReason.remote));
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await disposeGate?.future;
    if (failDispose) throw StateError('cleanup failed');
    if (state == WatchTransportState.disposed) return;
    state = WatchTransportState.disposed;
    await Future.wait([rx.close(), down.close(), states.close()]);
  }
}

class FakeTransport implements WatchTransport {
  final connections = <FakeConnection>[];
  void Function(FakeConnection)? configure;
  @override
  FakeConnection createConnection(WatchDeviceTarget target) {
    final connection = FakeConnection(target);
    configure?.call(connection);
    connections.add(connection);
    return connection;
  }
}
