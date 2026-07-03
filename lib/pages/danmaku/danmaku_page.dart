import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transfer_provider.dart';
import '../../services/image_bin.dart';
import '../../services/raster.dart';
import '../../services/l2_file_transfer.dart';
import '../shared/file_send_layout.dart';

/// Page for rendering danmaku text to a device RGB565 `.bin` (uncompressed)
/// and sending it over BLE as TYPE.image. Mirrors the miniprogram danmaku flow:
/// text + font family + size + bold + text/bg color → auto-sized bitmap →
/// buildImageBin(compress:false) → send 'danmaku.bin'.
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

// Text colors — common pure colors that map cleanly to RGB565.
const List<int> _textColors = [
  0xFFFFFFFF, // white
  0xFF000000, // black
  0xFFFFFF00, // yellow
  0xFFFF0000, // red
  0xFF00FF00, // green
  0xFF0000FF, // blue
  0xFF00FFFF, // cyan
  0xFFFF00FF, // magenta
];

// Background — pure red / green / blue / white.
const List<int> _bgColors = [
  0xFFFF0000,
  0xFF00FF00,
  0xFF0000FF,
  0xFFFFFFFF,
];

class _DanmakuPageState extends ConsumerState<DanmakuPage> {
  final _controller = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild());
  }

  @override
  void dispose() {
    // Reset send status on leave so re-entering never shows a stale result.
    final notifier = ref.read(transferProgressProvider.notifier);
    if (ref.read(transferProgressProvider).status == TransferStatus.sending) {
      notifier.abort();
    } else {
      notifier.reset();
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
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

  void _send() {
    final bin = _bin;
    if (bin == null || _isSending) return;
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入弹幕内容')),
      );
      return;
    }
    ref
        .read(transferProgressProvider.notifier)
        .send(TYPE.image, bin, 'danmaku.bin');
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferProgressProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sending = transferState.status == TransferStatus.sending;

    return Scaffold(
      appBar: AppBar(title: const Text('发送弹幕')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPreview(theme, cs),
            const SizedBox(height: 16),
            _buildTextField(theme, cs),
            const SizedBox(height: 12),
            _buildFontRow(theme, cs),
            const SizedBox(height: 4),
            _buildSizeSlider(theme, cs),
            _buildBoldSwitch(theme, cs),
            const SizedBox(height: 8),
            _buildColorRow(theme, cs, '文字颜色', _textColors, _textColor,
                _onTextColorTap),
            const SizedBox(height: 8),
            _buildColorRow(
                theme, cs, '背景颜色', _bgColors, _bgColor, _onBgColorTap),
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

  Widget _buildPreview(ThemeData theme, ColorScheme cs) {
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
      children: [
        SizedBox(
            width: 72,
            child: Text(label, style: theme.textTheme.titleSmall)),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((c) {
              final bool sel = c == selected;
              return GestureDetector(
                onTap: _isSending ? null : () => onTap(c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? cs.primary : cs.outlineVariant,
                      width: sel ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
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
    final bool canSend = _bin != null && _controller.text.trim().isNotEmpty;
    return FilledButton.icon(
      onPressed: canSend ? _send : null,
      icon: const Icon(Icons.send),
      label: const Text('发送到设备'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}
