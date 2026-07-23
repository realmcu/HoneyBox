// image_bin.dart
//
// Converts decoded RGBA pixels into a HoneyGUI device `.bin` file. This is a
// faithful Dart port of the miniprogram's `utils/image-bin.js` encoding half
// (pixel conversion + RLE + headers). The decode/resize half (which needs a
// canvas) lives in `raster.dart`; this file is pure Dart (dart:typed_data only)
// so it stays testable and off the Flutter dependency.
//
// Output format (RGB565, 2 bytes/px — or ARGB8565, 3 bytes/px with alpha):
//   uncompressed: [gui_rgb_data_head_t 8B] [pixel data: w*h*pixelBytes]
//   RLE:          [gui_rgb_data_head_t 8B] [imdc_file_header_t 12B]
//                 [offset table (h+1)*4] [compressed data]

import 'dart:typed_data';

// ── Pixel format (matches SDK GUI_FormatType) ────────────────────────────────
// Values confirmed against the reference converter (honeygui-design/tools/
// image-converter/types.ts): RGB565 = 0, ARGB8565 = 1, RGB888 = 3, JPEG = 12.
const int _pixelFormatRgb565 = 0;

/// GUI_FormatType for packed ARGB8565 (RGB565 colour + 8-bit alpha, 3 bytes/px),
/// used by the thumbnail encoder. (The planar RTKARGB8565 = 15 is a separate
/// format we do not emit.)
const int _pixelFormatArgb8565 = 1;

// imdc pixel_bytes field. The reference's FORMAT_TO_PIXEL_BYTES maps ARGB8565 →
// BYTES_3 (value 1) and RGB565 → BYTES_2 (value 0) — we mirror that map. (The
// PixelBytes enum's own inline comment grouping ARGB8565 under BYTES_2 is stale;
// converter.ts uses the map, so value 1 is what the device sees.)
const int _pixelBytesRgb565 = 0;
const int _pixelBytesArgb8565 = 1;

// RLE algorithm constants (compress/rle.ts)
const int _compressRle = 0;
const int _rleRunLen1 = 1; // feature_1 (minRun = runLength1 + 1)
const int _rleRunLen2 = 0; // feature_2

/// Default (square) output edge length, matching the miniprogram.
const int kImageDefaultSize = 360;

/// gui_rgb_data_head_t size in bytes — precedes the payload in both encodings.
const int _rgbDataHeaderBytes = 8;

