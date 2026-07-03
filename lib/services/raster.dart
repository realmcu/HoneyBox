// raster.dart
//
// The `dart:ui` half of resource conversion: decode + crop/resize a picked
// image to RGBA, and render danmaku text to RGBA. Kept separate from
// image_bin.dart (which is pure dart:typed_data) so the byte-level encoder
// stays testable. Ports the Canvas paths of the miniprogram's
// `utils/image-bin.js` (decodeAndResize/coverCrop) and `utils/text-bin.js`
// (renderDanmaku). Output RGBA feeds buildImageBin().

import 'dart:typed_data';
import 'dart:ui' as ui;

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
  final ByteData? bd =
      await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  picture.dispose();
  if (bd == null) {
    throw StateError('图片像素读取失败');
  }
  return RgbaImage(bd.buffer.asUint8List(), targetW, targetH);
}

/// Render [img] into an [outSize]×[outSize] RGBA using an affine transform that
/// maps source pixels to output pixels: `output = src * scale + (tx, ty)`.
/// Anything outside the image (letterbox from the pinch-zoom viewport frame) is
/// filled with [bgColor]. Used by the image page's viewport crop: the fixed
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
  final ByteData? bd =
      await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  picture.dispose();
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
  final int height =
      (lineH * lines.length + padY * 2) < 1 ? 1 : lineH * lines.length + padY * 2;

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
  final ByteData? bd =
      await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  picture.dispose();
  if (bd == null) {
    throw StateError('图片生成失败');
  }
  return RgbaImage(bd.buffer.asUint8List(), width, height);
}
