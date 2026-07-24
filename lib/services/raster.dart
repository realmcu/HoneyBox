// raster.dart
//
// The `dart:ui` half of resource conversion: decode + crop/resize a picked
// image to RGBA, and render danmaku text to RGBA. Kept separate from
// image_bin.dart (which is pure dart:typed_data) so the byte-level encoder
// stays testable. Ports the Canvas paths of the miniprogram's
// `utils/image-bin.js` (decodeAndResize/coverCrop) and `utils/text-bin.js`
// (renderDanmaku). Output RGBA feeds buildImageBin().

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_bin.dart';

/// Decoded pixels: [rgba] is width*height*4 bytes (R,G,B,A).
class RgbaImage {
  final Uint8List rgba;
  final int width;
  final int height;
  const RgbaImage(this.rgba, this.width, this.height);
}

/// Interactive crop box, normalized (0..1) relative to the source image.
class CropRect {
  final double nx;
  final double ny;
  final double nw;
  final double nh;
  const CropRect(this.nx, this.ny, this.nw, this.nh);
}

/// Decode encoded image bytes (PNG/JPEG/etc.) into a ui.Image.
Future<ui.Image> decodeUiImage(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

/// Wrap already-decoded RGBA8888 pixels ([RgbaImage]) back into a ui.Image, e.g.
/// to hand a page's freshly-rendered frame to [generateThumbnailArgb8565Bin]
/// (which draws through a Canvas and so needs a ui.Image). Callers own the
/// returned image and must dispose it.
Future<ui.Image> imageFromRgba(RgbaImage img) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    img.rgba,
    img.width,
    img.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

// Centered cover-crop rect (keep target aspect ratio, trim overflow — no
// distortion). Mirrors coverCrop() in image-bin.js / video-converter.
_SrcRect _coverCrop(int srcW, int srcH, int dstW, int dstH) {
  final double targetAR = dstW / dstH;
  final double srcAR = srcW / srcH;
  int sw, sh;
  if (srcAR > targetAR) {
    // source wider → fit height, crop width
    sh = srcH;
    sw = (srcH * targetAR).round();
  } else {
    // source taller → fit width, crop height
    sw = srcW;
    sh = (srcW / targetAR).round();
  }
  final int sx = ((srcW - sw) / 2).floor();
  final int sy = ((srcH - sh) / 2).floor();
  return _SrcRect(sx.toDouble(), sy.toDouble(), sw.toDouble(), sh.toDouble());
}

class _SrcRect {
  final double x, y, w, h;
  const _SrcRect(this.x, this.y, this.w, this.h);
}

/// Crop+resize [img] to exactly targetW×targetH, returning RGBA.
///
/// [crop] (user's interactive box, normalized, relative to source) takes
/// precedence; out-of-range values are clamped inside the image. When [crop]
/// is null, [cover]=true does a centered cover-crop, false stretches the whole
/// image. The selected source rect is stretched to fill the target so output
/// is strictly targetW×targetH — matching drawImage(img, sx,sy,sw,sh, 0,0,w,h).
Future<RgbaImage> cropResizeToRgba(
  ui.Image img, {
  required int targetW,
  required int targetH,
  CropRect? crop,
  bool cover = true,
}) async {
  final int iw = img.width;
  final int ih = img.height;
  double sx = 0, sy = 0, sw = iw.toDouble(), sh = ih.toDouble();

  if (crop != null && crop.nw > 0 && crop.nh > 0) {
    sx = (crop.nx * iw).roundToDouble();
    sy = (crop.ny * ih).roundToDouble();
    sw = (crop.nw * iw).roundToDouble();
    sh = (crop.nh * ih).roundToDouble();
    if (sx < 0) sx = 0;
    if (sy < 0) sy = 0;
    if (sw < 1) sw = 1;
    if (sh < 1) sh = 1;
    if (sx + sw > iw) sw = iw - sx;
    if (sy + sh > ih) sh = ih - sy;
  } else if (cover) {
    final _SrcRect c = _coverCrop(iw, ih, targetW, targetH);
    sx = c.x;
    sy = c.y;
    sw = c.w;
    sh = c.h;
  }

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.high
    ..isAntiAlias = true;
  canvas.drawImageRect(
    img,
    ui.Rect.fromLTWH(sx, sy, sw, sh),
    ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
    paint,
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image out = await picture.toImage(targetW, targetH);
  final ByteData? bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  picture.dispose();
  if (bd == null) {
    throw StateError('图片像素读取失败');
  }
  return RgbaImage(bd.buffer.asUint8List(), targetW, targetH);
}

/// Render [img] into an [outSize]×[outSize] [ui.Image] using an affine transform
/// that maps source pixels to output pixels: `output = src * scale + (tx, ty)`.
/// Anything outside the image (letterbox from the pinch-zoom viewport frame) is
/// filled with [bgColor]. The caller owns the returned image and must dispose
/// it. Shared by [renderViewportRgba] (encode path) and the multi-image page's
/// on-screen framed thumbnails, so both frame identically.
Future<ui.Image> renderViewportImage(
  ui.Image img, {
  required int outSize,
  required double scale,
  required double tx,
  required double ty,
  int bgColor = 0xFF000000,
}) async {
  final double s = outSize.toDouble();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, s, s));
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, s, s),
    ui.Paint()..color = ui.Color(bgColor),
  );
  canvas.clipRect(ui.Rect.fromLTWH(0, 0, s, s));
  canvas.translate(tx, ty);
  canvas.scale(scale);
  canvas.drawImage(
    img,
    ui.Offset.zero,
    ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true,
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image out = await picture.toImage(outSize, outSize);
  picture.dispose();
  return out;
}

