import 'package:flutter/services.dart';

/// Dart facade over the native [MediaPlayer]-backed preview player
/// (`VideoPreviewPlayer` in Kotlin).
///
/// Renders the *original* video into a Flutter external texture so the video
/// page can play it inside the circular pinch-zoom framing viewport — no frame
/// extraction, no third-party plugin. One instance drives one texture: call
/// [open] (completes once the first frame is renderable), then
/// [play]/[pause]/[seekTo]; [dispose] releases the native player + texture.
///
/// The framing/crop math is unaffected: it derives from the transform + source
/// dimensions, not from these pixels, so a video texture frames exactly like
/// the still thumbnail. Playback loops and is muted (a motion preview).
class NativeVideoPlayer {
  static const _channel = MethodChannel('ebadge/player');

  int? _textureId;
  int videoWidth = 0;
  int videoHeight = 0;
  int durationMs = 0;

  bool get isReady => _textureId != null;
  int get textureId => _textureId ?? -1;

  /// Open [path] and prepare playback. Completes once the first frame is ready;
  /// throws [PlatformException] on failure.
  Future<void> open(String path) async {
    final res = await _channel.invokeMethod('create', {'path': path});
    final map = (res as Map).cast<dynamic, dynamic>();
    _textureId = (map['textureId'] as num).toInt();
    videoWidth = (map['width'] as num?)?.toInt() ?? 0;
    videoHeight = (map['height'] as num?)?.toInt() ?? 0;
    durationMs = (map['durationMs'] as num?)?.toInt() ?? 0;
  }

  Future<void> play() async {
    final id = _textureId;
    if (id == null) return;
    await _channel.invokeMethod('play', {'id': id});
  }

  Future<void> pause() async {
    final id = _textureId;
    if (id == null) return;
    await _channel.invokeMethod('pause', {'id': id});
  }

  Future<void> seekTo(int ms) async {
    final id = _textureId;
    if (id == null) return;
    await _channel.invokeMethod('seekTo', {'id': id, 'positionMs': ms});
  }

  /// Current playback position in ms (0 when not ready). Poll while playing to
  /// drive a progress / time readout.
  Future<int> position() async {
    final id = _textureId;
    if (id == null) return 0;
    final res = await _channel.invokeMethod('position', {'id': id});
    return (res as num?)?.toInt() ?? 0;
  }

  /// Release the native player + texture. Safe to call multiple times.
  Future<void> dispose() async {
    final id = _textureId;
    _textureId = null;
    if (id == null) return;
    await _channel.invokeMethod('dispose', {'id': id});
  }
}
