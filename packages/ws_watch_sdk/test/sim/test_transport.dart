import 'dart:async';
import 'dart:typed_data';

import 'package:ws_watch_sdk/src/errors.dart';
import 'package:ws_watch_sdk/src/transport/connection.dart';

/// Scriptable byte transport; it does not reuse the device or host codecs.
class TestTransport implements WSTransportConnection {
  TestTransport({this.maxWriteLength = 20});
  final chunks = <Uint8List>[];
  final _rx = StreamController<Uint8List>.broadcast(sync: true);
  final _disconnect = StreamController<void>.broadcast(sync: true);
  Future<void> Function(Uint8List)? onWrite;
  bool closed = false;
  int disposeCount = 0;
  @override
  final int maxWriteLength;
  @override
  String get deviceId => 'scripted-device';
  @override
  Stream<Uint8List> get received => _rx.stream;
  @override
  Stream<void> get disconnected => _disconnect.stream;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> write(Uint8List chunk) async {
    if (closed) throw const WSDisconnectedException('closed');
    if (chunk.length > maxWriteLength) throw StateError('oversized chunk');
    chunks.add(Uint8List.fromList(chunk));
    await onWrite?.call(chunk);
  }

  void receive(List<int> bytes) {
    if (!closed) _rx.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> disconnect() async {
    if (closed) return;
    closed = true;
    _disconnect.add(null);
  }

  @override
  Future<void> dispose() async {
    if (disposeCount != 0) return;
    disposeCount++;
    await disconnect();
    await _rx.close();
    await _disconnect.close();
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
