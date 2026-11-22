final class WSIncomingCall {
  const WSIncomingCall({required this.number, this.name = ''});

  final String number;
  final String name;
}

final class WSAppNotification {
  const WSAppNotification({
    required this.id,
    required this.applicationType,
    required this.wallTimeSeconds,
    required this.title,
    required this.content,
  });

  final int id;
  final int applicationType;
  final int wallTimeSeconds;
  final String title;
  final String content;
}

final class WSMusicState {
  const WSMusicState({
    required this.playbackState,
    required this.volumePercent,
    this.song = '',
    this.artist = '',
  });

  final int playbackState;
  final int volumePercent;
  final String song;
  final String artist;
}

final class WSBatteryStatus {
  const WSBatteryStatus({
    required this.percent,
    required this.chargingState,
  });

  final int percent;
  final int chargingState;

  bool get isCharging => chargingState == 1;
  bool get isFull => chargingState == 2;
}

sealed class WSNotificationEvent {
  const WSNotificationEvent();
}

final class WSCallActionEvent extends WSNotificationEvent {
  const WSCallActionEvent(this.action);
  final int action;
}

final class WSMusicControlEvent extends WSNotificationEvent {
  const WSMusicControlEvent(this.action);
  final int action;
}

final class WSMusicStateRequestedEvent extends WSNotificationEvent {
  const WSMusicStateRequestedEvent();
}

final class WSFindWatchEndedEvent extends WSNotificationEvent {
  const WSFindWatchEndedEvent(this.reason);
  final int reason;
}

final class WSFindPhoneEvent extends WSNotificationEvent {
  const WSFindPhoneEvent(this.started);
  final bool started;
}

final class WSCameraShutterEvent extends WSNotificationEvent {
  const WSCameraShutterEvent();
}

final class WSBatteryEvent extends WSNotificationEvent {
  const WSBatteryEvent(this.status);
  final WSBatteryStatus status;
}
