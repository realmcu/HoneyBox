import 'dart:async';
import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/transfer_provider.dart';
import '../../services/converter.dart';
import '../../services/raster.dart';
import '../../services/resource_pack.dart';
import '../../services/l2_file_transfer.dart';
import '../../services/file_cache.dart';
import '../shared/cache_ui.dart';
import '../shared/color_picker_dialog.dart';
import '../shared/example_assets.dart';
import '../shared/file_send_layout.dart';
import '../shared/preview_frame.dart';
import '../shared/thumbnail_export.dart';

/// 多图轮播 — compose up to [_maxSlides] pictures into a looping slideshow video
/// and send it over BLE. Each picture is framed in the same circular pinch-zoom
/// viewport as the image page (whatever is inside the circle is used, letterbox
/// filled with the background color); the pictures are ordered via a draggable
/// thumbnail strip below the preview. On convert, every picture becomes a
/// self-decodable Cinepak key frame held for an equal share of the user's chosen
/// total duration, then muxed to one AVI(CVID) and sent as [TYPE.video]. The
/// composed clip can be previewed (the framed pictures cycle at their real hold
/// durations inside the viewport) before sending.
class SlideshowPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const SlideshowPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<SlideshowPage> createState() => _SlideshowPageState();
}

const int _maxSlides = 5;
const List<int> _sizePresets = [240, 360, 466, 480];

const int _maxFrames = 300; // hard safety cap on total frames
const double _minDurationSec = 1.0;
const double _maxDurationSec = 5.0;

// Cinepak quality presets for the still key frames — same LOW/MED/HIGH model as
// the video page. Photos benefit from codebook fidelity, so the default is HIGH.
const List<(String, int)> _qualityPresets = [
  ('LOW', 15),
  ('MED', 60),
  ('HIGH', 95)
];

// Resolution of the cached framed snapshots used for the thumbnail strip and
// the motion preview. Independent of the chosen output [_size] (framing is the
// same at any resolution), so changing size never re-renders these.
const int _previewRes = 360;

const double _previewMaxHRatio =
    0.5; // circular viewport max height = 50% screen

// Letterbox / out-of-frame fill colors (shared with the image/video pages).
const List<int> _bgColors = [
  0xFF000000,
  0xFFFFFFFF,
  0xFFFF3B30,
  0xFF34C759,
  0xFF007AFF,
  0xFFFFCC00,
];

enum _ConvStatus { idle, converting, ready, error }

enum _PlayState { stopped, playing, paused }

/// One picture in the carousel: its decoded source, an independent pinch-zoom
/// transform, and a cached framed snapshot (at [_previewRes]) for the strip and
/// the motion preview.
class _Slide {
  final int id;
  final String name;
  final ui.Image src;
  final int srcW;
  final int srcH;
  final TransformationController tc = TransformationController();
  ui.Image? framed;

  _Slide({
    required this.id,
    required this.name,
    required this.src,
    required this.srcW,
    required this.srcH,
  });

  void dispose() {
    tc.dispose();
    src.dispose();
    framed?.dispose();
  }
}

class _SlideshowPageState extends ConsumerState<SlideshowPage> {
  final _picker = ImagePicker();
  final _converter = ConverterService();

  // Captured while mounted so dispose() never touches `ref` (see initState).
  late final TransferProgressNotifier _transfer;

  final List<_Slide> _slides = [];
  int _nextId = 0;
  int _editingIndex = 0;

  // Options.
  int _size = 360;
  int _quality =
      95; // HIGH — photos favor fidelity; lower it to shrink the file
  int _bgColor = 0xFF000000;
  // Preview-only: fills the square corners outside the circle, extracted from
  // the FIRST slide via Palette. Never affects the converted resource.
  Color? _previewBg;
  int? _previewBgSlideId; // slide id _previewBg was extracted from (de-dup)
  // Debounces the (background) preview-color extraction so it runs only after
  // the user stops pinch-zooming / panning, not on every interaction-end.
  final _bgDebounce = Debouncer(const Duration(milliseconds: 350));
  double _durationSec = 3.0;

