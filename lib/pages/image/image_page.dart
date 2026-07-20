import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/transfer_provider.dart';
import '../../services/image_bin.dart';
import '../../services/raster.dart';
import '../../services/l2_file_transfer.dart';
import '../../services/file_cache.dart';
import '../shared/cache_ui.dart';
import '../shared/color_picker_dialog.dart';
import '../shared/example_assets.dart';
import '../shared/file_send_layout.dart';

/// Page for converting a picked image to a device RGB565 `.bin` and sending it
/// over BLE. The preview is a fixed square viewport: on load the whole image is
/// scaled to fit (contain), and the user pinch-zooms / pans to frame the region
/// to send — whatever is inside the square frame becomes the output (letterbox
/// filled black). Then size 240/360/480 → auto RLE/uncompressed → send.
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

const List<int> _sizePresets = [240, 360, 466, 480];
const double _previewMaxHRatio = 0.5; // viewport max height = 50% of screen

// Common background (letterbox / out-of-frame) colors; the palette button lets
// the user pick any color beyond these.
const List<int> _bgColors = [
  0xFF000000, // black
  0xFFFFFFFF, // white
  0xFFFF3B30, // red
  0xFF34C759, // green
  0xFF007AFF, // blue
  0xFFFFCC00, // yellow
];

class _ImagePageState extends ConsumerState<ImagePage> {
  final _picker = ImagePicker();
  final TransformationController _tc = TransformationController();

  // Captured while mounted so dispose() never touches `ref` (see initState).
  late final TransferProgressNotifier _transfer;

  XFile? _selectedImage;
  ui.Image? _srcImage;
  int _srcW = 0;
  int _srcH = 0;
  String _fileName = 'image.bin';
  int _sourceSize = 0;

  // Square preview viewport side in px (set during layout; the frame == output).
  double _vp = 0;
  // Active pointers over the preview viewport. While > 0 the page scroll is
  // suppressed so a pinch-zoom / pan edits the image instead of scrolling the
  // page out from under the user's fingers.
  int _viewportPointers = 0;

  // Conversion options.
  int _size = kImageDefaultSize; // 360
  bool _dither = false;
  int _bgColor = 0xFF000000; // viewport letterbox / out-of-frame fill

  // Conversion result. RLE-compressed vs uncompressed are both computed; the
  // smaller wins automatically (no user toggle), and both sizes are shown.
  Uint8List? _bin;
  int _binSize = 0;
  int _rawSize = 0; // uncompressed .bin size
  int _rleSize = 0; // RLE-compressed .bin size
  bool _usedCompress = false; // whether RLE (the smaller one) was chosen
  bool _converting = false;
  int _rebuildSeq = 0;

  // Cache mode: when a cached file is loaded, the editing UI is replaced by a
  // read-only panel and the send button re-sends the cached bytes as-is.
  CacheEntry? _cacheEntry;
  Uint8List? _cacheBytes;
  bool get _cacheMode => _cacheEntry != null;

  @override
  void initState() {
    super.initState();
    // Capture the notifier while the element is still mounted. Using `ref`
    // inside dispose() throws (the element is already defunct there), which
    // would abort ConsumerStatefulElement.unmount() before it closes this
    // page's provider subscription — leaking a defunct listener that then
    // crashes on the next state write (markNeedsBuild on a defunct element).
    _transfer = ref.read(transferProgressProvider.notifier);
  }

