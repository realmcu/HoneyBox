import 'dart:typed_data';
import 'models.dart';

abstract interface class WatchTransport {
  /// Creates an idle connection. Subscribe before calling connect.
  WatchTransportConnection createConnection(WatchDeviceTarget target);
}

abstract interface class WatchTransportConnection {
  WatchDeviceTarget get target;
  WatchTransportState get state;
  Stream<WatchTransportState> get stateChanges;
  Stream<Uint8List> get received;
  Stream<WatchDisconnectEvent> get disconnected;
  WatchWriteLimits get writeLimits;

  /// A connection is single-use; create another object to reconnect.
  Future<void> connect();

  /// Writes opaque bytes. Completion does not imply a frame ACK or L2 reply.
  /// Bytes must be copied before asynchronous work can observe caller mutation.
  Future<void> write(Uint8List bytes);

  /// Idempotent. Pending work must finish; old callbacks cannot revive a link.
  Future<void> disconnect();
  Future<void> dispose();
}
