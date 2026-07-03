// image_bin.dart
//
// Converts decoded RGBA pixels into a HoneyGUI device `.bin` file. This is a
// faithful Dart port of the miniprogram's `utils/image-bin.js` encoding half
// (pixel conversion + RLE + headers). The decode/resize half (which needs a
// canvas) lives in `raster.dart`; this file is pure Dart (dart:typed_data only)
// so it stays testable and off the Flutter dependency.
//
// Output format (RGB565):
//   uncompressed: [gui_rgb_data_head_t 8B] [pixel data: w*h*2]
//   RLE:          [gui_rgb_data_head_t 8B] [imdc_file_header_t 12B]
//                 [offset table (h+1)*4] [compressed data]

import 'dart:typed_data';

// ── Pixel format (matches SDK GUI_FormatType; only RGB565 used) ──────────────
const int _pixelFormatRgb565 = 0;

// imdc pixel_bytes enum: RGB565 -> BYTES_2 (0)
const int _pixelBytesRgb565 = 0;

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

/// Build the `.bin` from already-converted RGB565 [pixelData]. Split out so the
/// adaptive builder can convert pixels once and produce both variants cheaply.
Uint8List _buildFromPixels(
  Uint8List pixelData,
  int width,
  int height,
  bool compress,
) {
  const int format = _pixelFormatRgb565;
  const int pixelBytes = 2;

  final Uint8List header = _packRgbDataHeader(width, height, format, compress);

  if (!compress) {
    return _concat([header, pixelData]);
  }

  final _RleResult rle = _rleCompress(pixelData, width, height, pixelBytes);
  final Uint8List imdc = _packImdcHeader(
    _compressRle,
    _rleRunLen1,
    _rleRunLen2,
    _pixelBytesRgb565,
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
  const int pixelBytes = 2; // RGB565
  final Uint8List pixelData = rgbaToRgb565Bytes(rgba, width, height, dither);

  // The uncompressed size is fixed by geometry (header + w*h*2), so derive it
  // directly instead of materializing those bytes just to measure them.
  final int rawSize = _rgbDataHeaderBytes + width * height * pixelBytes;

  // RLE is data-dependent — it must actually be built to know its size.
  final Uint8List rle = _buildFromPixels(pixelData, width, height, true);
  if (rle.length < rawSize) {
    return ImageBinResult(
      bin: rle,
      compressed: true,
      rawSize: rawSize,
      rleSize: rle.length,
    );
  }

  // RLE didn't shrink it — materialize the uncompressed variant only now.
  final Uint8List raw = _buildFromPixels(pixelData, width, height, false);
  return ImageBinResult(
    bin: raw,
    compressed: false,
    rawSize: rawSize,
    rleSize: rle.length,
  );
}