// ── RGB565 conversion ────────────────────────────────────────────────────────
int _rgbToRgb565(int r, int g, int b) {
  return (((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)) & 0xFFFF;
}

/// Pack a 0xAARRGGBB colour into an RGB565 value (0..0xFFFF), e.g. for the
/// resource package's `bg_color` field. Alpha is ignored.
int rgb565FromArgb(int argb) =>
    _rgbToRgb565((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

int _clamp255(num v) {
  final int i = v.round();
  return i < 0 ? 0 : (i > 255 ? 255 : i);
}

/// Floyd–Steinberg error diffusion (before RGB565 quantization). Mirrors
/// image-converter/pixel-converter.ts: error = value - quantized (R/B truncated
/// to 5 bits, G to 6 bits), diffused [right 7/16, down-left 3/16, down 5/16,
/// down-right 1/16] to not-yet-processed neighbours; each write is round+clamp
/// to 0..255. Operates in place on three per-channel byte buffers.
void _floydSteinberg(
  Uint8List rBuf,
  Uint8List gBuf,
  Uint8List bBuf,
  int width,
  int height,
) {
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int idx = y * width + x;
      final int oldR = rBuf[idx];
      final int oldG = gBuf[idx];
      final int oldB = bBuf[idx];
      final int errR = oldR - ((oldR >> 3) << 3);
      final int errG = oldG - ((oldG >> 2) << 2);
      final int errB = oldB - ((oldB >> 3) << 3);
      if (x + 1 < width) {
        final int m = idx + 1;
        rBuf[m] = _clamp255(rBuf[m] + errR * 7 / 16);
        gBuf[m] = _clamp255(gBuf[m] + errG * 7 / 16);
        bBuf[m] = _clamp255(bBuf[m] + errB * 7 / 16);
      }
      if (x - 1 >= 0 && y + 1 < height) {
        final int m = idx + width - 1;
        rBuf[m] = _clamp255(rBuf[m] + errR * 3 / 16);
        gBuf[m] = _clamp255(gBuf[m] + errG * 3 / 16);
        bBuf[m] = _clamp255(bBuf[m] + errB * 3 / 16);
      }
      if (y + 1 < height) {
        final int m = idx + width;
        rBuf[m] = _clamp255(rBuf[m] + errR * 5 / 16);
        gBuf[m] = _clamp255(gBuf[m] + errG * 5 / 16);
        bBuf[m] = _clamp255(bBuf[m] + errB * 5 / 16);
      }
      if (x + 1 < width && y + 1 < height) {
        final int m = idx + width + 1;
        rBuf[m] = _clamp255(rBuf[m] + errR * 1 / 16);
        gBuf[m] = _clamp255(gBuf[m] + errG * 1 / 16);
        bBuf[m] = _clamp255(bBuf[m] + errB * 1 / 16);
      }
    }
  }
}

/// RGB565 has no alpha: semi-transparent pixels are pre-multiplied over black.
/// [rgba] is 4 bytes/pixel (R,G,B,A). Returns little-endian RGB565 bytes
/// (w*h*2). When [dither] is true, applies Floyd–Steinberg before quantizing.
Uint8List rgbaToRgb565Bytes(Uint8List rgba, int width, int height, bool dither) {
  if (!dither) {
    final out = Uint8List(width * height * 2);
    int o = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      int r = rgba[i];
      int g = rgba[i + 1];
      int b = rgba[i + 2];
      final int a = rgba[i + 3];
      if (a != 0xFF) {
        final double alpha = a / 255;
        r = _clamp255(r * alpha);
        g = _clamp255(g * alpha);
        b = _clamp255(b * alpha);
      }
      final int v = _rgbToRgb565(r, g, b);
      out[o++] = v & 0xFF;
      out[o++] = (v >> 8) & 0xFF;
    }
    return out;
  }

  final int n = width * height;
  final rBuf = Uint8List(n);
  final gBuf = Uint8List(n);
  final bBuf = Uint8List(n);
  for (int i = 0, p = 0; p < n; i += 4, p++) {
    int r = rgba[i];
    int g = rgba[i + 1];
    int b = rgba[i + 2];
    final int a = rgba[i + 3];
    if (a != 0xFF) {
      final double alpha = a / 255;
      r = _clamp255(r * alpha);
      g = _clamp255(g * alpha);
      b = _clamp255(b * alpha);
    }
    rBuf[p] = r;
    gBuf[p] = g;
    bBuf[p] = b;
  }
  _floydSteinberg(rBuf, gBuf, bBuf, width, height);
  final out = Uint8List(n * 2);
  int o = 0;
  for (int p = 0; p < n; p++) {
    final int v = _rgbToRgb565(rBuf[p], gBuf[p], bBuf[p]);
    out[o++] = v & 0xFF;
    out[o++] = (v >> 8) & 0xFF;
  }
  return out;
}

/// Convert [rgba] (4 bytes/pixel, R,G,B,A) to ARGB8565: 3 bytes/pixel, a
/// little-endian RGB565 colour (2 bytes) followed by the 8-bit alpha byte —
/// the layout the reference converter emits (`writeUInt16LE(rgb565); writeUInt8(a)`).
/// Unlike [rgbaToRgb565Bytes] the colour is NOT premultiplied over black, since
/// the alpha channel is preserved. When [dither] is true, Floyd–Steinberg is
/// applied to the colour channels (alpha untouched), matching the reference,
/// which dithers RGB565 and ARGB8565 alike. Used by the thumbnail encoder.
Uint8List rgbaToArgb8565Bytes(
  Uint8List rgba,
  int width,
  int height, {
  bool dither = false,
}) {
  if (!dither) {
    final out = Uint8List(width * height * 3);
    int o = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      final int v = _rgbToRgb565(rgba[i], rgba[i + 1], rgba[i + 2]);
      out[o++] = v & 0xFF;
      out[o++] = (v >> 8) & 0xFF;
      out[o++] = rgba[i + 3];
    }
    return out;
  }

  final int n = width * height;
  final rBuf = Uint8List(n);
  final gBuf = Uint8List(n);
  final bBuf = Uint8List(n);
  final aBuf = Uint8List(n);
  for (int i = 0, p = 0; p < n; i += 4, p++) {
    rBuf[p] = rgba[i];
    gBuf[p] = rgba[i + 1];
    bBuf[p] = rgba[i + 2];
    aBuf[p] = rgba[i + 3];
  }
  _floydSteinberg(rBuf, gBuf, bBuf, width, height);
  final out = Uint8List(n * 3);
  int o = 0;
  for (int p = 0; p < n; p++) {
    final int v = _rgbToRgb565(rBuf[p], gBuf[p], bBuf[p]);
    out[o++] = v & 0xFF;
    out[o++] = (v >> 8) & 0xFF;
    out[o++] = aBuf[p];
  }
  return out;
}

