/// Stable machine-readable error categories returned by the public JW SDK.
///
/// Prefer branching on [JWErrorCode] in app code (i18n, retry policy, analytics).
/// [JWException.msg] is always English and intended for developers and logs;
/// it is not localized UI copy.
enum JWErrorCode {
  /// Link or session was torn down; in-flight work must not continue.
  disposed,

  /// Link or channel cannot accept this call right now (e.g. busy, not open).
  unavailable,

  /// BLE / GATT transport is no longer connected.
  transportDisconnected,

  /// L2 business reply was not received before the reply deadline.
  businessReplyTimeout,

  /// L1 frame was not acknowledged before the ACK deadline (includes retries).
  ackTimeout,

  /// Device or stack responded with NACK for the outbound frame.
  nack,

  /// GATT write did not complete before the write deadline.
  writeTimeout,

  /// Inbound frame could not be received or decoded at the frame layer.
  receiveFailed,

  /// Outbound frame could not be written at the frame layer.
  writeFailed,

  /// Outbound frame queue is full; back off and retry later.
  queueFull,

  /// Operation was cancelled before completion (reserved for future use).
  cancelled,

  /// Health history sync saw no progress within the idle window.
  historySyncIdleTimeout,

  /// Transport-layer failure not covered by a more specific code.
  transport,

  /// Protocol rule violation or unexpected payload (command-specific).
  protocol,
}

/// An SDK error with a stable [code] and an English developer-facing [msg].
///
/// Example: `JWException(JWErrorCode.ackTimeout, 'ACK timeout')`.
/// [toString] is suitable for debug logs (`JW ackTimeout: ACK timeout`).
final class JWException implements Exception {
  const JWException(this.code, this.msg);

  /// Stable category for integration logic.
  final JWErrorCode code;

  /// English description; do not treat as end-user localized string.
  final String msg;

  /// Readable alias for integrations that prefer the conventional name.
  String get message => msg;

  @override
  String toString() => 'JW ${code.name}: $msg';
}
