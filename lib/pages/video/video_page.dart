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

const double _previewMaxHRatio = 0.42;
const double _minBox = 48;

double _clampd(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

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
  bool _lockAspect = true; // true = 1:1 cover, false = free stretch
  int _bgColor = 0xFF000000; // GIF transparent-background fill

  // Crop box, normalized (0..1) relative to the source/preview (uniform scale).
  Rect _cropN = const Rect.fromLTWH(0, 0, 1, 1);
  double _pvW = 0;
  double _pvH = 0;
  Rect? _dragStartBox;
  Offset? _dragStartPos;

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
    final state = ref.read(transferProgressProvider);
    if (state.status == TransferStatus.sending) {
      ref.read(transferProgressProvider.notifier).abort();
    }
    _rebuildSeq++;
    _converter.cancel();
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
      _pvW = 0;
      _pvH = 0;
      _cropN = _initCrop(_lockAspect);
    });
    ref.read(transferProgressProvider.notifier).reset();
  }

  // Initial normalized crop: lock → centered max square; free → full frame.
  Rect _initCrop(bool lock) {
    if (!lock || _srcW <= 0 || _srcH <= 0) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    final double ar = _srcW / _srcH;
    double nw, nh;
    if (ar >= 1) {
      nw = 1 / ar;
      nh = 1;
    } else {
      nw = 1;
      nh = ar;
    }
    return Rect.fromLTWH((1 - nw) / 2, (1 - nh) / 2, nw, nh);
  }

  // ── Convert ────────────────────────────────────────────────────────────────
  CropN? _cropForConvert() {
    if (_thumb == null || _pvW <= 0 || _pvH <= 0) return null;
    return (
      nx: _cropN.left,
      ny: _cropN.top,
      nw: _cropN.width,
      nh: _cropN.height,
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
        cropMode: _lockAspect ? 'cover' : 'stretch',
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

  void _onToggleLock() {
    if (_isBusy) return;
    final bool lock = !_lockAspect;
    setState(() {
      _lockAspect = lock;
      if (lock && _pvW > 0 && _pvH > 0) {
        final double wpx = _cropN.width * _pvW;
        final double hpx = _cropN.height * _pvH;
        if ((wpx - hpx).abs() > 0.5) {
          final double side = min(wpx, hpx);
          _cropN = Rect.fromLTWH(
            _cropN.left,
            _cropN.top,
            side / _pvW,
            side / _pvH,
          );
        }
      }
    });
    _invalidate();
  }

  void _onResetCrop() {
    if (_isBusy) return;
    setState(() => _cropN = _initCrop(_lockAspect));
    _invalidate();
  }

  // ── Crop-box drag (move / resize) ─────────────────────────────────────────
  Rect _boxPx() => Rect.fromLTWH(
        _cropN.left * _pvW,
        _cropN.top * _pvH,
        _cropN.width * _pvW,
        _cropN.height * _pvH,
      );

  void _setBoxPx(Rect b) {
    if (_pvW <= 0 || _pvH <= 0) return;
    setState(() {
      _cropN = Rect.fromLTWH(
        b.left / _pvW,
        b.top / _pvH,
        b.width / _pvW,
        b.height / _pvH,
      );
    });
  }

  void _onMoveStart(DragStartDetails d) {
    if (_isBusy || _pvW <= 0) return;
    _invalidate();
    _dragStartBox = _boxPx();
    _dragStartPos = d.globalPosition;
  }

  void _onMoveUpdate(DragUpdateDetails d) {
    final s = _dragStartBox;
    final p = _dragStartPos;
    if (s == null || p == null) return;
    final double dx = d.globalPosition.dx - p.dx;
    final double dy = d.globalPosition.dy - p.dy;
    final double x = _clampd(s.left + dx, 0, _pvW - s.width);
    final double y = _clampd(s.top + dy, 0, _pvH - s.height);
    _setBoxPx(
        Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), s.width, s.height));
  }

  void _onResizeStart(DragStartDetails d) {
    if (_isBusy || _pvW <= 0) return;
    _invalidate();
    _dragStartBox = _boxPx();
    _dragStartPos = d.globalPosition;
  }

  void _onResizeUpdate(DragUpdateDetails d, String corner) {
    final s = _dragStartBox;
    final p = _dragStartPos;
    if (s == null || p == null) return;
    final double dx = d.globalPosition.dx - p.dx;
    final double dy = d.globalPosition.dy - p.dy;
    _setBoxPx(_resizeBox(s, corner, dx, dy));
  }

  // From a dragged corner → new box: opposite corner fixed, dragged corner
  // follows finger; lockAspect keeps it square. Ported from video.js.
  Rect _resizeBox(Rect s, String corner, double dx, double dy) {
    final double pw = _pvW, ph = _pvH;
    final bool movingLeft = corner == 'tl' || corner == 'bl';
    final bool movingTop = corner == 'tl' || corner == 'tr';
    final double anchorX = movingLeft ? s.left + s.width : s.left;
    final double anchorY = movingTop ? s.top + s.height : s.top;
    final double px =
        _clampd((movingLeft ? s.left : s.left + s.width) + dx, 0, pw);
    final double py =
        _clampd((movingTop ? s.top : s.top + s.height) + dy, 0, ph);
    double w = (px - anchorX).abs();
    double h = (py - anchorY).abs();
    final double maxW = movingLeft ? anchorX : (pw - anchorX);
    final double maxH = movingTop ? anchorY : (ph - anchorY);

    if (_lockAspect) {
      double side = min(w, h);
      final double hi = min(maxW, maxH);
      side = side < _minBox ? _minBox : (side > hi ? hi : side);
      w = h = side;
    } else {
      w = w < _minBox ? _minBox : (w > maxW ? maxW : w);
      h = h < _minBox ? _minBox : (h > maxH ? maxH : h);
    }
    return Rect.fromLTWH(
      (movingLeft ? anchorX - w : anchorX).roundToDouble(),
      (movingTop ? anchorY - h : anchorY).roundToDouble(),
      w.roundToDouble(),
      h.roundToDouble(),
    );
  }

  void _onDragEnd() {
    _dragStartBox = null;
    _dragStartPos = null;
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_srcPath == null)
              _buildPickHint(theme, cs)
            else ...[
              if (_thumb != null) ...[
                _buildPreview(theme, cs),
                const SizedBox(height: 8),
                _buildCropControls(theme, cs),
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
            const SizedBox(height: 20),
            if (sending)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  value: transferState.progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            _buildStatus(theme, cs, transferState),
            const SizedBox(height: 12),
            _buildAction(theme, cs, sending),
          ],
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

  Widget _buildPreview(ThemeData theme, ColorScheme cs) {
    final double maxH = (MediaQuery.of(context).size.height * _previewMaxHRatio)
        .clamp(180.0, 9999.0)
        .toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final double avail = constraints.maxWidth;
        final double ar = (_srcW > 0 && _srcH > 0) ? _srcW / _srcH : 1;
        double w = avail;
        double h = w / ar;
        if (h > maxH) {
          h = maxH;
          w = h * ar;
        }
        if (w > avail) {
          w = avail;
          h = w / ar;
        }
        _pvW = w;
        _pvH = h;
        final Rect box = _boxPx();

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                if (_isGif)
                  Positioned.fill(child: ColoredBox(color: Color(_bgColor))),
                Positioned.fill(
                  child: RawImage(image: _thumb, fit: BoxFit.fill),
                ),
                ..._buildDimBands(box, w, h),
                Positioned(
                  left: box.left,
                  top: box.top,
                  width: box.width,
                  height: box.height,
                  child: GestureDetector(
                    onPanStart: _onMoveStart,
                    onPanUpdate: _onMoveUpdate,
                    onPanEnd: (_) => _onDragEnd(),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                _buildHandle(box, 'tl', cs),
                _buildHandle(box, 'tr', cs),
                _buildHandle(box, 'bl', cs),
                _buildHandle(box, 'br', cs),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDimBands(Rect box, double w, double h) {
    const Color dim = Color(0x66000000);
    Widget band(double l, double t, double bw, double bh) => Positioned(
          left: l,
          top: t,
          width: bw < 0 ? 0 : bw,
          height: bh < 0 ? 0 : bh,
          child: IgnorePointer(child: Container(color: dim)),
        );
    return [
      band(0, 0, w, box.top),
      band(0, box.bottom, w, h - box.bottom),
      band(0, box.top, box.left, box.height),
      band(box.right, box.top, w - box.right, box.height),
    ];
  }

  Widget _buildHandle(Rect box, String corner, ColorScheme cs) {
    const double sz = 22;
    final bool left = corner == 'tl' || corner == 'bl';
    final bool top = corner == 'tl' || corner == 'tr';
    final double cx = left ? box.left : box.right;
    final double cy = top ? box.top : box.bottom;
    return Positioned(
      left: cx - sz / 2,
      top: cy - sz / 2,
      width: sz,
      height: sz,
      child: GestureDetector(
        onPanStart: _onResizeStart,
        onPanUpdate: (d) => _onResizeUpdate(d, corner),
        onPanEnd: (_) => _onDragEnd(),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropControls(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isBusy ? null : _onToggleLock,
            icon: Icon(_lockAspect ? Icons.lock_outline : Icons.crop_free),
            label: Text(_lockAspect ? '1:1 裁剪' : '自由拉伸'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isBusy ? null : _onResetCrop,
            icon: const Icon(Icons.refresh),
            label: const Text('重置裁剪'),
          ),
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