// ── RLE compression (per line, node = [len:1][pixel:pixelBytes]) ─────────────
class _RleResult {
  final Uint8List compressed;
  final List<int> lineOffsets;
  _RleResult(this.compressed, this.lineOffsets);
}

_RleResult _rleCompress(Uint8List pixelData, int width, int height, int pixelBytes) {
  final int bytesPerLine = width * pixelBytes;
  final compressed = <int>[];
  final lineOffsets = List<int>.filled(height, 0);

  for (int line = 0; line < height; line++) {
    lineOffsets[line] = compressed.length;
    final int lineStart = line * bytesPerLine;
    final int lineEnd = lineStart + bytesPerLine;

    int i = lineStart;
    while (i < lineEnd) {
      int runLength = 1;
      int j = i + pixelBytes;
      while (j < lineEnd && runLength < 255) {
        bool same = true;
        for (int k = 0; k < pixelBytes; k++) {
          if (pixelData[i + k] != pixelData[j + k]) {
            same = false;
            break;
          }
        }
        if (!same) break;
        runLength++;
        j += pixelBytes;
      }
      compressed.add(runLength);
      for (int k = 0; k < pixelBytes; k++) {
        compressed.add(pixelData[i + k]);
      }
      i = j;
    }
  }

  return _RleResult(Uint8List.fromList(compressed), lineOffsets);
}

// ── Headers ──────────────────────────────────────────────────────────────────
// gui_rgb_data_head_t (8 bytes)
Uint8List _packRgbDataHeader(int width, int height, int format, bool compress) {
  final buf = Uint8List(8);
  final dv = ByteData.view(buf.buffer);
  // byte0: flag bitfield. resize=0 (scaled app-side), compress = bit4.
  final int flags = (compress ? 1 : 0) << 4;
  dv.setUint8(0, flags & 0xFF);
  dv.setUint8(1, format & 0xFF);
  dv.setInt16(2, width, Endian.little);
  dv.setInt16(4, height, Endian.little);
  dv.setUint8(6, 0); // version
  dv.setUint8(7, 0); // rsvd2
  return buf;
}

// imdc_file_header_t (12 bytes)
Uint8List _packImdcHeader(
  int algorithm,
  int feature1,
  int feature2,
  int pixelBytes,
  int width,
  int height,
) {
  final buf = Uint8List(12);
  final dv = ByteData.view(buf.buffer);
  final int algorithmType = (algorithm & 0x03) |
      ((feature1 & 0x03) << 2) |
      ((feature2 & 0x03) << 4) |
      ((pixelBytes & 0x03) << 6);
  dv.setUint8(0, algorithmType);
  dv.setUint8(1, 0);
  dv.setUint8(2, 0);
  dv.setUint8(3, 0);
  dv.setUint32(4, width & 0xFFFFFFFF, Endian.little);
  dv.setUint32(8, height & 0xFFFFFFFF, Endian.little);
  return buf;
}

Uint8List _concat(List<Uint8List> arrays) {
  int total = 0;
  for (final a in arrays) {
    total += a.length;
  }
  final out = Uint8List(total);
  int off = 0;
  for (final a in arrays) {
    out.setRange(off, off + a.length, a);
    off += a.length;
  }
  return out;
}