/// Render [img] into an [outSize]×[outSize] RGBA using the same affine transform
/// as [renderViewportImage]. Used by the image page's viewport crop: the fixed
/// square frame maps to the full output, so whatever is framed becomes the
/// sent image.
Future<RgbaImage> renderViewportRgba(
  ui.Image img, {
  required int outSize,
  required double scale,
  required double tx,
  required double ty,
  int bgColor = 0xFF000000,
}) async {
  final ui.Image out = await renderViewportImage(
    img,
    outSize: outSize,
    scale: scale,
    tx: tx,
    ty: ty,
    bgColor: bgColor,
  );
  final ByteData? bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  if (bd == null) {
    throw StateError('图片像素读取失败');
  }
  return RgbaImage(bd.buffer.asUint8List(), outSize, outSize);
}

// ── Danmaku text rendering (ports renderDanmaku in text-bin.js) ──────────────

/// Line-height factor (relative to font size). 1.1 is the smallest safe value
/// that keeps common CJK/Latin descenders from being clipped.
const double kDanmakuLineHeight = 1.1;
const double kDanmakuPadXRatio = 0.15;
const double kDanmakuPadYRatio = 0.05;

/// Free system font families offered in the UI (map directly to Android
/// system typefaces). key -> family string passed to the text engine.
const Map<String, String> kDanmakuFontFamilies = {
  'sans': 'sans-serif',
  'serif': 'serif',
  'mono': 'monospace',
};

