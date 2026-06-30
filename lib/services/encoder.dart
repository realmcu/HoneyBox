import 'dart:async';

import 'package:flutter/services.dart';

/// Supported (and placeholder) encoder formats for the encoding test bench.
///
/// Only [h264] is implemented natively today; [jpeg] and [mvs1] are reserved
/// slots that the native layer rejects with a "not implemented" error.
enum EncoderFormat { h264, jpeg, mvs1 }

extension EncoderFormatX on EncoderFormat {
  /// Wire value sent to the native layer.
  String get wire => switch (this) {
        EncoderFormat.h264 => 'h264',
        EncoderFormat.jpeg => 'jpeg',
        EncoderFormat.mvs1 => 'mvs1',
      };

  String get label => switch (this) {
        EncoderFormat.h264 => 'H.264',
        EncoderFormat.jpeg => 'JPEG',
        EncoderFormat.mvs1 => 'MVS1',
      };

  /// Whether the format is wired up natively (vs. a placeholder).
  bool get implemented => this == EncoderFormat.h264;

  /// Whether an I-frame interval applies to this format.
  bool get hasIFrameInterval => this == EncoderFormat.h264;
}

/// Immutable encoder configuration mirrored by the native [EncoderConfig].
class EncoderConfig {
  final EncoderFormat format;

  /// Output (scaled) resolution.
  final int width;
  final int height;

  /// Center-crop / digital-zoom factor (1.0 = full field of view).
  final double cropZoom;

  final int fps;

  /// Encode quality expressed as a bitrate in bits per second.
  final int bitrate;

  /// I-frame (IDR) interval in seconds — H.264 only.
  final int iFrameIntervalSec;

  const EncoderConfig({
    this.format = EncoderFormat.h264,
    this.width = 640,
    this.height = 480,
    this.cropZoom = 1.0,
    this.fps = 15,
    this.bitrate = 2000000,
    this.iFrameIntervalSec = 1,
  });

  EncoderConfig copyWith({
    EncoderFormat? format,
    int? width,
    int? height,
    double? cropZoom,
    int? fps,
    int? bitrate,
    int? iFrameIntervalSec,
  }) {
    return EncoderConfig(
      format: format ?? this.format,
      width: width ?? this.width,
      height: height ?? this.height,
      cropZoom: cropZoom ?? this.cropZoom,
      fps: fps ?? this.fps,
      bitrate: bitrate ?? this.bitrate,
      iFrameIntervalSec: iFrameIntervalSec ?? this.iFrameIntervalSec,
    );
  }

  Map<String, dynamic> toWire() => {
        'format': format.wire,
        'width': width,
        'height': height,
        'cropZoom': cropZoom,
        'fps': fps,
        'bitrate': bitrate,
        'iFrameIntervalSec': iFrameIntervalSec,
      };

  /// Persisted form (format stored by enum index).
  Map<String, dynamic> toJson() => {
        'format': format.index,
        'width': width,
        'height': height,
        'cropZoom': cropZoom,
        'fps': fps,
        'bitrate': bitrate,
        'iFrameIntervalSec': iFrameIntervalSec,
      };

  factory EncoderConfig.fromJson(Map<String, dynamic> json) {
    final fmtIndex = (json['format'] as num?)?.toInt() ?? 0;
    return EncoderConfig(
      format: (fmtIndex >= 0 && fmtIndex < EncoderFormat.values.length)
          ? EncoderFormat.values[fmtIndex]
          : EncoderFormat.h264,
      width: (json['width'] as num?)?.toInt() ?? 640,
      height: (json['height'] as num?)?.toInt() ?? 480,
      cropZoom: (json['cropZoom'] as num?)?.toDouble() ?? 1.0,
      fps: (json['fps'] as num?)?.toInt() ?? 15,
      bitrate: (json['bitrate'] as num?)?.toInt() ?? 2000000,
      iFrameIntervalSec: (json['iFrameIntervalSec'] as num?)?.toInt() ?? 1,
    );
  }
}

/// The camera preview texture descriptor reported by the native layer.
class CameraInfo {
  final int textureId;
  final int previewWidth;
  final int previewHeight;
  final int sensorOrientation;
  final bool facingFront;

  /// Exposure-compensation range in EV stops (0/0 if unsupported).
  final double evMin;
  final double evMax;
  final double evStep;

  /// Whether tap-to-focus metering regions are supported.
  final bool focusSupported;

  const CameraInfo({
    required this.textureId,
    required this.previewWidth,
    required this.previewHeight,
    required this.sensorOrientation,
    required this.facingFront,
    this.evMin = 0,
    this.evMax = 0,
    this.evStep = 0,
    this.focusSupported = false,
  });

