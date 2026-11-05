import 'package:jw_watch_sdk/jw_watch_sdk.dart';

enum JwHistorySyncPhase { idle, syncing, success, failed }

/// UI state for one health sync round (Demo-owned).
final class JwHistorySyncRunState {
  const JwHistorySyncRunState({
    required this.phase,
    this.plan,
    this.receivedWire = 0,
    this.totalWire = 0,
    this.receivedRowsByCategory = const {},
    this.roundRecords = const {},
    this.failure,
    this.startedAt,
    this.finishedAt,
    this.eventLog = const [],
  });

  const JwHistorySyncRunState.idle()
      : phase = JwHistorySyncPhase.idle,
        plan = null,
        receivedWire = 0,
        totalWire = 0,
        receivedRowsByCategory = const {},
        roundRecords = const {},
        failure = null,
        startedAt = null,
        finishedAt = null,
        eventLog = const [];

  final JwHistorySyncPhase phase;
  final JWHistorySyncPlan? plan;
  final int receivedWire;
  final int totalWire;
  final Map<JWHistorySyncCategory, int> receivedRowsByCategory;
  final Map<JWHistorySyncCategory, List<Object>> roundRecords;
  final JWHistorySyncFailure? failure;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<String> eventLog;

  bool get isActive => phase == JwHistorySyncPhase.syncing;

  bool get awaitingDevicePlan =>
      phase == JwHistorySyncPhase.syncing && plan == null;

  static const maxSamplesPerCategory = 50;
  static const maxEventLogEntries = 100;

  JwHistorySyncRunState copyWith({
    JwHistorySyncPhase? phase,
    JWHistorySyncPlan? plan,
    int? receivedWire,
    int? totalWire,
    Map<JWHistorySyncCategory, int>? receivedRowsByCategory,
    Map<JWHistorySyncCategory, List<Object>>? roundRecords,
    JWHistorySyncFailure? failure,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<String>? eventLog,
    bool clearFailure = false,
  }) =>
      JwHistorySyncRunState(
        phase: phase ?? this.phase,
        plan: plan ?? this.plan,
        receivedWire: receivedWire ?? this.receivedWire,
        totalWire: totalWire ?? this.totalWire,
        receivedRowsByCategory:
            receivedRowsByCategory ?? this.receivedRowsByCategory,
        roundRecords: roundRecords ?? this.roundRecords,
        failure: clearFailure ? null : (failure ?? this.failure),
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        eventLog: eventLog ?? this.eventLog,
      );
}
