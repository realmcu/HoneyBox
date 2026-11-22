import 'dart:typed_data';

final class WSDeviceDataCapabilities {
  const WSDeviceDataCapabilities({
    this.displayWidth,
    this.displayHeight,
    this.maxCompressedFrameBytes,
    this.suggestedJpegQuality,
    this.featureBits,
    this.maxChunkBytes,
    this.requestedFps,
    this.unknown = const {},
  });

  final int? displayWidth;
  final int? displayHeight;
  final int? maxCompressedFrameBytes;
  final int? suggestedJpegQuality;
  final int? featureBits;
  final int? maxChunkBytes;
  final int? requestedFps;
  final Map<int, Uint8List> unknown;
}

final class WSTodayNotificationConfig {
  const WSTodayNotificationConfig({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.intervalMinutes,
  });

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;
}

final class WSTodayNotificationConfigResult {
  const WSTodayNotificationConfigResult({
    required this.result,
    required this.config,
  });
  final int result;
  final WSTodayNotificationConfig config;
  bool get isSuccess => result == 0;
}

final class WSSportDetailPoint {
  const WSSportDetailPoint({
    required this.elapsedSeconds,
    required this.heartRateBpm,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesTenthKcal,
    required this.latitudeE7,
    required this.longitudeE7,
    required this.altitudeMeters,
  });

  final int elapsedSeconds;
  final int? heartRateBpm;
  final int steps;
  final int distanceMeters;
  final int caloriesTenthKcal;
  final int? latitudeE7;
  final int? longitudeE7;
  final int? altitudeMeters;
}

final class WSSportDetail {
  const WSSportDetail({required this.sportId, required this.points});
  final int sportId;
  final List<WSSportDetailPoint> points;
}
