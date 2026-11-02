import 'connection/connection_state.dart';

sealed class WSException implements Exception {
  const WSException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 非就绪状态下调用业务接口。
class WSNotReadyException extends WSException {
  const WSNotReadyException(this.state)
      : super('device is not ready (state: $state)');

  final WSConnectionState state;
}

/// 尝试发送已丢弃的协议。
class WSDroppedProtocolException extends WSException {
  const WSDroppedProtocolException(super.message);
}

enum WSTimeoutKind { ack, reply, connect, discover, confirm, syncIdle }

class WSTimeoutException extends WSException {
  const WSTimeoutException(this.kind, super.message);

  final WSTimeoutKind kind;
}

/// 设备回 ERR ACK 且重试用尽。
class WSNackException extends WSException {
  const WSNackException(super.message);
}

/// 请求过程中链路断开。
class WSDisconnectedException extends WSException {
  const WSDisconnectedException(super.message);
}

enum WSConnectFailure {
  bluetoothUnavailable,
  gattMissing,
  bindRejected,
  confirmRejected,
  confirmTimeout,
  initFailed,
  timeout,
  disconnected,
}

/// 连接流程失败。
class WSConnectException extends WSException {
  const WSConnectException(this.stage, this.reason, String message)
      : super(message);

  final WSConnectionState stage;
  final WSConnectFailure reason;
}

class WSSyncInProgressException extends WSException {
  const WSSyncInProgressException() : super('a sync is already in progress');
}

class WSQueueFullException extends WSException {
  const WSQueueFullException(int capacity)
      : super('send queue is full (capacity: $capacity)');
}
