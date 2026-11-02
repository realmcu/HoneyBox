import 'dart:typed_data';

import 'connection/connection_state.dart';
import 'model/feature.dart';

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

enum WSTimeoutKind { write, ack, reply, connect, discover, confirm, syncIdle }

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
  transportUnavailable,
  cancelled,
  alreadyConnected,
  storageFailed,
  protocolError,
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

class WSProtocolDecodeException extends WSException {
  WSProtocolDecodeException(this.cmd, this.key, List<int> raw, super.message)
      : raw = Uint8List.fromList(raw).asUnmodifiableView();
  final int cmd, key;
  final Uint8List raw;
}

class WSSessionInvalidatedException extends WSException {
  const WSSessionInvalidatedException(super.message);
}

class WSDisposedException extends WSException {
  const WSDisposedException() : super('object has been disposed');
}

class WSStorageException extends WSException {
  const WSStorageException(super.message);
}

class WSUnsupportedException extends WSException {
  const WSUnsupportedException(this.feature)
      : super('device explicitly reports this feature unsupported');
  final WSFeature feature;
}
