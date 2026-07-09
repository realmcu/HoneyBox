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

/// A short set of downscaled PNG frames plus the real-time interval between
/// them, used to play back a moving preview of a clip inside the framing
/// viewport before conversion. Frames keep the source aspect ratio (GIF frames
/// keep their alpha) so the preview matches the still thumbnail.
class VideoPreview {
  final List<Uint8List> frames; // PNG-encoded, in playback order
  final int intervalMs; // real-time gap between consecutive frames

  const VideoPreview({required this.frames, required this.intervalMs});
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

  /// Extract a short set of downscaled preview frames from [path] (video or
  /// GIF, auto-detected) so the page can play back the clip's motion inside the
  /// framing viewport. At most [maxCount] frames, each downscaled so its longest
  /// edge is ≤ [maxEdge]px to keep memory bounded once decoded.
  Future<VideoPreview> getVideoFrames(
    String path, {
    int maxCount = 48,
    int maxEdge = 240,
  }) async {
    _ensureHandler();
    final res = await _method.invokeMethod('previewFrames', {
      'path': path,
      'maxCount': maxCount,
      'maxEdge': maxEdge,
    });
    final map = (res as Map).cast<dynamic, dynamic>();
    final raw = (map['frames'] as List).cast<Object?>();
    final frames = <Uint8List>[
      for (final f in raw) f as Uint8List,
    ];
    return VideoPreview(
      frames: frames,
      intervalMs: (map['intervalMs'] as num?)?.toInt() ?? 100,
    );
  }

  /// Render a pre-drawn danmaku [strip] (raw RGBA, [stripW]×[stripH]) as a
  /// seamless looping AVI(CVID) that scrolls the strip right→left across a
  /// [size]×[size] canvas — used for the danmaku "scroll" mode, since the
  /// firmware has no native scrolling-text primitive. [speed] is px/sec, [gap]
  /// is the blank space between strip repeats (defaults to [size], i.e. a full
  /// screen apart). [bgColor] (ARGB) fills the background.
  Future<VideoConvertResult> encodeScrollVideo({
    required Uint8List strip,
    required int stripW,
    required int stripH,
    int size = 360,
    int bgColor = 0xFF000000,
    int speed = 120,
    int fps = 15,
    int? gap,
    int quality = 80,
    int maxFrames = 300,
    void Function(int done, int total)? onProgress,
  }) async {
    _ensureHandler();
    _activeProgress = onProgress;
    try {
      final res = await _method.invokeMethod('encodeScroll', {
        'strip': strip,
        'stripW': stripW,
        'stripH': stripH,
        'size': size,
        'bgColor': bgColor,
        'speed': speed,
        'fps': fps,
        'gap': gap ?? size,
        'quality': quality,
        'maxFrames': maxFrames,
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