  @override
  void dispose() {
    // Stop any in-flight send and clear stale status so re-entering starts
    // clean, via the captured notifier (never `ref` here). resetForDispose
    // defers the actual state write to a microtask so it lands after unmount
    // has closed this element's own subscription.
    _transfer.resetForDispose();
    _tc.dispose();
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
          const SnackBar(content: Text('请使用 视频 / GIF 功能发送 GIF 文件')),
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
      if (!mounted) {
        decoded.dispose();
        return;
      }
      _applyDecoded(decoded, bytes.length, image.name, image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  // Apply an already-decoded image as the current selection (shared by the
  // gallery picker and the built-in examples). [marker] is only a non-null
  // "something is loaded" flag — conversion works off [decoded], not its path.
  void _applyDecoded(
      ui.Image decoded, int byteLen, String name, XFile marker) {
    _srcImage?.dispose();
    final base =
        name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    setState(() {
      _selectedImage = marker;
      _srcImage = decoded;
      _srcW = decoded.width;
      _srcH = decoded.height;
      _sourceSize = byteLen;
      _fileName = '$base.bin';
      _bin = null;
      _binSize = 0;
      _rawSize = 0;
      _rleSize = 0;
      _tc.value = Matrix4.identity(); // reset zoom/pan to fit
    });
    ref.read(transferProgressProvider.notifier).reset();
    _rebuild();
  }

  // Load one of the bundled example images (assets/example/img/*.png).
  Future<void> _loadExampleImage(String assetPath) async {
    if (_isSending) return;
    try {
      final data = await rootBundle.load(assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final decoded = await decodeUiImage(bytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      _applyDecoded(
          decoded, bytes.length, assetPath.split('/').last, XFile(assetPath));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载示例失败: $e')));
    }
  }

  // ── Conversion ───────────────────────────────────────────────────────────
  Future<void> _rebuild() async {
    final src = _srcImage;
    if (src == null || _srcW <= 0 || _srcH <= 0) return;
    if (_vp <= 0) {
      // Preview not laid out yet — retry once the viewport size is known.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuild();
      });
      return;
    }
    final int token = ++_rebuildSeq;
    // Keep the previous result visible while re-converting so the info row and
    // send button don't flash on every zoom/pan; they update in place after.
    setState(() => _converting = true);
    try {
      // Map source px → output px from the current pinch-zoom transform.
      final double v = _vp;
      final double s0 = min(v / _srcW, v / _srcH); // contain scale in v×v box
      final double lx = (v - _srcW * s0) / 2;
      final double ly = (v - _srcH * s0) / 2;
      final m = _tc.value;
      final double k = m.getMaxScaleOnAxis();
      final double mtx = m.storage[12];
      final double mty = m.storage[13];
      final double f = _size / v; // viewport px → output px
      final double scaleOut = k * s0 * f;
      final double txOut = (k * lx + mtx) * f;
      final double tyOut = (k * ly + mty) * f;

      final RgbaImage img = await renderViewportRgba(
        src,
        outSize: _size,
        scale: scaleOut,
        tx: txOut,
        ty: tyOut,
        bgColor: _bgColor,
      );
      final ImageBinResult result = buildImageBinAdaptive(
        img.rgba,
        img.width,
        img.height,
        dither: _dither,
      );
      if (token != _rebuildSeq || !mounted) return;
      setState(() {
        _bin = result.bin;
        _binSize = result.bin.length;
        _rawSize = result.rawSize;
        _rleSize = result.rleSize;
        _usedCompress = result.compressed;
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

  void _onDitherChange(bool v) {
    if (_isSending) return;
    setState(() => _dither = v);
    _rebuild();
  }

  void _onBgColorTap(int c) {
    if (_isSending) return;
    setState(() => _bgColor = c);
    _rebuild();
  }

  void _onResetView() {
    if (_isSending) return;
    _tc.value = Matrix4.identity();
    _rebuild();
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  void _send() {
    final bin = _bin;
    if (bin == null || _converting || _isSending) return;
    ref.read(transferProgressProvider.notifier).send(
          TYPE.image,
          bin,
          _fileName,
          trailingByte: 0, // 0 = 图片
          cache: CacheSpec(CacheKind.image, {
            'size': '$_size',
            'cmp': _usedCompress ? 'rle' : 'raw',
          }),
        );
  }

  // ── Cache load / send ────────────────────────────────────────────────────
  Future<void> _loadCache() async {
    if (_isSending) return;
    final entry = await showCachePicker(context, CacheKind.image);
    if (entry == null || !mounted) return;
    try {
      final bytes = await entry.file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _cacheEntry = entry;
        _cacheBytes = bytes;
      });
      ref.read(transferProgressProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('读取缓存失败: $e')));
    }
  }

  void _clearCache() {
    setState(() {
      _cacheEntry = null;
      _cacheBytes = null;
    });
  }

  // Re-send the loaded cache bytes unchanged; no cache: arg so it isn't re-cached.
  void _sendCache() {
    final bytes = _cacheBytes;
    final entry = _cacheEntry;
    if (bytes == null || entry == null || _isSending) return;
    ref.read(transferProgressProvider.notifier).send(
          entry.kind.fileType,
          bytes,
          entry.kind.deviceName,
          trailingByte: entry.kind.trailingByte,
        );
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferProgressProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sending = transferState.status == TransferStatus.sending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('发送图片'),
        actions: [
          if (_selectedImage != null && !_cacheMode)
            IconButton(
              onPressed: _isSending ? null : _pickImage,
              icon: const Icon(Icons.folder_open),
              tooltip: '更换图片',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Freeze page scroll while the user is editing inside the preview
              // (pinch-zoom / pan) so the gesture never leaks into scrolling.
              physics: _viewportPointers > 0
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _cacheMode
                    ? [
                        CacheLoadedPanel(
                          entry: _cacheEntry!,
                          onChange: _loadCache,
                          onClear: _clearCache,
                        ),
                      ]
                    : [
                        // Always show the "loaded" layout; the preview viewport
                        // just stays empty (tap to pick) until an image is set.
                        _buildPreview(theme, cs),
                        const SizedBox(height: 10),
                        _buildExamples(theme, cs, enabled: !sending),
                        if (_srcImage != null) ...[
                          const SizedBox(height: 8),
                          _buildViewControls(theme, cs),
                        ],
                        const SizedBox(height: 16),
                        _buildSizeSelector(theme, cs),
                        const SizedBox(height: 8),
                        _buildBgColorRow(theme, cs),
                        const SizedBox(height: 8),
                        _buildToggles(theme, cs),
                        const SizedBox(height: 12),
                        _buildBinInfo(theme, cs),
                      ],
              ),
            ),
          ),
          _buildBottomBar(theme, cs, transferState, sending),
        ],
      ),
    );
  }

