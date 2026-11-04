/// Stable machine-readable error categories returned by the public JW SDK.
enum JWErrorCode {
  disposed,
  unavailable,
  transportDisconnected,
  businessReplyTimeout,
  ackTimeout,
  nack,
  writeTimeout,
  receiveFailed,
  writeFailed,
  queueFull,
  transport,
  protocol,
}

/// An SDK error with a stable [code] and an English developer-facing [msg].
final class JWException implements Exception {
  const JWException(this.code, this.msg);

  final JWErrorCode code;
  final String msg;

  /// Readable alias for integrations that prefer the conventional name.
  String get message => msg;

  @override
  String toString() => 'JW ${code.name}: $msg';
}