// ── Main conversion ───────────────────────────────────────────────────────────
/// Encode [rgba] (w*h*4, R,G,B,A) into a HoneyGUI `.bin`.
/// [compress] enables RLE (default true); [dither] enables Floyd–Steinberg.
Uint8List buildImageBin(
  Uint8List rgba,
  int width,
  int height, {
  bool compress = true,
  bool dither = false,
}) {
  final Uint8List pixelData = rgbaToRgb565Bytes(rgba, width, height, dither);
  return _buildFromPixels(pixelData, width, height, compress);
}

/// Build the `.bin` from already-converted [pixelData]. Split out so the
/// adaptive builder can convert pixels once and produce both variants cheaply.
/// Defaults describe RGB565 (2 bytes/px); the ARGB8565 path passes its own
/// [format]/[pixelBytes]/[pixelBytesEnum].
Uint8List _buildFromPixels(
  Uint8List pixelData,
  int width,
  int height,
  bool compress, {
  int format = _pixelFormatRgb565,
  int pixelBytes = 2,
  int pixelBytesEnum = _pixelBytesRgb565,
}) {
  final Uint8List header = _packRgbDataHeader(width, height, format, compress);

  if (!compress) {
    return _concat([header, pixelData]);
  }

  final _RleResult rle = _rleCompress(pixelData, width, height, pixelBytes);
  final Uint8List imdc = _packImdcHeader(
    _compressRle,
    _rleRunLen1,
    _rleRunLen2,
    pixelBytesEnum,
    width,
    height,
  );

  // Offset table entries are relative to the imdc_file_t start.
  // imdcOffset = imdc(12) + offset table ((h+1)*4).
  final int imdcOffset = 12 + (height + 1) * 4;
  final offsetTable = Uint8List((height + 1) * 4);
  final odv = ByteData.view(offsetTable.buffer);
  for (int i = 0; i < height; i++) {
    odv.setUint32(i * 4, (imdcOffset + rle.lineOffsets[i]) & 0xFFFFFFFF, Endian.little);
  }
  odv.setUint32(
      height * 4, (imdcOffset + rle.compressed.length) & 0xFFFFFFFF, Endian.little);

  return _concat([header, imdc, offsetTable, rle.compressed]);
}

/// Result of [buildImageBinAdaptive]: [bin] is the smaller of the uncompressed
/// and RLE-compressed encodings; [rawSize]/[rleSize] expose both sizes for a
/// before/after comparison, and [compressed] says which one won.
class ImageBinResult {
  final Uint8List bin;
  final bool compressed;
  final int rawSize;
  final int rleSize;
  const ImageBinResult({
    required this.bin,
    required this.compressed,
    required this.rawSize,
    required this.rleSize,
  });
}

/// Convert [rgba] once, encode it both uncompressed and RLE-compressed, and
/// return whichever is smaller. RLE can be *larger* than raw for noisy/photo
/// content (per-line + offset-table overhead), so picking adaptively always
/// yields the smallest transfer without asking the user to choose.
ImageBinResult buildImageBinAdaptive(
  Uint8List rgba,
  int width,
  int height, {
  bool dither = false,
}) {
  final Uint8List pixelData = rgbaToRgb565Bytes(rgba, width, height, dither);
  return _buildAdaptiveFromPixels(
    pixelData,
    width,
    height,
    format: _pixelFormatRgb565,
    pixelBytes: 2,
    pixelBytesEnum: _pixelBytesRgb565,
  );
}

/// ARGB8565 counterpart of [buildImageBinAdaptive]: converts [rgba] to ARGB8565
/// (3 bytes/px, alpha preserved; [dither] applies Floyd–Steinberg to colour) and
/// returns whichever of the uncompressed / RLE encodings is smaller. Used to
/// encode the 160×160 circular thumbnail.
ImageBinResult buildArgb8565BinAdaptive(
  Uint8List rgba,
  int width,
  int height, {
  bool dither = false,
}) {
  final Uint8List pixelData = rgbaToArgb8565Bytes(rgba, width, height, dither: dither);
  return _buildAdaptiveFromPixels(
    pixelData,
    width,
    height,
    format: _pixelFormatArgb8565,
    pixelBytes: 3,
    pixelBytesEnum: _pixelBytesArgb8565,
  );
}

