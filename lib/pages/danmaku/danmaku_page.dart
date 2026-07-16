import 'dart:async';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transfer_provider.dart';
import '../../services/image_bin.dart';
import '../../services/raster.dart';
import '../../services/l2_file_transfer.dart';
import '../../services/file_cache.dart';
import '../shared/cache_ui.dart';
import '../shared/color_picker_dialog.dart';
import '../shared/file_send_layout.dart';

/// Page for rendering danmaku text and sending it over BLE.
///
/// Conversion/send is always the same: the whole text is rendered to a device
/// RGB565 `.bin` (uncompressed) and sent as TYPE.image, mirroring the
/// miniprogram flow: text + font + size + bold + text/bg color → auto-sized
/// bitmap → buildImageBin(compress:false) → send 'danmaku.bin'.
///
/// A mode toggle changes the *preview only* — it never changes what is sent:
///  * 全览 (overview) — the whole text bitmap, contain-fit.
///  * 滚动 (scroll) — a circular 360×360 viewport animating the strip right→left
///    (marquee style), showing how the image will look scrolling on the round
///    screen. Purely a preview; the firmware still receives the full-text image.
class DanmakuPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const DanmakuPage(
      {super.key, required this.deviceName, required this.deviceId});

  @override
  ConsumerState<DanmakuPage> createState() => _DanmakuPageState();
}

const int _maxChars = 60;
const double _fontMin = 16;
const double _fontMax = 240;

// Free system font families (label → css family string).
const List<(String, String)> _fontFamilies = [
  ('黑体', 'sans-serif'),
  ('宋体', 'serif'),
  ('等宽', 'monospace'),
];

// Text colors — the common ones; less-used cyan / magenta are dropped and
// reachable via the palette button instead.
const List<int> _textColors = [
  0xFFFFFFFF, // white
  0xFF000000, // black
  0xFFFFFF00, // yellow
  0xFFFF0000, // red
  0xFF00FF00, // green
  0xFF0000FF, // blue
];

// Background — pure red / green / blue / white.
const List<int> _bgColors = [
  0xFFFF0000,
  0xFF00FF00,
  0xFF0000FF,
  0xFFFFFFFF,
];

// The device's round screen side (px). Scroll videos are rendered at this size,
// and the blank gap between scroll repeats defaults to one full screen.
const int _screenSize = 360;
const int _scrollGap = 360;
// Fixed medium scroll speed (px/sec on the 360px screen); not user-adjustable.
const int _scrollSpeed = 120;

// Preview only — both modes send the same full-text image (TYPE.image).
// 全览 = show the whole text at once; 滚动 = animate it scrolling for preview.
enum _DanmakuMode { overview, scroll }

