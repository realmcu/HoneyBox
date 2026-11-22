import '../history/ws_history_models.dart';
import '../wire/ws_measure_command.dart';

final class WSSpotMeasureStatus {
  const WSSpotMeasureStatus({
    required this.active,
    required this.dataTypeCode,
    required this.initiator,
    required this.startedAtSeconds,
  });
  final bool active;
  final int dataTypeCode;
  final int initiator;
  final int startedAtSeconds;
}

final class WSSportRealtimeSnapshot {
  const WSSportRealtimeSnapshot({
    required this.mode,
    required this.state,
    required this.startedAtSeconds,
    required this.durationSeconds,
    required this.heartRateBpm,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesTenthKcal,
  });
  final int mode;
  final int state;
  final int startedAtSeconds;
  final int durationSeconds;
  final int? heartRateBpm;
  final int steps;
  final int distanceMeters;
  final int caloriesTenthKcal;
}

final class WSSportState {
  const WSSportState({required this.hasActiveSport, this.snapshot});
  final bool hasActiveSport;
  final WSSportRealtimeSnapshot? snapshot;
}

sealed class WSMeasureEvent {
  const WSMeasureEvent();
}

final class WSSpotRealtimeEvent extends WSMeasureEvent {
  const WSSpotRealtimeEvent({
    required this.lane,
    required this.value,
  });
  final WSSpotMeasureLane lane;
  final Object? value;
}

final class WSSpotResultEvent extends WSMeasureEvent {
  const WSSpotResultEvent({
    required this.lane,
    required this.result,
    this.record,
  });
  final WSSpotMeasureLane lane;
  final int result;
  final Object? record;
}

final class WSSportRealtimeEvent extends WSMeasureEvent {
  const WSSportRealtimeEvent(this.snapshot);
  final WSSportRealtimeSnapshot snapshot;
}

final class WSSportEndedEvent extends WSMeasureEvent {
  const WSSportEndedEvent({
    required this.result,
    required this.endedBy,
    this.summary,
  });
  final int result;
  final int endedBy;
  final WSSport? summary;
}
