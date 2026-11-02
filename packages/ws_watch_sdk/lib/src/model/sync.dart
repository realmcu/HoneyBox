/// M5 intentionally exposes single-type history only.
enum WSHistoryType {
  steps(1),
  heartRate(3);

  const WSHistoryType(this.requestKey);
  final int requestKey;
  int get dataKey => requestKey + 0x20;
}

enum WSSyncStatus { completed, incomplete, confirmationUnknown }

enum WSSyncConfirmation { notSent, acked, unknown }

enum WSSyncStage { requesting, receiving, persisting, confirming, finished }

enum WSSyncFailure {
  cancelled,
  disconnected,
  idleTimeout,
  bufferOverflow,
  protocolError,
  countMismatch,
  storageFailed,
  deviceBusy,
  deviceFailed,
  invalidParameter,
  requestFailed,
  confirmationFailed
}

class WSSyncProgress {
  const WSSyncProgress(
      {required this.syncId,
      required this.type,
      required this.stage,
      this.announced,
      this.received = 0,
      this.committed = 0,
      this.inserted = 0,
      this.duplicates = 0,
      this.decodeFailures = 0,
      this.pendingBytes = 0});
  final String syncId;
  final WSHistoryType type;
  final WSSyncStage stage;
  final int? announced;
  final int received,
      committed,
      inserted,
      duplicates,
      decodeFailures,
      pendingBytes;
}

class WSSyncResult {
  const WSSyncResult(
      {required this.status,
      required this.progress,
      required this.confirmation,
      this.reason,
      this.message,
      this.deviceResultCode});
  final WSSyncStatus status;
  final WSSyncProgress progress;
  final WSSyncConfirmation confirmation;
  final WSSyncFailure? reason;
  final String? message;
  final int? deviceResultCode;
}

abstract interface class WSSyncSession {
  String get syncId;
  Stream<WSSyncProgress> get progress;
  Future<WSSyncResult> get result;
  Future<void> cancel();
}

class WSSyncLog {
  const WSSyncLog(
      {required this.deviceId,
      required this.userId,
      required this.syncId,
      required this.startedAt,
      required this.endedAt,
      required this.announcedJson,
      required this.receivedJson,
      required this.confirmation,
      required this.result,
      this.deviceResultCode,
      this.reason});
  final String deviceId, userId, syncId, announcedJson, receivedJson;
  final DateTime startedAt, endedAt;
  final WSSyncConfirmation confirmation;
  final WSSyncStatus result;
  final int? deviceResultCode;
  final String? reason;
}