class _DanmakuPageState extends ConsumerState<DanmakuPage>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();

  // Captured while mounted so dispose() never touches `ref` (see initState).
  late final TransferProgressNotifier _transfer;

  String _fontFamily = 'sans-serif';
  double _fontSize = 48;
  bool _bold = true;
  int _textColor = 0xFFFFFFFF;
  int _bgColor = 0xFF0000FF;

  ui.Image? _previewImage;
  int _imgW = 0;
  int _imgH = 0;
  Uint8List? _bin;
  int _binSize = 0;
  int _rebuildSeq = 0;

  // Cache mode: a loaded cached danmaku replaces the editor with a read-only
  // panel; the send button then re-sends those bytes unchanged.
  CacheEntry? _cacheEntry;
  Uint8List? _cacheBytes;
  bool get _cacheMode => _cacheEntry != null;

  // Scroll mode drives the circular preview animation only; the send payload is
  // the full-text image from _rebuild (identical in both preview modes).
  _DanmakuMode _mode = _DanmakuMode.overview;
  late final AnimationController _scrollCtl;

  @override
  void initState() {
    super.initState();
    // Capture the notifier while mounted; using `ref` in dispose() throws once
    // the element is defunct and would leak this page's provider subscription
    // (a defunct listener that crashes the next state write).
    _transfer = ref.read(transferProgressProvider.notifier);
    _scrollCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // replaced per period in _syncScrollAnim
    );
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild());
  }

  @override
  void dispose() {
    // Stop any in-flight send and clear stale status so re-entering starts
    // clean, via the captured notifier (never `ref` here). resetForDispose
    // defers the actual state write to a microtask so it lands after unmount
    // has closed this element's own subscription.
    _transfer.resetForDispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollCtl.dispose();
    _previewImage?.dispose();
    super.dispose();
  }

  bool get _isSending =>
      ref.read(transferProgressProvider).status == TransferStatus.sending;

  void _onTextChanged() => _rebuild();

  // Render preview only (no bin) — used during continuous slider drag.
  Future<void> _renderPreview() async {
    final int token = ++_rebuildSeq;
    try {
      final RgbaImage img = await renderDanmakuRgba(
        text: _controller.text,
        fontSize: _fontSize,
        bold: _bold,
        fontFamily: _fontFamily,
        color: _textColor,
        bgColor: _bgColor,
      );
      if (token != _rebuildSeq || !mounted) return;
      await _setPreview(img, token);
      if (token != _rebuildSeq || !mounted) return;
      setState(() {
        _bin = null;
        _binSize = 0;
      });
    } catch (_) {
      // Ignore transient render failures during drag.
    }
  }

  // Render preview + build bin — used on discrete changes / drag end.
  Future<void> _rebuild() async {
    final int token = ++_rebuildSeq;
    try {
      final RgbaImage img = await renderDanmakuRgba(
        text: _controller.text,
        fontSize: _fontSize,
        bold: _bold,
        fontFamily: _fontFamily,
        color: _textColor,
        bgColor: _bgColor,
      );
      if (token != _rebuildSeq || !mounted) return;
      await _setPreview(img, token);
      if (token != _rebuildSeq || !mounted) return;
      // Uncompressed: simplest layout for the device to address by offset.
      // Built in both preview modes — the send payload is mode-independent.
      final Uint8List bin =
          buildImageBin(img.rgba, img.width, img.height, compress: false);
      if (token != _rebuildSeq || !mounted) return;
      setState(() {
        _bin = bin;
        _binSize = bin.length;
      });
    } catch (e) {
      if (token != _rebuildSeq || !mounted) return;
      setState(() {
        _bin = null;
        _binSize = 0;
      });
    }
  }

  Future<void> _setPreview(RgbaImage img, int token) async {
    final ui.Image decoded = await _rgbaToImage(img);
    if (token != _rebuildSeq || !mounted) {
      decoded.dispose();
      return;
    }
    final ui.Image? old = _previewImage;
    setState(() {
      _previewImage = decoded;
      _imgW = img.width;
      _imgH = img.height;
    });
    old?.dispose();
    if (_mode == _DanmakuMode.scroll) _syncScrollAnim();
  }

  Future<ui.Image> _rgbaToImage(RgbaImage img) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      img.rgba,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  // ── Option handlers ─────────────────────────────────────────────────────────
  void _onFontTap(String css) {
    if (_isSending || css == _fontFamily) return;
    setState(() => _fontFamily = css);
    _rebuild();
  }

  void _onBoldChange(bool v) {
    if (_isSending) return;
    setState(() => _bold = v);
    _rebuild();
  }

  void _onTextColorTap(int c) {
    if (_isSending) return;
    setState(() => _textColor = c);
    _rebuild();
  }

  void _onBgColorTap(int c) {
    if (_isSending) return;
    setState(() => _bgColor = c);
    _rebuild();
  }

  // The mode toggle only changes the preview; the send payload (_bin) is
  // mode-independent, so it is neither invalidated nor rebuilt here.
  void _onModeChange(_DanmakuMode m) {
    if (_isSending || m == _mode) return;
    setState(() => _mode = m);
    if (m == _DanmakuMode.scroll) {
      _syncScrollAnim();
    } else {
      _scrollCtl.stop();
    }
  }

  // Re-time the circular preview loop so its on-screen speed matches what the
  // device will play: one full period (strip + gap) takes period/speed seconds.
  void _syncScrollAnim() {
    if (_mode != _DanmakuMode.scroll || _previewImage == null) {
      _scrollCtl.stop();
      return;
    }
    final double period = (_imgW + _scrollGap).toDouble();
    final double speed = _scrollSpeed <= 0 ? 1 : _scrollSpeed.toDouble();
    final int ms = (period / speed * 1000).round().clamp(300, 60000);
    _scrollCtl.duration = Duration(milliseconds: ms);
    _scrollCtl
      ..reset()
      ..repeat();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Always sends the full-text image, regardless of the preview mode.
  void _send() {
    if (_isSending) return;
    if (_controller.text.trim().isEmpty) {
      _snack('请输入弹幕内容');
      return;
    }
    final bin = _bin;
    if (bin == null) return;
    ref.read(transferProgressProvider.notifier).send(
          TYPE.image,
          bin,
          'danmaku.bin',
          trailingByte: 1, // 1 = 弹幕
          cache: CacheSpec(CacheKind.danmaku, {'w': '$_imgW', 'h': '$_imgH'}),
        );
  }

  // ── Cache load / send ────────────────────────────────────────────────────
  Future<void> _loadCache() async {
    if (_isSending) return;
    final entry = await showCachePicker(context, CacheKind.danmaku);
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
      _snack('读取缓存失败: $e');
    }
  }

  void _clearCache() {
    setState(() {
      _cacheEntry = null;
      _cacheBytes = null;
    });
  }

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
      appBar: AppBar(title: const Text('发送弹幕')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                        _buildPreview(theme, cs),
                        const SizedBox(height: 16),
                        _buildModeRow(theme, cs),
                        const SizedBox(height: 12),
                        _buildTextField(theme, cs),
                        const SizedBox(height: 12),
                        _buildFontRow(theme, cs),
                        const SizedBox(height: 4),
                        _buildSizeSlider(theme, cs),
                        _buildBoldSwitch(theme, cs),
                        const SizedBox(height: 8),
                        _buildColorRow(theme, cs, '文字颜色', _textColors,
                            _textColor, _onTextColorTap),
                        const SizedBox(height: 8),
                        _buildColorRow(theme, cs, '背景颜色', _bgColors, _bgColor,
                            _onBgColorTap),
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

  Widget _buildPreview(ThemeData theme, ColorScheme cs) {
    return _mode == _DanmakuMode.scroll
        ? _buildScrollPreview(theme, cs)
        : _buildOverviewPreview(theme, cs);
  }

  // 全览: the whole text bitmap, contain-fit in a rounded rectangle.
  Widget _buildOverviewPreview(ThemeData theme, ColorScheme cs) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.22,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: _previewImage == null
          ? Text('预览', style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _imgW.toDouble(),
                      height: _imgH.toDouble(),
                      child: RawImage(image: _previewImage, fit: BoxFit.fill),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _binSize > 0
                      ? '$_imgW×$_imgH · ${formatFileSize(_binSize)}'
                      : '$_imgW×$_imgH',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
    );
  }

  // 滚动: a circular viewport (the round 360×360 screen) with the text strip
  // sweeping right→left, looping — the same motion the device will play.
  Widget _buildScrollPreview(ThemeData theme, ColorScheme cs) {
    final double maxH = MediaQuery.of(context).size.height * 0.3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double v = min(constraints.maxWidth, maxH);
        return Center(
          child: Container(
            width: v,
            height: v,
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: ClipOval(
              child: _previewImage == null
                  ? ColoredBox(color: Color(_bgColor))
                  : AnimatedBuilder(
                      animation: _scrollCtl,
                      builder: (_, __) => CustomPaint(
                        size: Size(v, v),
                        painter: _ScrollPreviewPainter(
                          strip: _previewImage!,
                          bgColor: _bgColor,
                          phase: _scrollCtl.value,
                          gap: _scrollGap.toDouble(),
                          screen: _screenSize.toDouble(),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeRow(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Text('模式', style: theme.textTheme.titleSmall),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<_DanmakuMode>(
            segments: const [
              ButtonSegment(
                value: _DanmakuMode.overview,
                label: Text('全览'),
                icon: Icon(Icons.fit_screen_outlined),
              ),
              ButtonSegment(
                value: _DanmakuMode.scroll,
                label: Text('滚动'),
                icon: Icon(Icons.slideshow_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged:
                _isSending ? null : (s) => _onModeChange(s.first),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(ThemeData theme, ColorScheme cs) {
    return TextField(
      controller: _controller,
      maxLength: _maxChars,
      maxLines: 3,
      minLines: 1,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        hintText: '输入弹幕内容…',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildFontRow(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Text('字体', style: theme.textTheme.titleSmall),
        const SizedBox(width: 12),
        ..._fontFamilies.map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.$1),
                selected: _fontFamily == f.$2,
                onSelected: _isSending ? null : (_) => _onFontTap(f.$2),
              ),
            )),
      ],
    );
  }

  Widget _buildSizeSlider(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Text('字号', style: theme.textTheme.titleSmall),
        Expanded(
          child: Slider(
            value: _fontSize.clamp(_fontMin, _fontMax).toDouble(),
            min: _fontMin,
            max: _fontMax,
            divisions: (_fontMax - _fontMin).toInt(),
            label: '${_fontSize.round()}',
            onChanged: _isSending
                ? null
                : (v) {
                    setState(() => _fontSize = v);
                    _renderPreview();
                  },
            onChangeEnd: _isSending ? null : (_) => _rebuild(),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${_fontSize.round()}',
              textAlign: TextAlign.end, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildBoldSwitch(ThemeData theme, ColorScheme cs) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('加粗'),
      value: _bold,
      onChanged: _isSending ? null : _onBoldChange,
    );
  }

  Widget _buildColorRow(ThemeData theme, ColorScheme cs, String label,
      List<int> colors, int selected, void Function(int) onTap) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(label, style: theme.textTheme.titleSmall),
          ),
        ),
        Expanded(
          child: ColorSwatchStrip(
            presets: colors,
            selected: selected,
            onChanged: onTap,
            enabled: !_isSending,
          ),
        ),
      ],
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
      final bool canSend = _bin != null && _controller.text.trim().isNotEmpty;
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

// Preview-only painter: shows the danmaku strip scrolling right→left across the
// round screen, looping seamlessly, so the user can gauge how the full-text
// image will read while marqueeing. The strip is drawn at 1:1 device pixels
// (scaled to the on-screen box) and tiled every `period = stripWidth + gap`;
// [phase] (0..1) advances the sweep.
class _ScrollPreviewPainter extends CustomPainter {
  final ui.Image strip;
  final int bgColor;
  final double phase;
  final double gap; // device px
  final double screen; // device px (360)

  _ScrollPreviewPainter({
    required this.strip,
    required this.bgColor,
    required this.phase,
    required this.gap,
    required this.screen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(bgColor));

    final double scale = size.width / screen; // on-screen px per device px
    final double stripW = strip.width.toDouble();
    final double stripH = strip.height.toDouble();
    final double period = stripW + gap;
    // right→left: baseX runs period→0 as phase advances (matches native encode).
    final double baseX = period * (1 - phase);
    final double dy = (screen - stripH) / 2 * scale; // vertical centering
    final double dstW = stripW * scale;
    final double dstH = stripH * scale;
    final src = Rect.fromLTWH(0, 0, stripW, stripH);
    final paint = Paint()..filterQuality = FilterQuality.low;

    // One copy starts off the left edge; tile rightward until past the screen.
    double x = baseX - period;
    while (x < screen) {
      canvas.drawImageRect(
          strip, src, Rect.fromLTWH(x * scale, dy, dstW, dstH), paint);
      x += period;
    }
  }

  @override
  bool shouldRepaint(covariant _ScrollPreviewPainter old) =>
      old.phase != phase ||
      old.strip != strip ||
      old.bgColor != bgColor ||
      old.gap != gap ||
      old.screen != screen;
}