/// Render danmaku text to an auto-sized RGBA bitmap (bg filled, text centered
/// horizontally, each line vertically centered in its band). Faithful port of
/// renderDanmaku(): width = ceil(maxLineWidth)+2*padX, height = lineH*lines
/// +2*padY, lineH = round(fontSize*1.1).
///
/// [color]/[bgColor] are 0xAARRGGBB ints. [fontFamily] is a family string
/// (e.g. 'sans-serif'). [fontSize] is clamped to >=8 and rounded.
Future<RgbaImage> renderDanmakuRgba({
  required String text,
  required double fontSize,
  required bool bold,
  required String fontFamily,
  required int color,
  required int bgColor,
}) async {
  final int fs = fontSize.round() < 8 ? 8 : fontSize.round();
  final int padX = (fs * kDanmakuPadXRatio).round();
  final int padY = (fs * kDanmakuPadYRatio).round();
  final int lineH = (fs * kDanmakuLineHeight).round();

  final String normalized = text.replaceAll('\r\n', '\n');
  final List<String> lines =
      normalized.isNotEmpty ? normalized.split('\n') : <String>[''];

  final ui.TextStyle textStyle = ui.TextStyle(
    color: ui.Color(color),
    fontSize: fs.toDouble(),
    fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
    fontFamily: fontFamily,
    height: kDanmakuLineHeight,
  );
  ui.ParagraphStyle paragraphStyle(ui.TextAlign align) => ui.ParagraphStyle(
        textAlign: align,
        fontSize: fs.toDouble(),
        fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
        fontFamily: fontFamily,
        maxLines: 1,
      );

  // Measure each line at unbounded width; take the widest.
  double maxW = 0;
  final List<ui.Paragraph> measured = <ui.Paragraph>[];
  for (final String ln in lines) {
    final ui.ParagraphBuilder b =
        ui.ParagraphBuilder(paragraphStyle(ui.TextAlign.left))
          ..pushStyle(textStyle)
          ..addText(ln);
    final ui.Paragraph p = b.build();
    p.layout(const ui.ParagraphConstraints(width: 4194304.0));
    measured.add(p);
    if (p.longestLine > maxW) maxW = p.longestLine;
  }

  final int width = (maxW.ceil() + padX * 2) < 1 ? 1 : maxW.ceil() + padX * 2;
  final int height = (lineH * lines.length + padY * 2) < 1
      ? 1
      : lineH * lines.length + padY * 2;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  // Background fill.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = ui.Color(bgColor),
  );
  // Draw each line: horizontally centered, box vertically fills its band.
  for (int i = 0; i < measured.length; i++) {
    final ui.Paragraph p = measured[i];
    final double lineW = p.longestLine;
    final double x = (width - lineW) / 2;
    final double y = (padY + lineH * i).toDouble();
    canvas.drawParagraph(p, ui.Offset(x, y));
  }

  final ui.Picture picture = recorder.endRecording();
  final ui.Image out = await picture.toImage(width, height);
  final ByteData? bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  picture.dispose();
  if (bd == null) {
    throw StateError('图片生成失败');
  }
  return RgbaImage(bd.buffer.asUint8List(), width, height);
}

// ── Circular badge thumbnail (bg + centered content, border + shadow) ────────

/// Default overall thumbnail edge (px). The disc, its border and drop shadow are
/// all inset to fit inside this square; the corners outside the disc stay
/// transparent (ARGB8565 keeps that alpha).
const int kThumbnailSize = 160;

/// How far the content circle is inset from [radius] (the badge's nominal
/// radius), in px. The frame (shadow + halo) hugs the content edge and fills
/// outward to the FIXED outer rim (radius + haloWidth), so no transparent gap
/// shows between content and frame. Smaller = larger content / narrower frame
/// (0 = content reaches [radius]); larger = smaller content / wider frame. The
/// outer circle size stays fixed regardless of this value.
const double _kContentInset = 3.0;

