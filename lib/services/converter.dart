import 'package:flutter/services.dart';

/// Normalized crop rectangle (0..1) relative to the source frame. Mirrors the
/// miniprogram's interactive crop box; takes precedence over [cropMode].
typedef CropN = ({double nx, double ny, double nw, double nh});

/// A decoded first-frame thumbnail used as the crop-preview base. For GIFs the
/// PNG keeps its alpha channel so the UI can composite it over the chosen
/// background color; [isGif] tells the page to offer the background picker.
class VideoThumbnail {
  final Uint8List bytes; // PNG-encoded (alpha preserved for GIF)
  final int width;
  final int height;
  final bool isGif;

  const VideoThumbnail({
    required this.bytes,
    required this.width,
    required this.height,
    this.isGif = false,
  });
}

/// Result of a finished video→AVI(CVID) conversion.
class VideoConvertResult {
  final Uint8List avi;
  final int width;
  final int height;
  final int frameCount;
  final double fps;

  const VideoConvertResult({
    required this.avi,
    required this.width,
    required this.height,
    required this.frameCount,
    required this.fps,
  });
}

/// Dart-side facade over the native video→AVI(CVID) pipeline
/// ([VideoConverter] + [CinepakEncoder] + [CvidAviMuxer] in Kotlin).
///
/// Commands go out over a [MethodChannel]; conversion progress arrives back
/// over the same channel as `onProgress` method calls (routed to the callback
/// passed into [convertVideo]).
class ConverterService {
  static const _method = MethodChannel('ebadge/converter');

  void Function(int done, int total)? _activeProgress;
  bool _handlerSet = false;

  void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _method.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        final args = (call.arguments as Map?)?.cast<dynamic, dynamic>();
        final done = (args?['done'] as num?)?.toInt() ?? 0;
        final total = (args?['total'] as num?)?.toInt() ?? 0;
        _activeProgress?.call(done, total);
      }
      return null;
    });
  }

  /// Decode the first frame of [path] for use as the crop-preview base image.
  Future<VideoThumbnail> getVideoThumbnail(String path) async {
    _ensureHandler();
    final res = await _method.invokeMethod('getVideoThumbnail', {'path': path});
    final map = (res as Map).cast<dynamic, dynamic>();
    return VideoThumbnail(
      bytes: map['bytes'] as Uint8List,
      width: (map['width'] as num).toInt(),
      height: (map['height'] as num).toInt(),
      isGif: map['isGif'] as bool? ?? false,
    );
  }

  /// Convert the video or GIF at [path] to a device-playable AVI(CVID). Frames
  /// are sampled at [fps] (capped at the source rate), cropped/resized to
  /// [width]×[height] (must be multiples of 4), Cinepak-encoded and muxed. The
  /// source type (video vs GIF) is auto-detected natively; [bgColor] (ARGB) is
  /// the opaque background composited under transparent GIF pixels (ignored for
  /// video). Defaults to black, matching the miniprogram.
  Future<VideoConvertResult> convertVideo({
    required String path,
    int width = 360,
    int height = 360,
    int fps = 10,
    int quality = 60,
    int refine = 3,
    int strips = 2,
    int skipThresh = 720,
    int keyint = 0,
    String cropMode = 'cover',
    CropN? crop,
    int maxFrames = 300,
    int bgColor = 0xFF000000,
    void Function(int done, int total)? onProgress,
  }) async {
    _ensureHandler();
    _activeProgress = onProgress;
    try {
      final res = await _method.invokeMethod('convertVideo', {
        'path': path,
        'width': width,
        'height': height,
        'fps': fps,
        'quality': quality,
        'refine': refine,
        'strips': strips,
        'skipThresh': skipThresh,
        'keyint': keyint,
        'cropMode': cropMode,
        'maxFrames': maxFrames,
        'bgColor': bgColor,
        if (crop != null)
          'crop': {
            'nx': crop.nx,
            'ny': crop.ny,
            'nw': crop.nw,
            'nh': crop.nh,
          },
      });
      final map = (res as Map).cast<dynamic, dynamic>();
      return VideoConvertResult(
        avi: map['avi'] as Uint8List,
        width: (map['width'] as num).toInt(),
        height: (map['height'] as num).toInt(),
        frameCount: (map['frameCount'] as num).toInt(),
        fps: (map['fps'] as num).toDouble(),
      );
    } finally {
      _activeProgress = null;
    }
  }

  /// Request cancellation of the in-flight conversion.
  Future<void> cancel() => _method.invokeMethod('cancelConvert');
}
