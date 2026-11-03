import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import '../connection/connection_state.dart';
import '../errors.dart';
import 'connection.dart';

/// Keeps the existing WS Link/error contract while transport is extracted.
class WSByteTransportAdapter implements WSTransportConnection {
  WSByteTransportAdapter(this.connection);
  final WatchTransportConnection connection;
  @override
  String get deviceId => connection.target.deviceId;
  @override
  int get maxWriteLength => connection.writeLimits.maxWriteLength;
  @override
  Stream<Uint8List> get received => connection.received;
  @override
  Stream<void> get disconnected => connection.disconnected.map<void>((_) {});

  Future<void> _mapError(Future<void> Function() action) async {
    try {
      await action();
    } on WatchTransportException catch (error) {
      if (error.code == WatchTransportErrorCode.writeTooLarge) {
        throw ArgumentError('chunk exceeds transport write limit');
      }
      throw WSDisconnectedException(error.message);
    }
  }

  @override
  Future<void> prepare() async {
    try {
      await connection.connect();
    } on WatchBleException catch (error) {
      final reason = switch (error.code) {
        WatchTransportErrorCode.profileUnavailable =>
          WSConnectFailure.gattMissing,
        WatchTransportErrorCode.permissionDenied ||
        WatchTransportErrorCode.adapterOff =>
          WSConnectFailure.bluetoothUnavailable,
        WatchTransportErrorCode.timeout => WSConnectFailure.timeout,
        WatchTransportErrorCode.busy => WSConnectFailure.alreadyConnected,
        _ => WSConnectFailure.transportUnavailable,
      };
      throw WSConnectException(
          error.stage == BleConnectionStage.connecting
              ? WSConnectionState.connecting
              : WSConnectionState.discovering,
          reason,
          error.message);
    } on WatchTransportException catch (error) {
      throw WSDisconnectedException(error.message);
    }
  }

  @override
  Future<void> write(Uint8List chunk) =>
      _mapError(() => connection.write(chunk));
  @override
  Future<void> disconnect() => _mapError(connection.disconnect);
  @override
  Future<void> dispose() => _mapError(connection.dispose);
}