  // Framing viewport geometry (shared by every slide; each slide keeps its own
  // transform in [_Slide.tc]).
  double _vp = 0;
  int _viewportPointers = 0; // >0 → freeze page scroll while framing

  // Conversion result / state.
  Uint8List? _avi;
  int _binSize = 0;
  int _frameCount = 0;
  double _convProgress = 0;
  _ConvStatus _conv = _ConvStatus.idle;
  String? _convError;
  int _rebuildSeq = 0;
  // Guards the async thumbnail/package build in _send against re-entrant taps.
  bool _packaging = false;

  // Cache mode: when a cached carousel is loaded, the composer UI is replaced by
  // a read-only panel and the send button re-sends the cached bytes as-is.
  // Carousels are written into the shared 视频 pool tagged src=slideshow; the
  // picker filters to those, so regular videos/GIFs (from the video page) don't
  // show here and carousels don't show there.
  CacheEntry? _cacheEntry;
  Uint8List? _cacheBytes;
  bool get _cacheMode => _cacheEntry != null;

  // Motion preview: cycles the framed snapshots at their real hold durations.
  _PlayState _play = _PlayState.stopped;
  int _previewIdx = 0;
  Timer? _previewTimer;

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
    _rebuildSeq++;
    _converter.cancel();
    _previewTimer?.cancel();
    for (final s in _slides) {
      s.dispose();
    }
    _bgDebounce.dispose();
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

