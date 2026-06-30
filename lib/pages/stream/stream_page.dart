import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/config_store.dart';
import '../../services/encoder.dart';
import 'widgets/encoder_settings_sheet.dart';

// iPhone-camera-style palette for the dark capture UI.
const Color _kAccent = Color(0xFFFFCC00); // iOS yellow
const Color _kRec = Color(0xFFFF3B30); // iOS red
const Color _kDone = Color(0xFF34C759); // iOS green

/// Encoding test bench.
///
/// Before wiring camera streaming to the BLE transport, this page validates the
/// native Camera2 → MediaCodec H.264 pipeline in isolation: pick parameters from
/// the bottom-sheet menu, start/stop encoding, and inspect the raw `.h264`
/// elementary stream written to the app's external files dir.
class StreamPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const StreamPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<StreamPage> createState() => _StreamPageState();
}

class _StreamPageState extends ConsumerState<StreamPage>
    with WidgetsBindingObserver {
  final EncoderService _encoder = EncoderService();

  EncoderConfig _config = const EncoderConfig();
  CameraInfo? _camera;
  EncoderStats _stats = const EncoderStats();
  EncoderResult? _result;

  bool _encoding = false;
  bool _permissionDenied = false;
  String? _error;
  bool _facingFront = false;

  /// Latest native diagnostic line (swap/crop/matrix). Hidden unless [_showDiag]
  /// is toggled on; shown as a non-intrusive overlay at the top of the preview.
  String? _diag;
  bool _showDiag = false;

  /// Exposure compensation (EV stops) and tap-to-focus reticle state.
  double _ev = 0;
  Offset? _focusPoint;
  bool _focusVisible = false; // focus reticle box
  bool _showEv = false; // EV indicator (with the box, or while scrubbing)
  Timer? _focusTimer;
  int _focusSeq = 0; // bumped each tap to restart the shrink animation
  double _evDragStartEv = 0;
  double _evDragStartY = 0;

  /// Actual (camera-supported) size the native layer encoded at, reported on
  /// `started`. May differ from the requested resolution after snapping.
  int _actualW = 0;
  int _actualH = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _encoder
      ..onCamera = (info) {
        if (!mounted) return;
        setState(() {
          _camera = info;
          _facingFront = info.facingFront;
          _error = null;
          _ev = _ev.clamp(info.evMin, info.evMax);
        });
      }
      ..onStats = (stats) {
        if (mounted) setState(() => _stats = stats);
      }
      ..onStarted = (path, w, h) {
        if (!mounted) return;
        setState(() {
          _encoding = true;
          _result = null;
          _stats = const EncoderStats();
          _actualW = w;
          _actualH = h;
        });
      }
      ..onStopped = (result) {
        if (!mounted) return;
        setState(() {
          _encoding = false;
          _result = result;
        });
      }
      ..onError = (message) {
        if (!mounted) return;
        setState(() {
          _error = message;
          _encoding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      ..onInfo = (message) {
        if (!mounted || message.isEmpty) return;
        // Stash diagnostics silently; only rendered when the toggle is on.
        setState(() => _diag = message);
      };

    _encoder.listen();
    _bootstrapCamera();
  }

  Future<void> _bootstrapCamera() async {
    // Restore the last-used encoding parameters.
    final saved = await EncoderConfigStore.load();
    if (mounted) setState(() => _config = saved);

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    if (mounted) setState(() => _permissionDenied = false);
    await _encoder.openCamera(_config, facingFront: _facingFront);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_permissionDenied && _camera == null) {
        _encoder.openCamera(_config, facingFront: _facingFront);
      }
    } else {
      // Releasing in the background also stops any in-flight encode natively.
      if (_encoding) _encoder.stopEncoding();
      _encoder.closeCamera();
      if (mounted) {
        setState(() {
          _camera = null;
          _encoding = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _encoder.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final updated = await EncoderSettingsSheet.show(context, _config);
    if (updated != null && mounted) {
      setState(() => _config = updated);
      // Push to the live preview and persist for next time.
      _encoder.setConfig(updated);
      EncoderConfigStore.save(updated);
    }
  }

  void _toggleEncoding() {
    if (_encoding) {
      _encoder.stopEncoding();
    } else {
      setState(() {
        _result = null;
        _error = null;
      });
      _encoder.startEncoding(_config);
    }
  }

  Future<void> _flipCamera() async {
    if (_encoding) return;
    setState(() {
      _facingFront = !_facingFront;
      _camera = null;
      _ev = 0; // native resets exposure compensation on reopen
      _focusVisible = false;
    });
    await _encoder.openCamera(_config, facingFront: _facingFront);
  }

  /// A complete tap focuses (and meters) at [pos] within a [w]×[h] preview.
  void _setFocus(Offset pos, double w, double h) {
    final nx = (pos.dx / w).clamp(0.0, 1.0);
    final ny = (pos.dy / h).clamp(0.0, 1.0);
    _encoder.focusAt(nx, ny);
    _focusTimer?.cancel();
    setState(() {
      _focusPoint = pos;
      _focusVisible = true;
      _showEv = _camera?.evSupported ?? false;
      _focusSeq++;
    });
    _scheduleHide();
  }

  void _scheduleHide() {
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _focusVisible = false;
          _showEv = false;
        });
      }
    });
  }

  /// A drag is always an EV scrub — it never focuses. Anchors the EV indicator
  /// where the scrub starts (or keeps it beside a still-visible focus box).
  void _onEvDragStart(Offset pos) {
    if (!(_camera?.evSupported ?? false)) return;
    _evDragStartEv = _ev;
    _evDragStartY = pos.dy;
    _focusTimer?.cancel();
    setState(() {
      if (!_focusVisible) _focusPoint = pos;
      _showEv = true;
    });
  }

  /// Vertical scrub adjusts EV proportionally to the drag distance.
  void _onEvDrag(double dy, double previewHeight) {
    final info = _camera;
    if (info == null || !info.evSupported) return;
    final range = info.evMax - info.evMin;
    final delta = _evDragStartY - dy; // up = brighter
    final ev = (_evDragStartEv + (delta / previewHeight) * range)
        .clamp(info.evMin, info.evMax);
    _focusTimer?.cancel(); // keep the overlay up while scrubbing
    setState(() => _ev = ev);
    _encoder.setEv(ev);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview()),
                  // Diagnostic overlay — top of the preview, never overlaps the
                  // bottom controls and doesn't shift the preview layout.
                  if (_showDiag && _diag != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          _diag!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            iconSize: 20,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: Center(child: _buildTopStatus())),
          IconButton(
            icon: Icon(
              Icons.bug_report_outlined,
              color: _showDiag ? _kAccent : Colors.white54,
            ),
            iconSize: 20,
            tooltip: '诊断信息',
            onPressed: () => setState(() => _showDiag = !_showDiag),
          ),
        ],
      ),
    );
  }

  /// Recording pill while encoding; otherwise a tappable config summary.
  Widget _buildTopStatus() {
    if (_encoding) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _kRec.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _kRec,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _actualW > 0 ? '$_actualW×$_actualH' : '编码中',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final c = _config;
    final summary = '${c.format.label} · ${c.width}×${c.height} · ${c.fps}fps';
    return GestureDetector(
      onTap: _openSettings,
      child: Text(
        summary,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  // ── Preview ─────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    if (_permissionDenied) {
      return _centerInfo(
        icon: Icons.no_photography_outlined,
        text: '相机权限被拒绝',
        action: TextButton.icon(
          onPressed: () => openAppSettings(),
          icon: const Icon(Icons.settings, color: _kAccent),
          label: const Text('前往设置', style: TextStyle(color: _kAccent)),
        ),
      );
    }

    final info = _camera;
    if (info == null || info.textureId < 0) {
      return _centerInfo(
        icon: Icons.videocam_outlined,
        text: '正在启动摄像头…',
        action: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }

    // The GL stage bakes rotation/crop/scale into the preview texture, so it is
    // already upright at the output aspect ratio — render it directly.
    final w = info.previewWidth.toDouble();
    final h = info.previewHeight.toDouble();
    final aspect = (w <= 0 || h <= 0) ? 1.0 : w / h;

    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final cw = constraints.maxWidth;
            final ch = constraints.maxHeight;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Only a complete tap focuses; a drag is always an EV scrub.
              onTapUp: info.focusSupported
                  ? (d) => _setFocus(d.localPosition, cw, ch)
                  : null,
              onVerticalDragStart: info.evSupported
                  ? (d) => _onEvDragStart(d.localPosition)
                  : null,
              onVerticalDragUpdate: info.evSupported
                  ? (d) => _onEvDrag(d.localPosition.dy, ch)
                  : null,
              onVerticalDragEnd:
                  info.evSupported ? (_) => _scheduleHide() : null,
              child: Stack(
                children: [
                  Positioned.fill(child: Texture(textureId: info.textureId)),
                  if ((_focusVisible || _showEv) && _focusPoint != null)
                    ..._buildFocusOverlay(info, cw),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The focus reticle (with shrink animation) plus, when EV is supported, a
  /// vertical EV indicator hugging the box's right (or left near the edge).
  List<Widget> _buildFocusOverlay(CameraInfo info, double cw) {
    const box = 70.0;
    final fp = _focusPoint!;
    final evOnLeft = fp.dx > cw - 120;
    final t = info.evSupported && info.evMax > info.evMin
        ? (_ev - info.evMin) / (info.evMax - info.evMin)
        : 0.5;

    return [
      // Animated shrinking reticle (only for a tap-triggered focus).
      if (_focusVisible)
        Positioned(
          left: fp.dx - box / 2,
          top: fp.dy - box / 2,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_focusSeq),
            tween: Tween(begin: 1.5, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const _FocusReticle(),
          ),
        ),
      // EV indicator: track the same height as the box, sun thumb by EV value.
      if (_showEv && info.evSupported)
        Positioned(
          left: evOnLeft ? fp.dx - box / 2 - 34 : fp.dx + box / 2 + 8,
          top: fp.dy - box / 2,
          child: IgnorePointer(
            child: SizedBox(
              width: 26,
              height: box,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(width: 2, color: Colors.white38),
                  Positioned(
                    top: (1 - t) * (box - 22),
                    child: const Icon(
                      Icons.wb_sunny,
                      color: _kAccent,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  Widget _centerInfo({
    required IconData icon,
    required String text,
    required Widget action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white38),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 20),
          action,
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusLine(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleButton(
                Icons.flip_camera_ios_outlined,
                onTap: _flipCamera,
                enabled: !_encoding,
              ),
              _buildShutter(),
              _circleButton(
                Icons.tune,
                onTap: _openSettings,
                enabled: !_encoding,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// iOS-style record button: white ring with a white circle that morphs into a
  /// red rounded square while encoding.
  Widget _buildShutter() {
    final ready = _camera != null;
    final ring = ready ? Colors.white : Colors.white38;
    return GestureDetector(
      onTap: ready ? _toggleEncoding : null,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _encoding ? 30 : 58,
            height: _encoding ? 30 : 58,
            decoration: BoxDecoration(
              color: _encoding ? _kRec : ring,
              borderRadius: BorderRadius.circular(_encoding ? 8 : 40),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(
    IconData icon, {
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Icon(
          icon,
          size: 24,
          color: enabled ? Colors.white : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildStatusLine() {
    if (_encoding) {
      return Text(
        '${_stats.fps.toStringAsFixed(1)} fps · ${_stats.frames} 帧 · '
        'I:${_stats.keyframes} · ${_formatBytes(_stats.bytes)}',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        textAlign: TextAlign.center,
      );
    }

    final r = _result;
    if (r != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '已保存 · ${r.frames} 帧 (I帧 ${r.keyframes}) · ${_formatBytes(r.bytes)}',
            style: const TextStyle(
              color: _kDone,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (r.path != null) ...[
            const SizedBox(height: 3),
            Text(
              r.path!,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    return Text(
      _error ?? '点击下方按钮开始编码，生成 .h264 测试文件',
      style: TextStyle(
        color: _error != null ? _kRec : Colors.white54,
        fontSize: 13,
      ),
      textAlign: TextAlign.center,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Yellow tap-to-focus reticle (iOS-style square) shown briefly at the tap.
class _FocusReticle extends StatelessWidget {
  const _FocusReticle();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          border: Border.all(color: _kAccent, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
