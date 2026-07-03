import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/transfer_provider.dart';
import '../../services/converter.dart';
import '../../services/raster.dart';
import '../../services/l2_file_transfer.dart';
import '../shared/file_send_layout.dart';

/// Page for converting a picked video **or GIF** to a device-playable
/// AVI(CVID) and sending it over BLE. Mirrors the miniprogram video flow:
/// pick (mp4/mov or GIF) → first-frame crop box (1:1 lock = cover / free =
/// stretch) → size 240/360/480 → fps 10/15/20/24 → quality LOW/MED/HIGH →
/// convert (native Cinepak) → send TYPE.video. For a transparent GIF the user
/// can pick the background color composited under transparent pixels.
class VideoPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const VideoPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

const List<int> _sizePresets = [240, 360, 480];
const List<int> _fpsPresets = [10, 15, 20, 24];
const List<(String, int)> _qualityPresets = [('LOW', 15), ('MED', 60), ('HIGH', 95)];

// Background colors for transparent GIFs (opaque ARGB). Black first (default,
// matches the miniprogram), then white and a few accents.
const List<int> _bgColors = [
  0xFF000000,
  0xFFFFFFFF,
  0xFFFF3B30,
  0xFF34C759,
  0xFF007AFF,
  0xFFFFCC00,
];

const double _previewMaxHRatio = 0.5; // square viewport max height = 50% screen

enum _ConvStatus { idle, converting, ready, error }

class _VideoPageState extends ConsumerState<VideoPage> {
  final _picker = ImagePicker();
  final _converter = ConverterService();

  String? _selectedName;
  String? _srcPath;
  bool _isGif = false;
  String _fileName = 'video.avi';
  int _sourceSize = 0;

  // First-frame preview base (source-frame pixel dims in _srcW/_srcH).
  ui.Image? _thumb;
  int _srcW = 0;
  int _srcH = 0;

  // Conversion options.
  int _size = 360;
  int _fps = 10;
  int _quality = 60;
  int _bgColor = 0xFF000000; // GIF transparent bg + viewport letterbox fill

  // Pinch-zoom viewport crop (mirrors the image page): the fixed square frame
  // maps to the full output — whatever is framed is what gets encoded. On load
  // the whole first frame fits (contain); pinch-zoom / pan reframes it.
  final TransformationController _tc = TransformationController();
  double _vp = 0; // square viewport side in px (set during layout)
  int _viewportPointers = 0; // >0 → freeze page scroll while framing

  // Conversion result / state.
  Uint8List? _avi;
  int _binSize = 0;
  int _frameCount = 0;
  double _convProgress = 0;
  _ConvStatus _conv = _ConvStatus.idle;
  String? _convError;
  int _rebuildSeq = 0;

  @override
  void dispose() {
    // Reset send status on leave so re-entering never shows a stale result.
    final notifier = ref.read(transferProgressProvider.notifier);
    if (ref.read(transferProgressProvider).status == TransferStatus.sending) {
      notifier.abort();
    } else {
      notifier.reset();
    }
    _rebuildSeq++;
    _converter.cancel();
    _tc.dispose();
    _thumb?.dispose();
    super.dispose();
  }

  bool get _sending =>
      ref.read(transferProgressProvider).status == TransferStatus.sending;

  bool get _isBusy => _conv == _ConvStatus.converting || _sending;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Pick source (video or GIF) ─────────────────────────────────────────────
  Future<void> _showPickSheet() async {
    if (_isBusy) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('视频 (mp4 / mov)'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.gif_box_outlined),
              title: const Text('GIF 动图'),
              onTap: () => Navigator.pop(ctx, 'gif'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'video') {
      await _pickVideo();
    } else if (choice == 'gif') {
      await _pickGif();
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      final len = await File(video.path).length();
      await _loadMedia(
          path: video.path, name: video.name, size: len, isGif: false);
    } catch (e) {
      _snack('选择视频失败: $e');
    }
  }