/// Compose a circular "badge" thumbnail into a transparent [size]×[size] RGBA,
/// mirroring the on-screen preview circle (`previewCircle` in
/// preview_frame.dart): the [content] centered, a soft dark drop shadow, and a
/// faint translucent white halo rim around the edge. The interior has no solid
/// backdrop ([bgColor] transparent by default), so only these elements — not a
/// filled square — show, and the badge reads on any device background.
///
/// The drop shadow ([shadowColor]/[shadowBlur]/[shadowOffset]) is the deep
/// outline that keeps the pale edge legible against light content or a light
/// background. The halo ([haloColor], a translucent white [haloWidth] rim) is
/// painted as a disc one [haloWidth] larger than the badge, then covered by the
/// content — so only its rim shows AND the content's anti-aliased edge is backed
/// by the halo, not by transparency (otherwise a dark seam appears between image
/// and edge). ARGB8565 keeps the per-pixel alpha, so shadow, halo and the
/// transparent corners all survive encoding.
///
/// [content] is the resource preview — a decoded image, a video first frame, or
/// a pre-rendered danmaku bitmap (as a [ui.Image]). When [cover] is true it is
/// centre-cropped to fill the disc; when false it is contained (scaled to fit,
/// centered) so e.g. wide danmaku text isn't clipped. The disc is filled with
/// [bgColor] first, so contained/transparent content composites over the
/// background ("含背景，内容在中间").
Future<RgbaImage> renderCircularThumbnailRgba(
  ui.Image content, {
  int size = kThumbnailSize,
  int bgColor = 0x00000000,
  bool cover = true,
  double haloWidth = 0,
  int haloColor = 0x21FFFFFF,
  double shadowBlur = 5.0,
  int shadowColor = 0x66000000,
  ui.Offset shadowOffset = const ui.Offset(0, 2),
}) async {
  final double s = size.toDouble();
  final ui.Offset center = ui.Offset(s / 2, s / 2);
  // Inset the disc so the halo rim and the drop shadow's blur + offset all stay
  // within the square (nothing clipped at the edges).
  final double shadowReach =
      shadowBlur + shadowOffset.dx.abs() + shadowOffset.dy.abs();
  final double margin = shadowReach > haloWidth ? shadowReach : haloWidth;
  final double radius = (s / 2 - margin) < 1 ? 1 : (s / 2 - margin);
  // Content circle radius (the badge itself), inset from [radius]. The frame
  // (shadow + halo) hugs THIS edge and fills outward to the fixed outer rim, so
  // a smaller content leaves no transparent gap between it and the frame.
  final double contentRadius =
      (radius - _kContentInset) >= 1 ? radius - _kContentInset : radius;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, s, s));

  // 1)+2) Frame RING hugging the content. Clip to OUTSIDE the [contentRadius]
  //    circle (the content's edge) so the shadow + halo fill outward from there
  //    to the fixed outer rim — leaving NO transparent gap between the content
  //    and the frame. The content (drawn last) covers the interior; the frame's
  //    inner edge sits exactly on the content edge, while its outer edge stays
  //    put (radius + haloWidth) no matter how large the content is.
  canvas.save();
  canvas.clipPath(ui.Path.combine(
    ui.PathOperation.difference,
    ui.Path()..addRect(ui.Rect.fromLTWH(0, 0, s, s)),
    ui.Path()
      ..addOval(ui.Rect.fromCircle(center: center, radius: contentRadius)),
  ));

  // 1) Drop shadow: a soft blurred dark disc beneath the badge — the ring clip
  //    keeps only its outer (un-occluded) part, the deep outline that lets the
  //    pale edge read against any background (mirrors previewCircle's shadow).
  if (shadowBlur > 0 || shadowOffset != ui.Offset.zero) {
    canvas.drawCircle(
      center + shadowOffset,
      contentRadius,
      ui.Paint()
        ..color = ui.Color(shadowColor)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadowBlur),
    );
  }

  // 2) Faint translucent white halo out to the fixed outer rim (radius +
  //    haloWidth); the clip leaves the band from the content edge
  //    ([contentRadius]) out to that rim — filling the frame and hugging the
  //    content (the canvas analogue of previewCircle's white `spreadRadius`).
  if (haloWidth > 0) {
    canvas.drawCircle(
      center,
      radius + haloWidth,
      ui.Paint()..color = ui.Color(haloColor),
    );
  }
  canvas.restore();

  // 3) Background disc — only for CONTAIN mode (letterboxed / translucent
  //    content needs a backdrop). In COVER mode we deliberately OMIT it so the
  //    inset ring in step 4 stays TRANSPARENT and the (variable) device
  //    background shows through instead of a mismatched disc-colour rim.
  final bool hasDisc = ((bgColor >> 24) & 0xff) != 0;
  if (hasDisc && !cover) {
    canvas.drawCircle(center, radius, ui.Paint()..color = ui.Color(bgColor));
  }

  // 4) Content at [contentRadius] (computed above). COVER: fill the circle with
  //    an ImageShader via drawCircle, so the edge gets a SINGLE clean
  //    anti-aliased pass (RGB stays the image colour). The old
  //    clipPath(oval)+drawImageRect gave a DOUBLE-AA edge wherever the image rect
  //    was tangent to the clip circle — cover scales the short side to the
  //    diameter, so the rect touches the circle at the short-side ends — thinning
  //    those points to a greyer, uneven partial-alpha line. CONTAIN: keep clip +
  //    centred drawImageRect (image fits inside, backed by the disc).
  if (cover) {
    _drawCoverCircle(canvas, content, center, contentRadius);
  } else {
    canvas.save();
    canvas.clipPath(ui.Path()
      ..addOval(ui.Rect.fromCircle(center: center, radius: contentRadius)));
    _drawContentInDisc(canvas, content, center, contentRadius, false);
    canvas.restore();
  }

  final ui.Picture picture = recorder.endRecording();
  final ui.Image out = await picture.toImage(size, size);
  final ByteData? bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  picture.dispose();
  if (bd == null) {
    throw StateError('缩略图生成失败');
  }
  return RgbaImage(bd.buffer.asUint8List(), size, size);
}

