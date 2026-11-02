import 'dart:typed_data';

/// Internal byte transport. Link owns write serialization and framing.
abstract interface class WSTransportConnection {
  String get deviceId;
  int get maxWriteLength;
  Stream<Uint8List> get received;
  Stream<void> get disconnected;
  Future<void> prepare();
  Future<void> write(Uint8List chunk);
  Future<void> disconnect();
  Future<void> dispose();
}