/// Shared body of the adaptive builders: encode [pixelData] both uncompressed
/// and RLE-compressed, return the smaller. RLE can be *larger* than raw for
/// noisy content (per-line + offset-table overhead), so picking adaptively
/// always yields the smallest transfer.
ImageBinResult _buildAdaptiveFromPixels(
  Uint8List pixelData,
  int width,
  int height, {
  required int format,
  required int pixelBytes,
  required int pixelBytesEnum,
}) {
  // The uncompressed size is fixed by geometry (header + w*h*pixelBytes), so
  // derive it directly instead of materializing those bytes just to measure.
  final int rawSize = _rgbDataHeaderBytes + width * height * pixelBytes;

  // RLE is data-dependent — it must actually be built to know its size.
  final Uint8List rle = _buildFromPixels(
    pixelData,
    width,
    height,
    true,
    format: format,
    pixelBytes: pixelBytes,
    pixelBytesEnum: pixelBytesEnum,
  );
  if (rle.length < rawSize) {
    return ImageBinResult(
      bin: rle,
      compressed: true,
      rawSize: rawSize,
      rleSize: rle.length,
    );
  }

  // RLE didn't shrink it — materialize the uncompressed variant only now.
  final Uint8List raw = _buildFromPixels(
    pixelData,
    width,
    height,
    false,
    format: format,
    pixelBytes: pixelBytes,
    pixelBytesEnum: pixelBytesEnum,
  );
  return ImageBinResult(
    bin: raw,
    compressed: false,
    rawSize: rawSize,
    rleSize: rle.length,
  );
}

// ── Decode (bin → RGBA, for previewing cached files) ─────────────────────────

/// RGBA8888 pixels decoded from a HoneyGUI `.bin` (see [buildImageBin]).
class ImageBinPixels {
  final Uint8List rgba; // w*h*4
  final int width;
  final int height;
  const ImageBinPixels({
    required this.rgba,
    required this.width,
    required this.height,
  });
}

/// Expand a little-endian RGB565 value into RGBA at [rgba]\[o..o+3] (opaque).
/// Low bits are replicated into the freed low bits so full white/black map back
/// exactly (5→8 and 6→8 bit expansion).
void _writeRgb565(Uint8List rgba, int o, int v) {
  final int r5 = (v >> 11) & 0x1F;
  final int g6 = (v >> 5) & 0x3F;
  final int b5 = v & 0x1F;
  rgba[o] = (r5 << 3) | (r5 >> 2);
  rgba[o + 1] = (g6 << 2) | (g6 >> 4);
  rgba[o + 2] = (b5 << 3) | (b5 >> 2);
  rgba[o + 3] = 0xFF;
}

/// Like [_writeRgb565] but carries the supplied [a]lpha byte through (ARGB8565).
void _writeArgb8565(Uint8List rgba, int o, int v, int a) {
  final int r5 = (v >> 11) & 0x1F;
  final int g6 = (v >> 5) & 0x3F;
  final int b5 = v & 0x1F;
  rgba[o] = (r5 << 3) | (r5 >> 2);
  rgba[o + 1] = (g6 << 2) | (g6 >> 4);
  rgba[o + 2] = (b5 << 3) | (b5 >> 2);
  rgba[o + 3] = a;
}