  // Pinned bottom bar: transfer progress + status + action button, always
  // visible (does not scroll with the page content).
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
              _buildActionButton(cs, sending),
            ],
          ),
        ),
      ),
    );
  }

  // Empty circular viewport shown before an image is picked — tap to pick.
  Widget _buildEmptyViewport(ThemeData theme, ColorScheme cs, double v) {
    return GestureDetector(
      onTap: _isSending ? null : _pickImage,
      child: Container(
        width: v,
        height: v,
        color: cs.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 44, color: cs.outline),
            const SizedBox(height: 8),
            Text('点击选择图片',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
          ],
        ),
      ),
    );
  }

  // A horizontal strip of round example thumbnails under the preview; tapping
  // one loads that bundled image directly.
  Widget _buildExamples(ThemeData theme, ColorScheme cs,
      {required bool enabled}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('示例', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ExampleStrip(
          count: ExampleAssets.images.length,
          enabled: enabled,
          thumbBuilder: (i) => Image.asset(
            ExampleAssets.images[i],
            fit: BoxFit.cover,
            cacheWidth: 120,
          ),
          onTap: (i) => _loadExampleImage(ExampleAssets.images[i]),
        ),
      ],
    );
  }

  // Fixed circular viewport representing the device's round 360×360 screen. The
  // image is pinch-zoomed / panned underneath; on first load it fits (contain),
  // centered. The sent bitmap is still square (crop math unchanged) — the circle
  // just marks what the round screen actually shows, so frame content within it.
  Widget _buildPreview(ThemeData theme, ColorScheme cs) {
    final double maxH = MediaQuery.of(context).size.height * _previewMaxHRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double v = min(constraints.maxWidth, maxH);
        _vp = v;
        return Center(
          child: Listener(
            // Track fingers on the viewport so page scroll can be frozen while
            // the image is being pinch-zoomed / panned (see SingleChildScrollView).
            onPointerDown: (_) => setState(() => _viewportPointers++),
            onPointerUp: (_) =>
                setState(() => _viewportPointers = (_viewportPointers - 1).clamp(0, 99)),
            onPointerCancel: (_) =>
                setState(() => _viewportPointers = (_viewportPointers - 1).clamp(0, 99)),
            child: Container(
              width: v,
              height: v,
              // Ring marks the round-screen boundary; drawn over the content.
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: ClipOval(
                child: _srcImage == null
                    ? _buildEmptyViewport(theme, cs, v)
                    : SizedBox(
                        width: v,
                        height: v,
                        child: Stack(
                          children: [
                            Positioned.fill(
                                child: ColoredBox(color: Color(_bgColor))),
                            InteractiveViewer(
                              transformationController: _tc,
                              minScale: 1.0,
                              maxScale: 8.0,
                              clipBehavior: Clip.hardEdge,
                              onInteractionEnd: (_) => _rebuild(),
                              child: SizedBox(
                                width: v,
                                height: v,
                                child: RawImage(
                                    image: _srcImage, fit: BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
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
          child: Text('双指缩放 / 拖动取景，圆内即屏幕显示区域',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ),
        TextButton.icon(
          onPressed: _isSending ? null : _onResetView,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重置'),
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

  // Background fill for the letterbox / out-of-frame area (visible when the
  // image is zoomed out or panned past an edge inside the circular viewport).
  Widget _buildBgColorRow(ThemeData theme, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('背景', style: theme.textTheme.titleSmall),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ColorSwatchStrip(
            presets: _bgColors,
            selected: _bgColor,
            onChanged: _onBgColorTap,
            enabled: !_isSending,
          ),
        ),
      ],
    );
  }

  Widget _buildToggles(ThemeData theme, ColorScheme cs) {
    // RLE compression is now chosen automatically (smaller of RLE/uncompressed),
    // so only the dither option remains user-facing.
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('抖动 (Floyd–Steinberg)'),
      subtitle: const Text('改善渐变，降低色带'),
      value: _dither,
      onChanged: _isSending ? null : _onDitherChange,
    );
  }

  Widget _buildBinInfo(ThemeData theme, ColorScheme cs) {
    final tt = theme.textTheme;

    if (_selectedImage == null) {
      return Text('点击上方预览区选择图片，或选择下方示例',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant));
    }

    // Only before the very first result show the simple single line. During a
    // re-convert we keep the previous comparison rendered (below) so the row
    // never collapses/reflows while zooming/panning.
    if (_binSize == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('原图 ${formatFileSize(_sourceSize)}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
              Text(_converting ? '转换中…' : '—',
                  style: tt.bodyMedium?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      );
    }

    // Before/after comparison: both encodings shown, the chosen (smaller) one
    // highlighted; RLE compression is applied automatically.
    final int savePct = _rawSize > 0 && _binSize < _rawSize
        ? (100 * (_rawSize - _binSize) / _rawSize).round()
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('原图 ${formatFileSize(_sourceSize)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            Text('$_size×$_size · 已用 ${formatFileSize(_binSize)}',
                style: tt.bodyMedium?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _sizeTag(cs, tt, '未压缩', _rawSize, !_usedCompress),
            const SizedBox(width: 8),
            _sizeTag(cs, tt, 'RLE 压缩', _rleSize, _usedCompress),
            const Spacer(),
            if (savePct > 0)
              Text('省 $savePct%',
                  style: tt.bodySmall?.copyWith(
                      color: cs.secondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _sizeTag(
      ColorScheme cs, TextTheme tt, String label, int bytes, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${formatFileSize(bytes)}',
        style: tt.bodySmall?.copyWith(
          color: selected ? cs.primary : cs.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildStatus(ThemeData theme, ColorScheme cs, TransferState state) {
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
    final Widget primary;
    if (_cacheMode) {
      primary = FilledButton.icon(
        onPressed: _cacheBytes != null ? _sendCache : null,
        icon: const Icon(Icons.send),
        label: const Text('发送缓存'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      );
    } else {
      // Stay enabled during a re-convert (the retained bin is still valid) to
      // avoid a color flash on each zoom/pan; _send() no-ops while _converting.
      final bool canSend = _bin != null && _selectedImage != null;
      primary = FilledButton.icon(
        onPressed: canSend ? _send : null,
        icon: const Icon(Icons.send),
        label: const Text('发送到设备'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      );
    }
    // Circular "load cache" button sits to the left of the send button.
    return Row(
      children: [
        CacheLoadButton(onPressed: _loadCache),
        const SizedBox(width: 12),
        Expanded(child: primary),
      ],
    );
  }
}
