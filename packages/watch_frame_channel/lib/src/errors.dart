enum WatchFrameErrorKind {
  disconnected,
  receive,
  write,
  ackTimeout,
  writeTimeout,
  nack,
  queueFull
}

class WatchFrameException implements Exception {
  const WatchFrameException(this.kind, this.message);
  final WatchFrameErrorKind kind;
  final String message;
  @override
  String toString() => 'WatchFrameException(${kind.name}): $message';
}

/// A failed chunk invalidates the frame boundary, including control ACK writes.
class WatchFrameWriteException extends WatchFrameException {
  const WatchFrameWriteException(this.cause, {required this.isControl})
      : super(WatchFrameErrorKind.write, 'frame write failed');
  final Object cause;
  final bool isControl;
}
