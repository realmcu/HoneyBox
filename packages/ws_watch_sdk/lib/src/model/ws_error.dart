enum WSErrorCode {
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
  protocol,
  transport,
  historySyncIdleTimeout,
  historySyncFailed,
  historySyncBusy,
}

final class WSException implements Exception {
  const WSException(this.code, this.msg);

  final WSErrorCode code;
  final String msg;

  String get message => msg;

  @override
  String toString() => 'WS ${code.name}: $msg';
}