// Draw [content] centered within the disc at [center]/[radius]. cover → scale by
// the shorter side so the disc is fully filled (overflow cropped by the caller's
// clip); contain → scale by the longer side so the whole content fits.
void _drawContentInDisc(
  ui.Canvas canvas,
  ui.Image content,
  ui.Offset center,
  double radius,
  bool cover,
) {
  final int iw = content.width;
  final int ih = content.height;
  if (iw <= 0 || ih <= 0) return;
  final double d = radius * 2;
  final double scale =
      cover ? d / (iw < ih ? iw : ih) : d / (iw > ih ? iw : ih);
  final double dw = iw * scale;
  final double dh = ih * scale;
  canvas.drawImageRect(
    content,
    ui.Rect.fromLTWH(0, 0, iw.toDouble(), ih.toDouble()),
    ui.Rect.fromLTWH(center.dx - dw / 2, center.dy - dh / 2, dw, dh),
    ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true,
  );
}

// Fill a [radius] circle at [center] with [content] scaled COVER (short side ==
// diameter; the overflow of the long side falls outside the circle) using an
// ImageShader. The only anti-aliased edge is drawCircle's own — a single clean
// partial-alpha ramp whose RGB is the image colour — which avoids the double AA
// (and greyer, uneven edge) of a clipPath + drawImageRect whose rect is tangent
// to the clip circle at the short-side ends.
void _drawCoverCircle(
  ui.Canvas canvas,
  ui.Image content,
  ui.Offset center,
  double radius,
) {
  final int iw = content.width;
  final int ih = content.height;
  if (iw <= 0 || ih <= 0) return;
  final double scale = (radius * 2) / (iw < ih ? iw : ih);
  // Column-major 4x4: scale about the origin, then translate so the scaled image
  // is centred on [center]. Maps shader (image-pixel) space → canvas space.
  final Float64List matrix = Float64List.fromList(<double>[
    scale, 0, 0, 0, //
    0, scale, 0, 0, //
    0, 0, 1, 0, //
    center.dx - iw * scale / 2, center.dy - ih * scale / 2, 0, 1, //
  ]);
  canvas.drawCircle(
    center,
    radius,
    ui.Paint()
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.high
      ..shader = ui.ImageShader(
          content, ui.TileMode.clamp, ui.TileMode.clamp, matrix,
          filterQuality: ui.FilterQuality.high),
  );
}