/// Decode a HoneyGUI RGB565 `.bin` (uncompressed **or** RLE, as produced by
/// [buildImageBin]) back into RGBA8888 for on-screen preview. Returns null when
/// the bytes are too short or the header is malformed. Inverse of the encoder:
/// reads the 8-byte gui_rgb_data_head_t, and for RLE walks the per-line offset
/// table + `[len:1][pixel:2]` nodes.
ImageBinPixels? decodeImageBin(Uint8List bin) {
  if (bin.length < _rgbDataHeaderBytes) return null;
  final bd = ByteData.sublistView(bin);
  final int flags = bd.getUint8(0);
  final bool compressed = (flags & (1 << 4)) != 0;
  final int width = bd.getInt16(2, Endian.little);
  final int height = bd.getInt16(4, Endian.little);
  if (width <= 0 || height <= 0) return null;
  final int n = width * height;
  final rgba = Uint8List(n * 4);

  if (!compressed) {
    if (bin.length < _rgbDataHeaderBytes + n * 2) return null;
    int p = _rgbDataHeaderBytes;
    for (int i = 0; i < n; i++) {
      _writeRgb565(rgba, i * 4, bd.getUint16(p, Endian.little));
      p += 2;
    }
    return ImageBinPixels(rgba: rgba, width: width, height: height);
  }

  // RLE: header(8) + imdc(12) + offset table (h+1)*4 + per-line nodes. Table
  // entries are offsets from the imdc start, so absolute file offset = 8 + entry.
  const int tableStart = _rgbDataHeaderBytes + 12;
  if (bin.length < tableStart + (height + 1) * 4) return null;
  for (int line = 0; line < height; line++) {
    final int start =
        _rgbDataHeaderBytes + bd.getUint32(tableStart + line * 4, Endian.little);
    final int end = _rgbDataHeaderBytes +
        bd.getUint32(tableStart + (line + 1) * 4, Endian.little);
    int p = start;
    int col = 0;
    final int rowBase = line * width * 4;
    // Each node is 3 bytes: p+2 < end ⇔ 3 bytes ([len][px_lo][px_hi]) remain.
    while (p + 2 < end && col < width) {
      final int run = bd.getUint8(p);
      final int v = bd.getUint16(p + 1, Endian.little);
      p += 3;
      for (int k = 0; k < run && col < width; k++) {
        _writeRgb565(rgba, rowBase + col * 4, v);
        col++;
      }
    }
  }
  return ImageBinPixels(rgba: rgba, width: width, height: height);
}

/// Decode an ARGB8565 `.bin` (uncompressed **or** RLE, as produced by
/// [buildArgb8565BinAdaptive]) back into RGBA8888 with the alpha channel
/// preserved. Inverse of the encoder; returns null on short/malformed input.
/// Provided mainly for round-trip testing — the firmware is the real consumer.
ImageBinPixels? decodeArgb8565Bin(Uint8List bin) {
  if (bin.length < _rgbDataHeaderBytes) return null;
  final bd = ByteData.sublistView(bin);
  final int flags = bd.getUint8(0);
  final bool compressed = (flags & (1 << 4)) != 0;
  final int width = bd.getInt16(2, Endian.little);
  final int height = bd.getInt16(4, Endian.little);
  if (width <= 0 || height <= 0) return null;
  final int n = width * height;
  final rgba = Uint8List(n * 4);

  if (!compressed) {
    if (bin.length < _rgbDataHeaderBytes + n * 3) return null;
    int p = _rgbDataHeaderBytes;
    for (int i = 0; i < n; i++) {
      _writeArgb8565(
          rgba, i * 4, bd.getUint16(p, Endian.little), bd.getUint8(p + 2));
      p += 3;
    }
    return ImageBinPixels(rgba: rgba, width: width, height: height);
  }

  const int tableStart = _rgbDataHeaderBytes + 12;
  if (bin.length < tableStart + (height + 1) * 4) return null;
  for (int line = 0; line < height; line++) {
    final int start =
        _rgbDataHeaderBytes + bd.getUint32(tableStart + line * 4, Endian.little);
    final int end = _rgbDataHeaderBytes +
        bd.getUint32(tableStart + (line + 1) * 4, Endian.little);
    int p = start;
    int col = 0;
    final int rowBase = line * width * 4;
    // Each node is 4 bytes: [len][px_lo][px_hi][alpha].
    while (p + 3 < end && col < width) {
      final int run = bd.getUint8(p);
      final int v = bd.getUint16(p + 1, Endian.little);
      final int a = bd.getUint8(p + 3);
      p += 4;
      for (int k = 0; k < run && col < width; k++) {
        _writeArgb8565(rgba, rowBase + col * 4, v, a);
        col++;
      }
    }
  }
  return ImageBinPixels(rgba: rgba, width: width, height: height);
}
