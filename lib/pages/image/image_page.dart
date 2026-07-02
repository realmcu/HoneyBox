import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/transfer_provider.dart';
import '../../services/image_bin.dart';
import '../../services/raster.dart';
import '../../services/l2_file_transfer.dart';
import '../shared/file_send_layout.dart';

/// Page for converting a picked image to a device RGB565 `.bin` and sending it
/// over BLE. Mirrors the miniprogram image flow: pick → interactive crop box
/// (1:1 lock = cover / free = stretch) → size 240/360/480 → RLE + dither
/// toggles → convert (client-side) → send TYPE.image.
class ImagePage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const ImagePage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<ImagePage> createState() => _ImagePageState();
}

const List<int> _sizePresets = [240, 360, 480];
const double _previewMaxHRatio = 0.42; // preview max height = 42% of screen
const double _minBox = 48; // min crop-box edge in preview px

double _clampd(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

class _ImagePageState extends ConsumerState<ImagePage> {
  final _picker = ImagePicker();

  XFile? _selectedImage;
  ui.Image? _srcImage;
  int _srcW = 0;
  int _srcH = 0;
  String _fileName = 'image.bin';
  int _sourceSize = 0;

  // Conversion options.
  int _size = kImageDefaultSize; // 360
  bool _compress = true;
  bool _dither = false;
  bool _lockAspect = true; // true = 1:1 cover, false = free stretch

  // Crop box, normalized (0..1) relative to the source/preview (uniform scale).
  Rect _cropN = const Rect.fromLTWH(0, 0, 1, 1);

  // Preview size in px (set during layout, used by drag math).
  double _pvW = 0;
  double _pvH = 0;

  // Drag session.
  Rect? _dragStartBox;
  Offset? _dragStartPos;

  // Conversion result.
  Uint8List? _bin;
  int _binSize = 0;
  bool _converting = false;
  int _rebuildSeq = 0;

  @override
  void dispose() {
    final state = ref.read(transferProgressProvider);
    if (state.status == TransferStatus.sending) {
      ref.read(transferProgressProvider.notifier).abort();
    }
    _srcImage?.dispose();
    super.dispose();
  }

  bool get _isSending =>
      ref.read(transferProgressProvider).status == TransferStatus.sending;

  // ── Pick image ─────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_isSending) return;
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final name = image.name.toLowerCase();
      if (name.endsWith('.gif')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请使用 GIF 功能发送 GIF 文件')),
        );
        return;
      }

      final file = File(image.path);
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件过大，建议压缩后发送')),
        );
        return;
      }

      final decoded = await decodeUiImage(bytes);
      _srcImage?.dispose();

      final base = image.name.contains('.')
          ? image.name.substring(0, image.name.lastIndexOf('.'))
          : image.name;

      setState(() {
        _selectedImage = image;
        _srcImage = decoded;
        _srcW = decoded.width;
        _srcH = decoded.height;
        _sourceSize = bytes.length;
        _fileName = '$base.bin';
        _bin = null;
        _binSize = 0;
        _pvW = 0; // force preview + crop re-init on next layout
        _pvH = 0;
        _cropN = _initCrop(_lockAspect);
      });
      ref.read(transferProgressProvider.notifier).reset();
      _rebuild();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  // Initial normalized crop: lock → centered max square; free → full image.
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

  // ── Conversion ───────────────────────────────────────────────────────────
  CropRect? _cropRect() {
    if (_pvW <= 0 || _pvH <= 0) return null;
    return CropRect(_cropN.left, _cropN.top, _cropN.width, _cropN.height);
  }

  Future<void> _rebuild() async {
    final src = _srcImage;
    if (src == null) return;
    final int token = ++_rebuildSeq;
    setState(() {
      _converting = true;
      _bin = null;
      _binSize = 0;
    });
    try {
      final RgbaImage img = await cropResizeToRgba(
        src,
        targetW: _size,
        targetH: _size,
        crop: _cropRect(),
        cover: _lockAspect,
      );
      final Uint8List bin = buildImageBin(
        img.rgba,
        img.width,
        img.height,
        compress: _compress,
        dither: _dither,
      );
      if (token != _rebuildSeq || !mounted) return;
      setState(() {
        _bin = bin;
        _binSize = bin.length;
        _converting = false;
      });
    } catch (e) {
      if (token != _rebuildSeq || !mounted) return;
      setState(() => _converting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转换失败: $e')),
      );
    }
  }

  // ── Option changes ─────────────────────────────────────────────────────────
  void _onSizeTap(int size) {
    if (_isSending || size == _size) return;
    setState(() => _size = size);
    _rebuild();
  }

  void _onCompressChange(bool v) {
    if (_isSending) return;
    setState(() => _compress = v);
    _rebuild();
  }

  void _onDitherChange(bool v) {
    if (_isSending) return;
    setState(() => _dither = v);
    _rebuild();
  }

  void _onToggleLock() {
    if (_isSending) return;
    final bool lock = !_lockAspect;
    setState(() {
      _lockAspect = lock;
      // Shrink current box to a square (short side, anchored top-left) on lock.
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
    _rebuild();
  }

  void _onResetCrop() {
    if (_isSending) return;
    setState(() => _cropN = _initCrop(_lockAspect));
    _rebuild();
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
    if (_isSending || _pvW <= 0) return;
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
    if (_isSending || _pvW <= 0) return;
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
  // follows finger; lockAspect keeps it square. Ported from image.js.
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
    final start = _dragStartBox;
    _dragStartBox = null;
    _dragStartPos = null;
    if (start == null) return;
    final Rect now = _boxPx();
    if ((now.left - start.left).abs() > 0.5 ||
        (now.top - start.top).abs() > 0.5 ||
        (now.width - start.width).abs() > 0.5 ||
        (now.height - start.height).abs() > 0.5) {
      _rebuild();
    }
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  void _send() {
    final bin = _bin;
    if (bin == null || _converting || _isSending) return;
    ref.read(transferProgressProvider.notifier).send(TYPE.image, bin, _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferProgressProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sending = transferState.status == TransferStatus.sending;

    return Scaffold(
      appBar: AppBar(title: const Text('发送图片')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage == null)
              _buildPickHint(theme, cs)
            else ...[
              _buildPreview(theme, cs),
              const SizedBox(height: 8),
              _buildCropControls(theme, cs),
              const SizedBox(height: 16),
              _buildSizeSelector(theme, cs),
              const SizedBox(height: 8),
              _buildToggles(theme, cs),
              const SizedBox(height: 12),
              _buildBinInfo(theme, cs),
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
            _buildActionButton(cs, sending),
          ],
        ),
      ),
    );
  }

  Widget _buildPickHint(ThemeData theme, ColorScheme cs) {
    return GestureDetector(
      onTap: _pickImage,
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
            Icon(Icons.image_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('点击选择图片',
                style: theme.textTheme.bodyLarge?.copyWith(color: cs.outline)),
          ],
        ),
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
                Positioned.fill(
                  child: Image.file(File(_selectedImage!.path), fit: BoxFit.fill),
                ),
                // Dim overlay outside the crop box (four bands).
                ..._buildDimBands(box, w, h),
                // Crop box outline + move gesture.
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
      band(0, 0, w, box.top), // top
      band(0, box.bottom, w, h - box.bottom), // bottom
      band(0, box.top, box.left, box.height), // left
      band(box.right, box.top, w - box.right, box.height), // right
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
            onPressed: _isSending ? null : _onToggleLock,
            icon: Icon(_lockAspect ? Icons.lock_outline : Icons.crop_free),
            label: Text(_lockAspect ? '1:1 裁剪' : '自由拉伸'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSending ? null : _onResetCrop,
            icon: const Icon(Icons.refresh),
            label: const Text('重置裁剪'),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeSelector(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Text('尺寸', style: theme.textTheme.titleSmall),
        const SizedBox(width: 12),
        ..._sizePresets.map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$s'),
                selected: _size == s,
                onSelected: _isSending ? null : (_) => _onSizeTap(s),
              ),
            )),
      ],
    );
  }

  Widget _buildToggles(ThemeData theme, ColorScheme cs) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('RLE 压缩'),
          subtitle: const Text('减小体积、加快传输'),
          value: _compress,
          onChanged: _isSending ? null : _onCompressChange,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('抖动 (Floyd–Steinberg)'),
          subtitle: const Text('改善渐变，降低色带'),
          value: _dither,
          onChanged: _isSending ? null : _onDitherChange,
        ),
      ],
    );
  }

  Widget _buildBinInfo(ThemeData theme, ColorScheme cs) {
    String right;
    if (_converting) {
      right = '转换中…';
    } else if (_binSize > 0) {
      right = '$_size×$_size · ${formatFileSize(_binSize)}';
    } else {
      right = '—';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('原图 ${formatFileSize(_sourceSize)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        Row(
          children: [
            if (_converting)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Text(right,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatus(
      ThemeData theme, ColorScheme cs, TransferState state) {
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

  Widget _buildActionButton(ColorScheme cs, bool sending) {
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
    final bool canSend = _bin != null && !_converting && _selectedImage != null;
    return FilledButton.icon(
      onPressed: canSend ? _send : null,
      icon: const Icon(Icons.send),
      label: const Text('发送到设备'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}