/// Compose a danmaku [strip] onto a square [screenSize]² device-screen image:
/// fill [bgColor] opaque, then draw the strip LEFT-aligned (x = 0) and
/// vertically centered at its native device px — a still of the round screen's
/// scrolling main-face at scroll offset 0 (mirrors the page's 滚动预览, which
/// fills the viewport with the bg and sweeps the v-centered strip across it).
///
/// Feed the result to [generateThumbnailArgb8565Bin] (cover): the badge's
/// content circle is the inscribed circle of this screen, so it shows the
/// strip's LEFT edge over the danmaku background — not a centre-crop of the bare
/// strip. Caller owns the returned image (dispose it); [strip] is not disposed.
Future<ui.Image> composeDanmakuScreenImage(
  ui.Image strip, {
  int screenSize = 360,
  int bgColor = 0xFF000000,
}) async {
  final int side = screenSize < 1 ? 1 : screenSize;
  final double s = side.toDouble();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, s, s));
  canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, s, s), ui.Paint()..color = ui.Color(bgColor));
  final double sw = strip.width.toDouble();
  final double sh = strip.height.toDouble();
  if (sw > 0 && sh > 0) {
    // Vertical centering matches _ScrollPreviewPainter's dy = (screen - stripH)/2;
    // left edge pinned to x = 0. Wide strips overflow right (clipped to the
    // circle later); short strips leave bg to their right — as on the round
    // screen at scroll offset 0.
    final double dy = (s - sh) / 2;
    canvas.drawImageRect(
      strip,
      ui.Rect.fromLTWH(0, 0, sw, sh),
      ui.Rect.fromLTWH(0, dy, sw, sh),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  }
  final ui.Picture picture = recorder.endRecording();
  final ui.Image out = await picture.toImage(side, side);
  picture.dispose();
  return out;
}

/// Full thumbnail generator: render [content] into a circular badge (see
/// [renderCircularThumbnailRgba]) and encode it as an ARGB8565 `.bin`,
/// adaptively choosing the smaller of the raw / RLE encodings. This is the
/// artifact the resource packer appends as its final ("thumbnail") resource.
/// Pass an opaque [bgColor] (the page's preview background) to fill the disc so
/// the badge matches the on-screen preview; leave it transparent for a
/// backdrop-less badge (e.g. danmu, text only). [dither] defaults to true: the
/// badge's soft shadow/halo produce a smooth grey ramp that visibly bands when
/// quantized to RGB565, so Floyd–Steinberg is applied to break up the banding.
Future<Uint8List> generateThumbnailArgb8565Bin(
  ui.Image content, {
  int size = kThumbnailSize,
  int bgColor = 0x00000000,
  bool cover = true,
  bool dither = true,
}) async {
  final RgbaImage badge = await renderCircularThumbnailRgba(
    content,
    size: size,
    bgColor: bgColor,
    cover: cover,
    // previewCircle's look: an opaque [bgColor] disc (behind the content only,
    // to back its edge → no dark seam) + a faint white halo rim + a soft drop
    // shadow. Unlike previewCircle (whose black 0.4 / blur size*0.11 shadow sits
    // over an OPAQUE bg field), our frame is transparent so the changeable
    // header bg shows *through* it — the same shadow then reads as a dark ring.
    // So keep the shadow TIGHT (small blur, hugging the edge) and VERY FAINT
    // (alpha ≈ 0.02), and the white halo light too (≈ 0.04): together they read
    // as a whisper-thin floaty rim, not a visible border, over any background.
    // The frame is enlarged by shrinking the CONTENT (see [_kContentInset]), not
    // by widening/darkening this halo — the outer circle size stays put.
    haloWidth: size * 0.03,
    haloColor: 0x0AFFFFFF,
    shadowBlur: size * 0.045,
    shadowOffset: ui.Offset(0, size * 0.02),
    shadowColor: 0x06000000,
  );
  return buildArgb8565BinAdaptive(badge.rgba, badge.width, badge.height,
          dither: dither)
      .bin;
}
