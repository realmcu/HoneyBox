import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/converter.dart';
import '../../services/file_cache.dart';
import '../../services/image_bin.dart';
import '../../services/image_jpeg.dart';
import 'file_send_layout.dart';

// ── Formatting helpers (shared by the picker, panel and management page) ──────

/// Leading icon for a cache category.
IconData cacheKindIcon(CacheKind kind) {
  switch (kind) {
    case CacheKind.image:
      return Icons.image_outlined;
    case CacheKind.danmaku:
      return Icons.subtitles_outlined;
    case CacheKind.video:
      return Icons.movie_outlined;
  }
}

String _two(int n) => n < 10 ? '0$n' : '$n';

/// `yyyy-MM-dd HH:mm` for a cache entry's timestamp.
String cacheTimeLabel(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// Human-readable one-line summary of an entry's conversion parameters, derived
/// from the filename (mirrors what each page shows in its own convert-info row).
String cacheParamSummary(CacheEntry e) {
  final p = e.params;
  final parts = <String>[];
  switch (e.kind) {
    case CacheKind.image:
      final size = p['size'];
      if (size != null) parts.add('$size×$size');
      if (p['fmt'] == 'jpeg') {
        final q = p['q'];
        parts.add(q != null ? 'JPEG $q%' : 'JPEG');
      } else {
        final cmp = p['cmp'];
        if (cmp == 'rle') {
          parts.add('RLE');
        } else if (cmp == 'raw') {
          parts.add('未压缩');
        }
      }
      break;
    case CacheKind.danmaku:
      final w = p['w'], h = p['h'];
      if (w != null && h != null) parts.add('$w×$h');
      break;
    case CacheKind.video:
      // Source tag first, so 视频/GIF/轮播 are distinguishable in the list and
      // management page (plain video carries no tag).
      switch (p['src']) {
        case 'gif':
          parts.add('GIF');
          break;
        case 'slideshow':
          parts.add('轮播');
          break;
      }
      final size = p['size'];
      if (size != null) parts.add('$size×$size');
      final fps = p['fps'];
      if (fps != null) parts.add('${fps}fps');
      final frames = p['frames'];
      if (frames != null) parts.add('$frames 帧');
      final slides = p['slides'];
      if (slides != null) parts.add('$slides 图');
      break;
  }
  return parts.isEmpty ? e.kind.label : parts.join(' · ');
}

/// Decode a cache entry to a preview image (image/danmaku only; video → null).
/// Callers own the returned [ui.Image] and must dispose it.
Future<ui.Image?> loadCacheThumb(CacheEntry e) async {
  if (e.kind == CacheKind.video) return null;
  try {
    final bytes = await e.file.readAsBytes();
    // Image caches come in two formats under the same CacheKind.image: an RGB565
    // `.bin` or a JPEG container (header type byte distinguishes them). A JPEG
    // container decodes through Flutter's native codec off its stripped JFIF
    // payload; RGB565 (and danmaku) expands to RGBA via our own decoder.
    final jpeg = imageJpegPayload(bytes);
    if (jpeg != null) {
      final codec = await ui.instantiateImageCodec(jpeg);
      final frame = await codec.getNextFrame();
      return frame.image;
    }
    final px = decodeImageBin(bytes);
    if (px == null) return null;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      px.rgba,
      px.width,
      px.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  } catch (_) {
    return null;
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

/// Square rounded thumbnail for a cache entry. Decodes image/danmaku previews
/// itself (and disposes the decoded image), shows a category icon for video and
/// on decode failure.
class CacheThumb extends StatefulWidget {
  final CacheEntry entry;
  final double size;
  const CacheThumb({super.key, required this.entry, this.size = 48});

  @override
  State<CacheThumb> createState() => _CacheThumbState();
}

class _CacheThumbState extends State<CacheThumb> {
  ui.Image? _img;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CacheThumb old) {
    super.didUpdateWidget(old);
    if (old.entry.file.path != widget.entry.file.path) {
      _img?.dispose();
      _img = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final img = await loadCacheThumb(widget.entry);
    if (!mounted) {
      img?.dispose();
      return;
    }
    setState(() {
      _img?.dispose();
      _img = img;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.size;
    Widget content;
    if (widget.entry.kind == CacheKind.video || (!_loading && _img == null)) {
      content =
          Icon(cacheKindIcon(widget.entry.kind), color: cs.onSurfaceVariant, size: s * 0.5);
    } else if (_img == null) {
      content = SizedBox(
        width: s * 0.4,
        height: s * 0.4,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      content = SizedBox(
        width: s,
        height: s,
        child: RawImage(image: _img, fit: BoxFit.cover),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: s,
        height: s,
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

// ── Load button (circular; sits left of the send button) ──────────────────────

/// Round outlined button used to open the cache picker. Placed to the left of a
/// page's primary send/convert button.
class CacheLoadButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  const CacheLoadButton({super.key, required this.onPressed, this.tooltip = '载入缓存'});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            side: BorderSide(color: cs.outline),
            foregroundColor: cs.primary,
          ),
          child: const Icon(Icons.history, size: 22),
        ),
      ),
    );
  }
}

// ── Picker sheet ──────────────────────────────────────────────────────────────

/// Show a modal sheet listing cached files of [kind]; resolves to the chosen
/// [CacheEntry], or null if dismissed. Entries can also be deleted in place.
/// [where] optionally narrows a shared pool (e.g. only carousels); [label]
/// overrides the category word shown in the title / empty state.
Future<CacheEntry?> showCachePicker(
  BuildContext context,
  CacheKind kind, {
  bool Function(CacheEntry)? where,
  String? label,
}) {
  return showModalBottomSheet<CacheEntry>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _CachePickerSheet(kind: kind, where: where, label: label),
  );
}

class _CachePickerSheet extends ConsumerStatefulWidget {
  final CacheKind kind;
  final bool Function(CacheEntry)? where;
  final String? label;
  const _CachePickerSheet({required this.kind, this.where, this.label});

  @override
  ConsumerState<_CachePickerSheet> createState() => _CachePickerSheetState();
}

class _CachePickerSheetState extends ConsumerState<_CachePickerSheet> {
  late Future<List<CacheEntry>> _future;

  String get _label => widget.label ?? widget.kind.label;

  @override
  void initState() {
    super.initState();
    _future =
        ref.read(fileCacheProvider).list(kind: widget.kind, where: widget.where);
  }

  void _reload() {
    setState(() {
      _future = ref
          .read(fileCacheProvider)
          .list(kind: widget.kind, where: widget.where);
    });
  }

  Future<void> _delete(CacheEntry e) async {
    await ref.read(fileCacheProvider).delete(e.file);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(cacheKindIcon(widget.kind), size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('选择$_label缓存',
                      style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<CacheEntry>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('暂无$_label缓存',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = items[i];
                      return ListTile(
                        leading: CacheThumb(entry: e),
                        title: Text(cacheParamSummary(e),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${cacheTimeLabel(e.time)} · ${formatFileSize(e.size)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          tooltip: '删除',
                          onPressed: () => _delete(e),
                        ),
                        onTap: () => Navigator.of(context).pop(e),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loaded-cache panel (replaces a page's editing UI in cache mode) ───────────

/// Shown in place of a sender page's editing content once a cache file is
/// loaded: a [CachePreview] plus its size and parameters, presented like the
/// normal convert-info so the user can confirm before re-sending. [onChange]
/// reopens the picker; [onClear] exits cache mode.
class CacheLoadedPanel extends StatelessWidget {
  final CacheEntry entry;
  final VoidCallback onChange;
  final VoidCallback onClear;
  const CacheLoadedPanel({
    super.key,
    required this.entry,
    required this.onChange,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CachePreview(entry: entry),
        const SizedBox(height: 16),
        CacheInfoCard(entry: entry),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: onChange,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('更换缓存'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('取消载入'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Info card (kind · size · params · time) ───────────────────────────────────

/// The rounded info block shown beneath a preview: category, file size, the
/// param summary and the timestamp. Shared by [CacheLoadedPanel] and the
/// management-page preview sheet.
class CacheInfoCard extends StatelessWidget {
  final CacheEntry entry;
  const CacheInfoCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final e = entry;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cacheKindIcon(e.kind), size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('${e.kind.label}缓存', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(formatFileSize(e.size),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(cacheParamSummary(e),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(cacheTimeLabel(e.time),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Preview sheet (view a cache file, e.g. from the management page) ──────────

/// Show a modal sheet that previews [entry] (image/danmaku still or looping
/// video) with its info card and a delete action. Resolves to `true` if the
/// entry was deleted — so the caller can refresh its list — otherwise null.
Future<bool?> showCachePreview(BuildContext context, CacheEntry entry) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _CachePreviewSheet(entry: entry),
  );
}

class _CachePreviewSheet extends ConsumerWidget {
  final CacheEntry entry;
  const _CachePreviewSheet({required this.entry});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(fileCacheProvider).delete(entry.file);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(cacheKindIcon(entry.kind), size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('预览${entry.kind.label}缓存',
                      style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              CachePreview(
                entry: entry,
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              const SizedBox(height: 16),
              CacheInfoCard(entry: entry),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _delete(context, ref),
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  label: Text('删除', style: TextStyle(color: cs.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cache preview engine (still image / looping video) ────────────────────────

/// Renders a cache entry's visual preview: a decoded still for image/danmaku, or
/// the cached CVID/AVI decoded to frames and auto-looped for video (with a
/// play/pause overlay). Owns and disposes every decoded [ui.Image]. Used by
/// [CacheLoadedPanel] on the sender pages and by the management-page preview.
class CachePreview extends StatefulWidget {
  final CacheEntry entry;

  /// Max height of the preview box; defaults to 34% of the screen height.
  final double? maxHeight;
  const CachePreview({super.key, required this.entry, this.maxHeight});

  @override
  State<CachePreview> createState() => _CachePreviewState();
}

class _CachePreviewState extends State<CachePreview> {
  final _converter = ConverterService();

  // Image / danmaku: a single decoded still.
  ui.Image? _preview;

  // Video: decoded frames cycled by a timer. The cached AVI is Cinepak, which no
  // platform player can decode, so the frames come from our own [CinepakDecoder]
  // (see ConverterService.decodeCachedVideo).
  List<ui.Image>? _frames;
  int _frameIdx = 0;
  int _intervalMs = 100;
  Timer? _timer;
  bool _playing = false;
  bool _decodeFailed = false;

  bool get _isVideo => widget.entry.kind == CacheKind.video;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachePreview old) {
    super.didUpdateWidget(old);
    if (old.entry.file.path != widget.entry.file.path) {
      _reset();
      _load();
    }
  }

  void _load() {
    if (_isVideo) {
      _loadFrames();
    } else {
      _decode();
    }
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _playing = false;
    _frameIdx = 0;
    _decodeFailed = false;
    _preview?.dispose();
    _preview = null;
    _disposeFrames();
  }

  // ── image / danmaku still ────────────────────────────────────────────────
  Future<void> _decode() async {
    final img = await loadCacheThumb(widget.entry);
    if (!mounted) {
      img?.dispose();
      return;
    }
    setState(() {
      _preview?.dispose();
      _preview = img;
    });
  }

  // ── video: decode the cached CVID/AVI to frames, then auto-play the loop ───
  Future<void> _loadFrames() async {
    try {
      final clip = await _converter.decodeCachedVideo(widget.entry.file.path);
      final imgs = <ui.Image>[];
      for (final png in clip.frames) {
        imgs.add(await _decodePng(png));
      }
      if (!mounted) {
        for (final im in imgs) {
          im.dispose();
        }
        return;
      }
      setState(() {
        _disposeFrames();
        _frames = imgs;
        _frameIdx = 0;
        _intervalMs = clip.intervalMs;
        _decodeFailed = false;
      });
      _startPlay(); // "预览播放" — loop as soon as it's loaded
    } catch (_) {
      if (!mounted) return;
      setState(() => _decodeFailed = true);
    }
  }

  Future<ui.Image> _decodePng(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _startPlay() {
    final frames = _frames;
    if (frames == null || frames.length < 2) return; // single frame → static
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _intervalMs), (_) {
      if (!mounted) return;
      setState(() => _frameIdx = (_frameIdx + 1) % frames.length);
    });
    setState(() => _playing = true);
  }

  void _pausePlay() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  void _togglePlay() {
    if (_playing) {
      _pausePlay();
    } else {
      _startPlay();
    }
  }

  // Stop = pause and rewind to the first frame (the still cover), mirroring the
  // video page's stop button.
  void _onStop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _playing = false;
        _frameIdx = 0;
      });
    }
  }

  void _disposeFrames() {
    final frames = _frames;
    if (frames != null) {
      for (final im in frames) {
        im.dispose();
      }
    }
    _frames = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _preview?.dispose();
    _disposeFrames();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _preview_(theme, cs);
  }

  Widget _preview_(ThemeData theme, ColorScheme cs) {
    final e = widget.entry;
    final double maxH =
        widget.maxHeight ?? MediaQuery.of(context).size.height * 0.34;
    if (e.kind == CacheKind.video) {
      return _videoPreview(theme, cs, maxH);
    }
    return Container(
      height: maxH,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: _preview == null
          ? const SizedBox(
              width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
          : (e.kind == CacheKind.image
              // Image caches are square and represent the round screen.
              ? ClipOval(
                  child: SizedBox(
                    width: maxH - 24,
                    height: maxH - 24,
                    child: RawImage(image: _preview, fit: BoxFit.cover),
                  ),
                )
              // Danmaku is a wide strip — contain-fit the whole thing.
              : FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _preview!.width.toDouble(),
                    height: _preview!.height.toDouble(),
                    child: RawImage(image: _preview, fit: BoxFit.fill),
                  ),
                )),
    );
  }

  // 缓存视频是 Cinepak(CVID)编码,平台播放器无法解码,因此 [_loadFrames] 用
  // 自带的 CinepakDecoder 把它解成若干帧,在这里以圆屏内自动循环的方式"播放预览"。
  // 解码中显示进度圈;解码失败回退为图标(此时仍可重新发送,只是无法预览)。
  Widget _videoPreview(ThemeData theme, ColorScheme cs, double maxH) {
    final double side = maxH - 24;
    Widget content;
    if (_decodeFailed) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_outlined, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('视频缓存 · 无法预览',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      );
    } else if (_frames == null) {
      content = const SizedBox(
        width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      final frames = _frames!;
      final img = frames[_frameIdx % frames.length];
      content = Stack(
        alignment: Alignment.center,
        children: [
          // 帧本身是方形 → 对应圆屏(与图片预览一致)。
          ClipOval(
            child: SizedBox(
              width: side,
              height: side,
              child: RawImage(image: img, fit: BoxFit.cover),
            ),
          ),
          // 循环帧即"预览播放";单帧视频不显示控制按钮。播放/暂停 + 停止,
          // 与视频转换页的预览控制一致。
          if (frames.length >= 2)
            Positioned(
              right: 4,
              bottom: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _togglePlay,
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      iconSize: 22,
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      visualDensity: VisualDensity.compact,
                      tooltip: _playing ? '暂停' : '播放',
                    ),
                    IconButton(
                      onPressed: (_playing || _frameIdx != 0) ? _onStop : null,
                      icon: const Icon(Icons.stop),
                      iconSize: 22,
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      visualDensity: VisualDensity.compact,
                      tooltip: '停止',
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Container(
      height: maxH,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: content,
    );
  }
}
