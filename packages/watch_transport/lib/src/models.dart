/// A transport endpoint, not a persistent business/user identity.
final class WatchDeviceTarget {
  WatchDeviceTarget({required this.transportId, required this.deviceId}) {
    if (transportId.trim().isEmpty || deviceId.trim().isEmpty) {
      throw ArgumentError('transportId and deviceId must not be empty');
    }
  }

  final String transportId;
  final String deviceId;

  @override
  bool operator ==(Object other) =>
      other is WatchDeviceTarget &&
      transportId == other.transportId &&
      deviceId == other.deviceId;

  @override
  int get hashCode => Object.hash(transportId, deviceId);
}

enum WatchTransportState {
  idle,
  connecting,
  connected,
  disconnecting,
  disconnected,
  disposed,
}

final class WatchWriteLimits {
  WatchWriteLimits({required this.maxWriteLength}) {
    if (maxWriteLength <= 0) {
      throw ArgumentError.value(maxWriteLength, 'maxWriteLength');
    }
  }

  /// Maximum bytes in one write, with no BLE-specific header assumptions.
  final int maxWriteLength;
}

enum WatchTransportErrorCode {
  notConnected,
  closed,
  disposed,
  connect,
  timeout,
  write,
  writeTooLarge,
  busy,
  deviceNotFound,
  unsupported,
  receiveOverflow,
}

class WatchTransportException implements Exception {
  const WatchTransportException(this.code, this.message);

  final WatchTransportErrorCode code;
  final String message;

  @override
  String toString() => 'WatchTransportException(${code.name}): $message';
}

enum WatchDisconnectReason { requested, remote, failed, disposed }

final class WatchDisconnectEvent {
  const WatchDisconnectEvent(this.reason, {this.error});
  final WatchDisconnectReason reason;
  final WatchTransportException? error;
}