  Future<void> _pickGif() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gif'],
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final path = f.path;
      if (path == null) {
        _snack('无法读取文件路径');
        return;
      }
      // Verify the GIF magic — album pickers can hand back a static image.
      final raf = await File(path).open();
      Uint8List head;
      try {
        head = await raf.read(3);
      } finally {
        await raf.close();
      }
      final ok = head.length >= 3 &&
          head[0] == 0x47 &&
          head[1] == 0x49 &&
          head[2] == 0x46;
      if (!ok) {
        _snack('这不是 GIF 动图（可能已被转为静态图）');
        return;
      }
      await _loadMedia(path: path, name: f.name, size: f.size, isGif: true);
    } catch (e) {
      _snack('选择 GIF 失败: $e');
    }
  }

  // Shared: load the crop-preview thumbnail and reset all state for a new pick.
  Future<void> _loadMedia({
    required String path,
    required String name,
    required int size,
    required bool isGif,
  }) async {
    ui.Image? thumb;
    int tw = 0;
    int th = 0;
    try {
      final t = await _converter.getVideoThumbnail(path);
      thumb = await decodeUiImage(t.bytes);
      tw = t.width;
      th = t.height;
    } catch (_) {
      // No preview — conversion still works with cover cropping.
    }

    if (!mounted) {
      thumb?.dispose();
      return;
    }

    _thumb?.dispose();
    final base =
        name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;

    setState(() {
      _selectedName = name;
      _srcPath = path;
      _isGif = isGif;
      _sourceSize = size;
      _fileName = '$base.avi';
      _thumb = thumb;
      _srcW = tw;
      _srcH = th;
      _avi = null;
      _binSize = 0;
      _frameCount = 0;
      _convProgress = 0;
      _conv = _ConvStatus.idle;
      _convError = null;
      _tc.value = Matrix4.identity(); // reset zoom/pan to contain-fit
    });
    ref.read(transferProgressProvider.notifier).reset();
  }

  // ── Convert ────────────────────────────────────────────────────────────────
  // Normalized source rect (relative to the source frame) that the square
  // viewport currently frames, derived from the pinch-zoom transform. Inverts
  // the image page's `output = src*scale + t` mapping, so nx/ny may be negative
  // and nw/nh may exceed 1 (letterbox); the native side fills outside the frame
  // with the background. Returns null when there's no preview to frame.
  CropN? _cropForConvert() {
    if (_thumb == null || _vp <= 0 || _srcW <= 0 || _srcH <= 0) return null;
    final double v = _vp;
    final double s0 = min(v / _srcW, v / _srcH); // contain scale in v×v box
    final double lx = (v - _srcW * s0) / 2;
    final double ly = (v - _srcH * s0) / 2;
    final m = _tc.value;
    final double k = m.getMaxScaleOnAxis();
    final double denom = k * s0;
    if (denom <= 0) return null;
    final double mtx = m.storage[12];
    final double mty = m.storage[13];
    return (
      nx: -(k * lx + mtx) / (denom * _srcW),
      ny: -(k * ly + mty) / (denom * _srcH),
      nw: v / (denom * _srcW),
      nh: v / (denom * _srcH),
    );
  }

  Future<void> _convert() async {
    final path = _srcPath;
    if (path == null || _isBusy) return;
    final int token = ++_rebuildSeq;
    setState(() {
      _conv = _ConvStatus.converting;
      _convProgress = 0;
      _binSize = 0;
      _frameCount = 0;
      _convError = null;
      _avi = null;
    });
    try {
      final res = await _converter.convertVideo(
        path: path,
        width: _size,
        height: _size,
        fps: _fps,
        quality: _quality,
        cropMode: 'cover', // only used as the no-preview fallback
        crop: _cropForConvert(),
        bgColor: _bgColor,
        onProgress: (done, total) {
          if (token != _rebuildSeq || !mounted) return;
          setState(() {
            _convProgress = total > 0 ? (done / total).clamp(0.0, 0.99) : 0;
            _frameCount = done;
          });
        },
      );
      if (token != _rebuildSeq || !mounted) return;
      setState(() {
        _avi = res.avi;
        _binSize = res.avi.length;
        _frameCount = res.frameCount;
        _convProgress = 1;
        _conv = _ConvStatus.ready;
      });
    } on PlatformException catch (e) {
      if (token != _rebuildSeq || !mounted) return;
      if (e.code == 'cancelled') {
        setState(() => _conv = _ConvStatus.idle);
        return;
      }
      setState(() {
        _conv = _ConvStatus.error;
        _convError = e.message ?? '转换失败';
      });
    } catch (e) {
      if (token != _rebuildSeq || !mounted) return;
      setState(() {
        _conv = _ConvStatus.error;
        _convError = '$e';
      });
    }
  }

  void _cancelConvert() {
    _rebuildSeq++;
    _converter.cancel();
    setState(() {
      _conv = _ConvStatus.idle;
      _convProgress = 0;
    });
  }

  // Any option/crop change drops the converted result back to "needs convert".
  void _invalidate() {
    if (_avi == null && _conv == _ConvStatus.idle && _convError == null) return;
    _rebuildSeq++;
    setState(() {
      _avi = null;
      _binSize = 0;
      _frameCount = 0;
      _convProgress = 0;
      _convError = null;
      _conv = _ConvStatus.idle;
    });
  }

  void _onSizeTap(int s) {
    if (_isBusy || s == _size) return;
    setState(() => _size = s);
    _invalidate();
  }

  void _onFpsTap(int f) {
    if (_isBusy || f == _fps) return;
    setState(() => _fps = f);
    _invalidate();
  }

  void _onQualityTap(int q) {
    if (_isBusy || q == _quality) return;
    setState(() => _quality = q);
    _invalidate();
  }

  void _onBgTap(int c) {
    if (_isBusy || c == _bgColor) return;
    setState(() => _bgColor = c);
    _invalidate();
  }

  void _onResetView() {
    if (_isBusy) return;
    _tc.value = Matrix4.identity();
    _invalidate();
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  void _send() {
    final avi = _avi;
    if (avi == null || _conv != _ConvStatus.ready || _sending) return;
    ref.read(transferProgressProvider.notifier).send(TYPE.video, avi, _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferProgressProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sending = transferState.status == TransferStatus.sending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('发送视频'),
        actions: [
          if (_srcPath != null)
            IconButton(
              onPressed: _isBusy ? null : _showPickSheet,
              icon: const Icon(Icons.folder_open),
              tooltip: '重新选择',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Freeze page scroll while the user is framing inside the preview
              // (pinch-zoom / pan) so the gesture never leaks into scrolling.
              physics: _viewportPointers > 0
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_srcPath == null)
                    _buildPickHint(theme, cs)
                  else ...[
                    if (_thumb != null) ...[
                      _buildPreview(theme, cs),
                      const SizedBox(height: 8),
                      _buildViewControls(theme, cs),
                    ] else
                      _buildNoPreview(theme, cs),
                    const SizedBox(height: 16),
                    _buildChipRow(theme, '尺寸', _sizePresets,
                        (s) => s == _size, (s) => _onSizeTap(s), (s) => '$s'),
                    const SizedBox(height: 8),
                    _buildChipRow(theme, '帧率', _fpsPresets, (f) => f == _fps,
                        (f) => _onFpsTap(f), (f) => '$f'),
                    const SizedBox(height: 8),
                    _buildQualityRow(theme),
                    if (_isGif) ...[
                      const SizedBox(height: 8),
                      _buildBgColorRow(theme, cs),
                    ],
                    const SizedBox(height: 12),
                    _buildConvInfo(theme, cs),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomBar(theme, cs, transferState, sending),
        ],
      ),
    );
  }

  // Pinned bottom bar: transfer progress + status + action, always visible
  // (does not scroll with the page content).
  Widget _buildBottomBar(
      ThemeData theme, ColorScheme cs, TransferState state, bool sending) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border:
            Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              _buildStatus(theme, cs, state),
              const SizedBox(height: 12),
              _buildAction(theme, cs, sending),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickHint(ThemeData theme, ColorScheme cs) {
    return GestureDetector(
      onTap: _showPickSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_creation_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('点击选择视频或 GIF',
                style: theme.textTheme.bodyLarge?.copyWith(color: cs.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPreview(ThemeData theme, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.movie_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(_selectedName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('无法读取首帧，将按封面居中裁剪',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // Fixed square viewport: the first frame is pinch-zoomed / panned underneath
  // a fixed frame (contain-fit on load). Whatever the square frames is what gets
  // encoded; areas outside the frame become the background (letterbox).
  Widget _buildPreview(ThemeData theme, ColorScheme cs) {
    final double maxH = MediaQuery.of(context).size.height * _previewMaxHRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double v = min(constraints.maxWidth, maxH);
        _vp = v;
        return Center(
          child: Listener(
            // Track fingers on the viewport so page scroll can be frozen while
            // the frame is being pinch-zoomed / panned (see SingleChildScrollView).
            onPointerDown: (_) => setState(() => _viewportPointers++),
            onPointerUp: (_) => setState(
                () => _viewportPointers = (_viewportPointers - 1).clamp(0, 99)),
            onPointerCancel: (_) => setState(
                () => _viewportPointers = (_viewportPointers - 1).clamp(0, 99)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: v,
                height: v,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: Color(_bgColor))),
                    InteractiveViewer(
                      transformationController: _tc,
                      minScale: 1.0,
                      maxScale: 8.0,
                      clipBehavior: Clip.hardEdge,
                      // Reframing invalidates the converted result (re-convert
                      // is expensive/native, so it's manual — not automatic).
                      onInteractionEnd: (_) => _invalidate(),
                      child: SizedBox(
                        width: v,
                        height: v,
                        child: RawImage(image: _thumb, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewControls(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Icon(Icons.pinch_outlined, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text('双指缩放 / 拖动取景，框内即画面区域',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ),
        TextButton.icon(
          onPressed: _isBusy ? null : _onResetView,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重置'),
        ),
      ],
    );
  }

  Widget _buildChipRow(
    ThemeData theme,
    String label,
    List<int> presets,
    bool Function(int) selected,
    void Function(int) onTap,
    String Function(int) fmt,
  ) {
    return Row(
      children: [
        SizedBox(
            width: 40, child: Text(label, style: theme.textTheme.titleSmall)),
        const SizedBox(width: 8),
        ...presets.map((v) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(fmt(v)),
                selected: selected(v),
                onSelected: _isBusy ? null : (_) => onTap(v),
              ),
            )),
      ],
    );
  }

  Widget _buildQualityRow(ThemeData theme) {
    return Row(
      children: [
        SizedBox(
            width: 40, child: Text('质量', style: theme.textTheme.titleSmall)),
        const SizedBox(width: 8),
        ..._qualityPresets.map((q) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(q.$1),
                selected: _quality == q.$2,
                onSelected: _isBusy ? null : (_) => _onQualityTap(q.$2),
              ),
            )),
      ],
    );
  }

  Widget _buildBgColorRow(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        SizedBox(
            width: 40, child: Text('背景', style: theme.textTheme.titleSmall)),
        const SizedBox(width: 8),
        ..._bgColors.map((c) {
          final bool sel = _bgColor == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _isBusy ? null : () => _onBgTap(c),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? cs.primary : cs.outlineVariant,
                    width: sel ? 3 : 1,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConvInfo(ThemeData theme, ColorScheme cs) {
    String right;
    if (_conv == _ConvStatus.converting) {
      final pct = (_convProgress * 100).toInt();
      right = '转换中 $pct% · $_frameCount 帧';
    } else if (_conv == _ConvStatus.ready) {
      right = '$_size×$_size · $_frameCount 帧 · ${formatFileSize(_binSize)}';
    } else {
      right = '待转换';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('源文件 ${formatFileSize(_sourceSize)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        Flexible(
          child: Text(right,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStatus(ThemeData theme, ColorScheme cs, TransferState state) {
    if (_conv == _ConvStatus.error) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 20, color: cs.error),
          const SizedBox(width: 6),
          Flexible(
            child: Text(_convError ?? '转换失败',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.error, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }
    switch (state.status) {
      case TransferStatus.idle:
        return const SizedBox.shrink();
      case TransferStatus.sending:
        final pct = (state.progress * 100).toInt();
        return Text('$pct% · ${state.speedKBs} KB/s',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.primary));
      case TransferStatus.done:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 20, color: cs.secondary),
            const SizedBox(width: 6),
            Text('发送成功',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.secondary, fontWeight: FontWeight.w600)),
          ],
        );
      case TransferStatus.error:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 20, color: cs.error),
            const SizedBox(width: 6),
            Flexible(
              child: Text(state.errorMessage ?? '发送失败',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.error, fontWeight: FontWeight.w600)),
            ),
          ],
        );
    }
  }

  Widget _buildAction(ThemeData theme, ColorScheme cs, bool sending) {
    if (sending) {
      return FilledButton.icon(
        onPressed: () => ref.read(transferProgressProvider.notifier).abort(),
        icon: const Icon(Icons.close),
        label: const Text('取消'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
          minimumSize: const Size.fromHeight(48),
        ),
      );
    }
    if (_conv == _ConvStatus.converting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              value: _convProgress > 0 ? _convProgress : null,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _cancelConvert,
            icon: const Icon(Icons.close),
            label: const Text('取消转换'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      );
    }
    if (_conv == _ConvStatus.ready) {
      return FilledButton.icon(
        onPressed: _send,
        icon: const Icon(Icons.send),
        label: const Text('发送到设备'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      );
    }
    // idle or error → convert.
    return FilledButton.icon(
      onPressed: _srcPath != null ? _convert : null,
      icon: const Icon(Icons.transform),
      label: const Text('转换为视频'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}
