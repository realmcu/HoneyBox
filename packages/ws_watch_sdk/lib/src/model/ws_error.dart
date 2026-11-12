/// Stable machine-readable error categories returned by the public WS SDK.
///
/// Prefer branching on [WSErrorCode] in app code (i18n, retry policy, analytics).
/// [WSException.msg] is always English and intended for developers and logs;
/// it is not localized UI copy.
enum WSErrorCode {
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

  /// Protocol rule violation or unexpected payload (command-specific).
  protocol,

  /// Transport-layer failure not covered by a more specific code.
  transport,

  /// Health history sync saw no progress within the idle window.
  historySyncIdleTimeout,

  /// Health history sync ended with a device or parser failure.
  historySyncFailed,

  /// Device reported sync busy; caller should retry later.
  historySyncBusy,
}

/// An SDK error with a stable [code] and an English developer-facing [msg].
///
/// Example: `WSException(WSErrorCode.ackTimeout, 'ACK timeout')`.
/// [toString] is suitable for debug logs (`WS ackTimeout: ACK timeout`).
final class WSException implements Exception {
  const WSException(this.code, this.msg);

  /// Stable category for integration logic.
  final WSErrorCode code;

  /// English description; do not treat as end-user localized string.
  final String msg;

  /// Readable alias for integrations that prefer the conventional name.
  String get message => msg;

  @override
  String toString() => 'WS ${code.name}: $msg';
}