  bool get evSupported => evMax > evMin;
}

/// Live encoding statistics streamed from the native encoder.
class EncoderStats {
  final int frames;
  final int keyframes;
  final int bytes;
  final double fps;

  const EncoderStats({
    this.frames = 0,
    this.keyframes = 0,
    this.bytes = 0,
    this.fps = 0,
  });
}

/// Result of a finished encoding run.
class EncoderResult {
  final String? path;
  final int frames;
  final int keyframes;
  final int bytes;

  const EncoderResult({
    this.path,
    this.frames = 0,
    this.keyframes = 0,
    this.bytes = 0,
  });
}

/// Dart-side facade over the native Camera2 + MediaCodec encoding pipeline.
///
/// Commands go out over a [MethodChannel]; camera-ready notices, live stats,
/// completion, and errors arrive over an [EventChannel].
class EncoderService {
  static const _method = MethodChannel('ebadge/encoder');
  static const _events = EventChannel('ebadge/encoder/events');

  StreamSubscription<dynamic>? _eventSub;

  // Callbacks — assigned by the page that owns the bench.
  void Function(CameraInfo info)? onCamera;
  void Function(EncoderStats stats)? onStats;
  void Function(String path, int width, int height)? onStarted;
  void Function(EncoderResult result)? onStopped;
  void Function(String message)? onError;
  void Function(String message)? onInfo;

  /// Begin listening for native events. Call once before [openCamera].
  void listen() {
    _eventSub ??= _events.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object e) => onError?.call('事件流错误: $e'),
    );
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final map = event.cast<dynamic, dynamic>();
    switch (map['event'] as String?) {
      case 'camera':
        onCamera?.call(CameraInfo(
          textureId: (map['textureId'] as num).toInt(),
          previewWidth: (map['previewWidth'] as num?)?.toInt() ?? 0,
          previewHeight: (map['previewHeight'] as num?)?.toInt() ?? 0,
          sensorOrientation: (map['sensorOrientation'] as num?)?.toInt() ?? 0,
          facingFront: map['facingFront'] as bool? ?? false,
          evMin: (map['evMin'] as num?)?.toDouble() ?? 0,
          evMax: (map['evMax'] as num?)?.toDouble() ?? 0,
          evStep: (map['evStep'] as num?)?.toDouble() ?? 0,
          focusSupported: map['focusSupported'] as bool? ?? false,
        ));
        break;
      case 'stats':
        onStats?.call(EncoderStats(
          frames: (map['frames'] as num?)?.toInt() ?? 0,
          keyframes: (map['keyframes'] as num?)?.toInt() ?? 0,
          bytes: (map['bytes'] as num?)?.toInt() ?? 0,
          fps: (map['fps'] as num?)?.toDouble() ?? 0,
        ));
        break;
      case 'started':
        onStarted?.call(
          map['path'] as String? ?? '',
          (map['width'] as num?)?.toInt() ?? 0,
          (map['height'] as num?)?.toInt() ?? 0,
        );
        break;
      case 'stopped':
        onStopped?.call(EncoderResult(
          path: map['path'] as String?,
          frames: (map['frames'] as num?)?.toInt() ?? 0,
          keyframes: (map['keyframes'] as num?)?.toInt() ?? 0,
          bytes: (map['bytes'] as num?)?.toInt() ?? 0,
        ));
        break;
      case 'error':
        onError?.call(map['message'] as String? ?? '未知错误');
        break;
      case 'info':
        onInfo?.call(map['message'] as String? ?? '');
        break;
    }
  }

  Future<void> openCamera(EncoderConfig config, {bool facingFront = false}) =>
      _method.invokeMethod('openCamera', {
        'facingFront': facingFront,
        ...config.toWire(),
      });

  Future<void> closeCamera() => _method.invokeMethod('closeCamera');

  /// Push updated parameters (crop/zoom/aspect/fps) to the live preview.
  Future<void> setConfig(EncoderConfig config) =>
      _method.invokeMethod('setConfig', config.toWire());

  Future<void> startEncoding(EncoderConfig config) =>
      _method.invokeMethod('startEncoding', config.toWire());

  Future<void> stopEncoding() => _method.invokeMethod('stopEncoding');

  /// Tap-to-focus at normalized [nx],[ny] (0..1) in the displayed preview.
  Future<void> focusAt(double nx, double ny) =>
      _method.invokeMethod('focusAt', {'x': nx, 'y': ny});

  /// Set exposure compensation in EV stops.
  Future<void> setEv(double ev) => _method.invokeMethod('setEv', {'ev': ev});

  /// Release the native camera and stop listening for events.
  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    try {
      await closeCamera();
    } catch (_) {}
  }
}