  // ── Pick images ─────────────────────────────────────────────────────────
  Future<void> _addImages() async {
    if (_isBusy) return;
    final remaining = _maxSlides - _slides.length;
    if (remaining <= 0) {
      _snack('最多选择 $_maxSlides 张图片');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;
      _stopPlayback();
      int added = 0;
      for (final x in picked) {
        if (added >= remaining) break;
        if (x.name.toLowerCase().endsWith('.gif')) continue; // → 视频/GIF 功能
        final bytes = await File(x.path).readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) continue; // skip oversized
        final img = await decodeUiImage(bytes);
        _slides.add(_Slide(
          id: _nextId++,
          name: x.name,
          src: img,
          srcW: img.width,
          srcH: img.height,
        ));
        added++;
      }
      if (!mounted) return;
      if (added == 0) {
        _snack('未添加图片（GIF 请用 视频/GIF 功能，或图片过大）');
        return;
      }
      ref.read(transferProgressProvider.notifier).reset();
      setState(() => _editingIndex = _slides.length - 1);
      for (int i = _slides.length - added; i < _slides.length; i++) {
        _renderSlide(i);
      }
      _invalidate();
      _refreshPreviewBg();
      if (picked.length > remaining) {
        _snack('已达上限，仅添加前 $remaining 张');
      }
    } catch (e) {
      _snack('选择图片失败: $e');
    }
  }

  // Append one bundled example image as a new slide (single add, honors the
  // _maxSlides cap). Loaded via rootBundle → decode, same pipeline as _addImages.
  Future<void> _addExampleImage(String assetPath) async {
    if (_isBusy) return;
    if (_slides.length >= _maxSlides) {
      _snack('最多选择 $_maxSlides 张图片');
      return;
    }
    try {
      final data = await rootBundle.load(assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final img = await decodeUiImage(bytes);
      if (!mounted) {
        img.dispose();
        return;
      }
      _stopPlayback();
      _slides.add(_Slide(
        id: _nextId++,
        name: assetPath.split('/').last,
        src: img,
        srcW: img.width,
        srcH: img.height,
      ));
      ref.read(transferProgressProvider.notifier).reset();
      setState(() => _editingIndex = _slides.length - 1);
      _renderSlide(_slides.length - 1);
      _invalidate();
      _refreshPreviewBg();
    } catch (e) {
      _snack('加载示例失败: $e');
    }
  }

  void _removeSlide(int i) {
    if (_isBusy || i < 0 || i >= _slides.length) return;
    _stopPlayback();
    final s = _slides[i];
    setState(() {
      _slides.removeAt(i);
      if (_slides.isEmpty) {
        _editingIndex = 0;
      } else if (_editingIndex >= _slides.length) {
        _editingIndex = _slides.length - 1;
      } else if (i < _editingIndex) {
        _editingIndex -= 1;
      }
    });
    s.dispose();
    _invalidate();
    _refreshPreviewBg();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_isBusy) return;
    _stopPlayback();
    setState(() {
      // newIndex is already adjusted for the removed item (onReorderItem).
      final s = _slides.removeAt(oldIndex);
      _slides.insert(newIndex, s);
      // Keep editing whichever slide the user was on.
      if (_editingIndex == oldIndex) {
        _editingIndex = newIndex;
      } else if (oldIndex < _editingIndex && newIndex >= _editingIndex) {
        _editingIndex -= 1;
      } else if (oldIndex > _editingIndex && newIndex <= _editingIndex) {
        _editingIndex += 1;
      }
    });
    _invalidate();
    _refreshPreviewBg();
  }

  void _selectSlide(int i) {
    if (_play != _PlayState.stopped || i == _editingIndex) return;
    setState(() => _editingIndex = i);
  }

  // ── Framed-snapshot rendering ─────────────────────────────────────────────
  // Source→output affine map for slide [s] at [outSize], derived from its
  // pinch-zoom transform. Mirrors the image page's viewport crop math: the
  // fixed square frame maps to the full output.
  (double, double, double) _viewportMap(_Slide s, int outSize) {
    final double v = _vp;
    final double s0 = min(v / s.srcW, v / s.srcH); // contain scale in v×v box
    final double lx = (v - s.srcW * s0) / 2;
    final double ly = (v - s.srcH * s0) / 2;
    final m = s.tc.value;
    final double k = m.getMaxScaleOnAxis();
    final double mtx = m.storage[12];
    final double mty = m.storage[13];
    final double f = outSize / v; // viewport px → output px
    return (k * s0 * f, (k * lx + mtx) * f, (k * ly + mty) * f);
  }

  // Re-render slide [i]'s framed snapshot (strip tile + motion preview). Retries
  // once the viewport size is known.
  Future<void> _renderSlide(int i) async {
    if (_vp <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _renderSlide(i);
      });
      return;
    }
    if (i < 0 || i >= _slides.length) return;
    final s = _slides[i];
    final (scale, tx, ty) = _viewportMap(s, _previewRes);
    try {
      final img = await renderViewportImage(
        s.src,
        outSize: _previewRes,
        scale: scale,
        tx: tx,
        ty: ty,
        bgColor: _bgColor,
      );
      if (!mounted || i >= _slides.length || !identical(_slides[i], s)) {
        img.dispose();
        return;
      }
      setState(() {
        s.framed?.dispose();
        s.framed = img;
      });
    } catch (_) {
      // A failed thumbnail just leaves the placeholder — non-fatal.
    }
  }

  Future<void> _renderAllSlides() async {
    for (int i = 0; i < _slides.length; i++) {
      await _renderSlide(i);
    }
  }

  // ── Options ────────────────────────────────────────────────────────────────
  void _onSizeTap(int s) {
    if (_isBusy || s == _size) return;
    setState(() => _size = s); // framing unchanged → no snapshot re-render
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
    _renderAllSlides(); // background is baked into the snapshots
    _invalidate();
  }

  void _onDurationChanged(double v) {
    if (_isBusy) return;
    setState(() => _durationSec = v);
    _invalidate();
  }

  void _onResetView() {
    if (_isBusy || _slides.isEmpty) return;
    _slides[_editingIndex].tc.value = Matrix4.identity();
    _renderSlide(_editingIndex);
    _invalidate();
  }

  // Slideshow frame rate. The pictures are stills, and every hold repeat is an
  // idempotent no-op inter frame in Cinepak (see native encodeFrames), so the
  // repeats are near-free in the file. A higher, fixed rate therefore costs
  // almost nothing yet lets an equal per-picture frame count land the chosen
  // duration precisely — 10 fps gives 0.1 s timing granularity.
  int get _slideFps => 10;

  // Per-image displayed-frame count. Every picture is held for the SAME number
  // of frames k, so the key frames are evenly spaced and the loop's wrap-around
  // (last picture → first) is just another evenly-timed cut — no short or long
  // picture at the seam. k is derived from the chosen duration (rounded, ≥ 1)
  // and the real total is k·n frames, capped at [_maxFrames]. Rounding to whole
  // frames means the clip's true length can differ slightly from the slider;
  // see [_actualDurationSec].
  List<int> _currentHolds() {
    final n = _slides.length;
    if (n == 0) return const [];
    int k = (_durationSec * _slideFps / n).round();
    if (k < 1) k = 1;
    if (k * n > _maxFrames) k = _maxFrames ~/ n;
    if (k < 1) k = 1;
    return List<int>.filled(n, k);
  }

  // The clip's real duration once every picture is rounded to k equal frames
  // (k·n / fps seconds). Shown to the user instead of the raw slider value.
  double get _actualDurationSec {
    final holds = _currentHolds();
    if (holds.isEmpty) return 0;
    final total = holds.fold<int>(0, (s, h) => s + h);
    return total / _slideFps;
  }

  // ── Convert ─────────────────────────────────────────────────────────────────
  Future<void> _convert() async {
    if (_slides.isEmpty || _isBusy) return;
    if (_vp <= 0) {
      _snack('预览未就绪，请稍候重试');
      return;
    }
    _stopPlayback();
    final int token = ++_rebuildSeq;
    final holds = _currentHolds();
    setState(() {
      _conv = _ConvStatus.converting;
      _convProgress = 0;
      _binSize = 0;
      _frameCount = 0;
      _convError = null;
      _avi = null;
    });
    try {
      // Render each slide to output-resolution RGBA (framing + background baked
      // in) for the native Cinepak encoder. Cinepak codes 4×4 macroblocks, so
      // the output must be a multiple of 4. Frames are pre-rendered here, so we
      // round the chosen size *up* (e.g. 466 → 468) before rendering — native
      // can't resize an already-baked frame. Mapping is linear in outSize, so
      // the framing is unchanged.
      final int encodeSize = (_size + 3) & ~3;
      final frames = <Uint8List>[];
      for (final s in _slides) {
        final (scale, tx, ty) = _viewportMap(s, encodeSize);
        final img = await renderViewportRgba(
          s.src,
          outSize: encodeSize,
          scale: scale,
          tx: tx,
          ty: ty,
          bgColor: _bgColor,
        );
        if (token != _rebuildSeq || !mounted) return;
        frames.add(img.rgba);
      }
      final res = await _converter.encodeSlideshow(
        frames: frames,
        holds: holds,
        size: encodeSize,
        fps: _slideFps,
        quality: _quality,
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
        _convError = e.message ?? '合成失败';
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

  // Any edit drops a converted result back to "needs convert" (send is gated on
  // a fresh AVI, so we never ship a stale composition).
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

  // Refresh the preview's outside-circle fill from the FIRST slide (Palette).
  // Skips when the first slide is unchanged; clears when there are no slides.
  // Preview-only — does not touch _bgColor or the conversion pipeline.
  Future<void> _refreshPreviewBg({bool force = false}) async {
    // Never compute while a finger is on the preview (pan/scale in progress);
    // it resumes after the gesture ends via the debounced onInteractionEnd.
    if (_viewportPointers > 0) return;
    if (_slides.isEmpty) {
      _previewBgSlideId = null;
      if (mounted && _previewBg != null) setState(() => _previewBg = null);
      return;
    }
    final first = _slides.first;
    // Same first image and framing unchanged → keep the current color. [force]
    // is set when the first slide was reframed (its pixels-in-view changed).
    if (!force && first.id == _previewBgSlideId) return;
    _previewBgSlideId = first.id;
    final region =
        framedSourceRect(_vp, first.srcW, first.srcH, first.tc.value);
    final color = await extractPreviewBg(first.src, region: region);
    if (!mounted) return;
    // The first slide may have changed again while awaiting.
    if (_slides.isEmpty || _slides.first.id != first.id) return;
    setState(() => _previewBg = color);
  }

  // ── Send ─────────────────────────────────────────────────────────────────
  // Wrap the composed AVI + a thumbnail into a resource package: resource[0] is
  // the carousel AVI(CVID), resource[1] a 160 circular ARGB8565 thumbnail of the
  // first slide's framed picture. The device reads the kind from the package
  // header's type (ResourceType.video); TYPE.video stays as the transport tag.
  Future<void> _send() async {
    final avi = _avi;
    if (avi == null ||
        _conv != _ConvStatus.ready ||
        _sending ||
        _packaging ||
        _slides.isEmpty) {
      return;
    }
    // First slide's framed picture (page-owned — do NOT dispose); fall back to
    // its raw source if it hasn't been framed yet.
    final ui.Image content = _slides.first.framed ?? _slides.first.src;
    _packaging = true;
    try {
      final Uint8List thumb = await generateThumbnailArgb8565Bin(content);
      if (!mounted) return;
      // Header bg = the colour that fills the preview area outside the circle
      // (extracted from the first slide); fall back to the chosen background.
      final int bgArgb = _previewBg?.toARGB32() ?? _bgColor;
      final Uint8List pkg = buildResourcePack(
        type: ResourceType.video,
        bgColor: bgArgb,
        resources: [avi],
        thumbnail: thumb,
      );
      ref.read(transferProgressProvider.notifier).send(
            TYPE.video,
            pkg,
            'carousel.avi',
            cache: CacheSpec(CacheKind.video, {
              'src': 'slideshow', // tag so the picker can show only carousels
              'size': '$_size',
              'frames': '$_frameCount',
              'slides': '${_slides.length}',
            }),
          );
    } catch (e) {
      _snack('打包失败: $e');
    } finally {
      _packaging = false;
    }
  }

  // ── Export thumbnail ─────────────────────────────────────────────────────
  // Save the first-slide badge (the converted circular ARGB8565 thumbnail,
  // resource[1]) to a user-picked file — byte-for-byte what _send packages.
  // Filename carries the header/bg colour as a hex suffix; base is "carousel".
  Future<void> _exportThumbnail() async {
    if (_isBusy || _packaging || _slides.isEmpty) return;
    final ui.Image content = _slides.first.framed ?? _slides.first.src;
    _packaging = true; // reuse the re-entrancy guard
    try {
      final Uint8List thumb = await generateThumbnailArgb8565Bin(content);
      if (!mounted) return;
      final int bgArgb = _previewBg?.toARGB32() ?? _bgColor;
      await exportThumbnailBin(
        context,
        bin: thumb,
        sourceName: 'carousel',
        bgColor: bgArgb,
      );
    } catch (e) {
      _snack('导出失败: $e');
    } finally {
      _packaging = false;
    }
  }

  // ── Cache load / send ────────────────────────────────────────────────────
  Future<void> _loadCache() async {
    if (_isBusy) return;
    // Only carousels made on this page (src=slideshow); labeled 轮播 in the sheet.
    final entry = await showCachePicker(
      context,
      CacheKind.video,
      where: (e) => e.params['src'] == 'slideshow',
      label: '轮播',
    );
    if (entry == null || !mounted) return;
    try {
      final bytes = await entry.file.readAsBytes();
      if (!mounted) return;
      _stopPlayback(); // halt the motion preview before swapping to the panel
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

  // Re-send the loaded cache bytes unchanged; no cache: arg so it isn't re-cached.
  // The cache holds the whole resource package (or a legacy bare AVI); either way
  // resend it verbatim — no trailing byte, no repackaging.
  void _sendCache() {
    final bytes = _cacheBytes;
    final entry = _cacheEntry;
    if (bytes == null || entry == null || _sending) return;
    ref.read(transferProgressProvider.notifier).send(
          entry.kind.fileType,
          bytes,
          entry.kind.deviceName,
        );
  }

  // ── Motion preview ──────────────────────────────────────────────────────────
  void _onPlayPause() {
    if (_isBusy || _slides.isEmpty) return;
    if (_play == _PlayState.playing) {
      _previewTimer?.cancel();
      setState(() => _play = _PlayState.paused);
      return;
    }
    if (_play == _PlayState.stopped) _previewIdx = 0;
    setState(() => _play = _PlayState.playing);
    _scheduleNext();
  }

  void _scheduleNext() {
    _previewTimer?.cancel();
    if (_slides.isEmpty) return;
    final holds = _currentHolds();
    final idx = _previewIdx % _slides.length;
    final ms = (holds[idx] / _slideFps * 1000).round().clamp(60, 10000);
    _previewTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _previewIdx = (_previewIdx + 1) % _slides.length);
      _scheduleNext();
    });
  }

  void _onStop() {
    _previewTimer?.cancel();
    _previewTimer = null;
    setState(() {
      _play = _PlayState.stopped;
      _previewIdx = 0;
    });
  }

  // Halt playback without a setState (callers wrap their own / are disposing).
  void _stopPlayback() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _play = _PlayState.stopped;
    _previewIdx = 0;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferProgressProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sending = transferState.status == TransferStatus.sending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('多图轮播'),
        actions: [
          if (_slides.isNotEmpty && !_cacheMode) ...[
            IconButton(
              onPressed: (_isBusy || _packaging) ? null : _exportThumbnail,
              icon: const Icon(Icons.save_alt),
              tooltip: '导出缩略图',
            ),
            IconButton(
              onPressed:
                  (_isBusy || _slides.length >= _maxSlides) ? null : _addImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: '添加图片',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                        if (_slides.isEmpty) ...[
                          _buildPickHint(theme, cs),
                          const SizedBox(height: 12),
                          _buildExamples(theme, cs),
                        ] else ...[
                          _buildPreview(theme, cs),
                          const SizedBox(height: 8),
                          _buildViewControls(theme, cs),
                          const SizedBox(height: 12),
                          _buildStrip(theme, cs),
                          const SizedBox(height: 10),
                          _buildExamples(theme, cs),
                          const SizedBox(height: 16),
                          _buildSizeSelector(theme, cs),
                          const SizedBox(height: 8),
                          _buildQualitySelector(theme, cs),
                          const SizedBox(height: 8),
                          _buildBgColorRow(theme, cs),
                          const SizedBox(height: 8),
                          _buildDurationRow(theme, cs),
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

  Widget _buildPickHint(ThemeData theme, ColorScheme cs) {
    return GestureDetector(
      onTap: _addImages,
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
            Icon(Icons.burst_mode_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('点击选择图片（最多 $_maxSlides 张）',
                style: theme.textTheme.bodyLarge?.copyWith(color: cs.outline)),
          ],
        ),
      ),
    );
  }

  // A row of round example thumbnails; tapping one appends it to the selected
  // slides (up to _maxSlides). Disabled while busy or once the cap is reached.
  Widget _buildExamples(ThemeData theme, ColorScheme cs) {
    final full = _slides.length >= _maxSlides;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('示例', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ExampleStrip(
          count: ExampleAssets.images.length,
          enabled: !_isBusy && !full,
          thumbBuilder: (i) => Image.asset(
            ExampleAssets.images[i],
            fit: BoxFit.cover,
            cacheWidth: 120,
          ),
          onTap: (i) => _addExampleImage(ExampleAssets.images[i]),
        ),
      ],
    );
  }

  // Circular framing viewport for the current slide, with a play/pause/stop
  // overlay that previews the composed slideshow (framed pictures cycle at their
  // real hold durations).
  Widget _buildPreview(ThemeData theme, ColorScheme cs) {
    final double maxH = MediaQuery.of(context).size.height * _previewMaxHRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double v = min(constraints.maxWidth, maxH);
        final double d = v - 2 * kPreviewMargin; // circle floats with a margin
        _vp = d;
        return Center(
          child: SizedBox(
            width: v,
            height: v,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _play == _PlayState.stopped
                      ? _buildEditingContent(cs, d)
                      : _buildPlayingContent(cs, d),
                ),
                Positioned(
                  right: kPreviewMargin,
                  bottom: kPreviewMargin,
                  child: _buildPlayControls(cs),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditingContent(ColorScheme cs, double v) {
    final slide = _slides[_editingIndex];
    return Listener(
      onPointerDown: (_) {
        // A new touch starts: drop any pending extraction so nothing computes
        // while the finger is down.
        _bgDebounce.cancel();
        setState(() => _viewportPointers++);
      },
      onPointerUp: (_) => setState(
          () => _viewportPointers = (_viewportPointers - 1).clamp(0, 99)),
      onPointerCancel: (_) => setState(
          () => _viewportPointers = (_viewportPointers - 1).clamp(0, 99)),
      child: previewCircle(
        size: v,
        bg: _previewBg,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(_bgColor))),
            InteractiveViewer(
              key: ValueKey(slide.id),
              transformationController: slide.tc,
              minScale: 1.0,
              maxScale: 8.0,
              clipBehavior: Clip.hardEdge,
              onInteractionEnd: (_) {
                _renderSlide(_editingIndex);
                _invalidate();
                if (_editingIndex == 0) {
                  _bgDebounce.run(() => _refreshPreviewBg(force: true));
                }
              },
              child: SizedBox(
                width: v,
                height: v,
                child: RawImage(image: slide.src, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayingContent(ColorScheme cs, double v) {
    final img = _slides.isNotEmpty
        ? _slides[_previewIdx % _slides.length].framed
        : null;
    return previewCircle(
      size: v,
      bg: _previewBg,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Color(_bgColor))),
          if (img != null)
            Positioned.fill(child: RawImage(image: img, fit: BoxFit.contain)),
        ],
      ),
    );
  }

  Widget _buildPlayControls(ColorScheme cs) {
    final bool canPlay = !_isBusy && _slides.isNotEmpty;
    final bool isPlaying = _play == _PlayState.playing;
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canPlay ? _onPlayPause : null,
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 22,
            color: Colors.white,
            disabledColor: Colors.white38,
            visualDensity: VisualDensity.compact,
            tooltip: isPlaying ? '暂停' : '预览',
          ),
          IconButton(
            onPressed: canPlay && _play != _PlayState.stopped ? _onStop : null,
            icon: const Icon(Icons.stop),
            iconSize: 22,
            color: Colors.white,
            disabledColor: Colors.white38,
            visualDensity: VisualDensity.compact,
            tooltip: '停止',
          ),
        ],
      ),
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
          onPressed: _isBusy ? null : _onResetView,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重置'),
        ),
      ],
    );
  }

  // Ordered thumbnail strip: tap to edit, long-press to drag-reorder, × to
  // remove; a trailing tile adds more (up to the limit).
  Widget _buildStrip(ThemeData theme, ColorScheme cs) {
    return SizedBox(
      height: 92,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: true,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _slides.length,
        onReorderItem: _onReorder,
        footer: _slides.length < _maxSlides ? _buildAddTile(cs) : null,
        itemBuilder: (ctx, i) => _buildSlideTile(ctx, cs, i),
      ),
    );
  }

  Widget _buildSlideTile(BuildContext ctx, ColorScheme cs, int i) {
    final s = _slides[i];
    final selected = i == _editingIndex && _play == _PlayState.stopped;
    return Padding(
      key: ValueKey(s.id),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: GestureDetector(
        onTap: () => _selectSlide(i),
        child: SizedBox(
          width: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Color(_bgColor),
                  shape: BoxShape.circle,
                ),
                // 边框画在图片之上（foregroundDecoration），避免挤占内边距
                // 露出底色形成黑边——与示例行的圆形缩略图保持一致。
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: s.framed != null
                    ? RawImage(image: s.framed, fit: BoxFit.cover)
                    : const Center(
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
              ),
              // 序号放圆形底部居中，避免旧的左下角位置露到圆外。
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              Positioned(
                right: -8,
                top: -8,
                child: IconButton(
                  onPressed: _isBusy ? null : () => _removeSlide(i),
                  icon: const Icon(Icons.cancel),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  color: cs.error,
                  tooltip: '移除',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTile(ColorScheme cs) {
    return Padding(
      key: const ValueKey('__add__'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: GestureDetector(
        onTap: _isBusy ? null : _addImages,
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.outline),
          ),
          child: Icon(Icons.add, color: cs.outline, size: 28),
        ),
      ),
    );
  }

  Widget _buildSizeSelector(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        SizedBox(
            width: 40, child: Text('尺寸', style: theme.textTheme.titleSmall)),
        const SizedBox(width: 8),
        ..._sizePresets.map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PresetChip(
                label: '$s',
                selected: _size == s,
                onTap: _isBusy ? null : () => _onSizeTap(s),
              ),
            )),
      ],
    );
  }

  Widget _buildQualitySelector(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        SizedBox(
            width: 40, child: Text('质量', style: theme.textTheme.titleSmall)),
        const SizedBox(width: 8),
        ..._qualityPresets.map((q) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PresetChip(
                label: q.$1,
                selected: _quality == q.$2,
                onTap: _isBusy ? null : () => _onQualityTap(q.$2),
              ),
            )),
      ],
    );
  }

  Widget _buildBgColorRow(ThemeData theme, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SizedBox(
              width: 40, child: Text('背景', style: theme.textTheme.titleSmall)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ColorSwatchStrip(
            presets: _bgColors,
            selected: _bgColor,
            onChanged: _onBgTap,
            enabled: !_isBusy,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationRow(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        SizedBox(
            width: 40, child: Text('时长', style: theme.textTheme.titleSmall)),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: _durationSec.clamp(_minDurationSec, _maxDurationSec),
            min: _minDurationSec,
            max: _maxDurationSec,
            divisions: ((_maxDurationSec - _minDurationSec) / 0.5).round(),
            label: '${_durationSec.toStringAsFixed(1)}s',
            onChanged: _isBusy ? null : _onDurationChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text('${_durationSec.toStringAsFixed(1)}s',
              textAlign: TextAlign.right, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildConvInfo(ThemeData theme, ColorScheme cs) {
    String right;
    if (_conv == _ConvStatus.converting) {
      final pct = (_convProgress * 100).toInt();
      right = '合成中 $pct% · $_frameCount 帧';
    } else if (_conv == _ConvStatus.ready) {
      right = '$_size×$_size · $_frameCount 帧 · ${formatFileSize(_binSize)}';
    } else {
      right = '待合成';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
            '${_slides.length} 张 · 约 ${_actualDurationSec.toStringAsFixed(1)}s',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        Flexible(
          child: Text(right,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

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

  Widget _buildStatus(ThemeData theme, ColorScheme cs, TransferState state) {
    if (_conv == _ConvStatus.error) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 20, color: cs.error),
          const SizedBox(width: 6),
          Flexible(
            child: Text(_convError ?? '合成失败',
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
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.error, fontWeight: FontWeight.w600)),
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
            label: const Text('取消合成'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
        ],
      );
    }
    // Cache mode: re-send the loaded cache bytes as-is.
    if (_cacheMode) {
      return _withLoadButton(FilledButton.icon(
        onPressed: _cacheBytes != null ? _sendCache : null,
        icon: const Icon(Icons.send),
        label: const Text('发送缓存'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ));
    }
    if (_conv == _ConvStatus.ready) {
      return _withLoadButton(FilledButton.icon(
        onPressed: _send,
        icon: const Icon(Icons.send),
        label: const Text('发送到设备'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ));
    }
    // idle or error → convert.
    return _withLoadButton(FilledButton.icon(
      onPressed: _slides.isNotEmpty ? _convert : null,
      icon: const Icon(Icons.movie_filter_outlined),
      label: const Text('合成转换'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ));
  }

  // Circular "load cache" button sits to the left of the primary action.
  Widget _withLoadButton(Widget primary) {
    return Row(
      children: [
        CacheLoadButton(onPressed: _loadCache),
        const SizedBox(width: 12),
        Expanded(child: primary),
      ],
    );
  }
}
