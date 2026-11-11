import 'package:ws_watch_sdk/ws_watch_sdk.dart';

enum WsHistorySyncPhase { idle, syncing, success, failed }

/// UI state for one health sync round (Demo-owned).
final class WsHistorySyncRunState {
  const WsHistorySyncRunState({
    required this.phase,
    this.plan,
    this.receivedWire = 0,
    this.totalWire = 0,
    this.receivedRowsByCategory = const {},
    this.failure,
    this.startedAt,
    this.finishedAt,
  });

  const WsHistorySyncRunState.idle()
      : phase = WsHistorySyncPhase.idle,
        plan = null,
        receivedWire = 0,
        totalWire = 0,
        receivedRowsByCategory = const {},
        failure = null,
        startedAt = null,
        finishedAt = null;

  final WsHistorySyncPhase phase;
  final WSHistorySyncPlan? plan;
  final int receivedWire;
  final int totalWire;
  final Map<WSHistorySyncCategory, int> receivedRowsByCategory;
  final WSHistorySyncFailure? failure;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isActive => phase == WsHistorySyncPhase.syncing;

  bool get awaitingDevicePlan =>
      phase == WsHistorySyncPhase.syncing && plan == null;

  WsHistorySyncRunState copyWith({
    WsHistorySyncPhase? phase,
    WSHistorySyncPlan? plan,
    int? receivedWire,
    int? totalWire,
    Map<WSHistorySyncCategory, int>? receivedRowsByCategory,
    WSHistorySyncFailure? failure,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearFailure = false,
  }) =>
      WsHistorySyncRunState(
        phase: phase ?? this.phase,
        plan: plan ?? this.plan,
        receivedWire: receivedWire ?? this.receivedWire,
        totalWire: totalWire ?? this.totalWire,
        receivedRowsByCategory:
            receivedRowsByCategory ?? this.receivedRowsByCategory,
        failure: clearFailure ? null : (failure ?? this.failure),
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
      );
}
