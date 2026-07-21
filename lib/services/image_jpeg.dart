// image_jpeg.dart
//
// Pure-Dart baseline (sequential DCT) JPEG encoder with 4:2:0 chroma
// subsampling (YCbCr / JFIF). Hand-written — like image_bin.dart — because no
// available Dart package guarantees *baseline + 4:2:0*, which the device's
// hardware JPEG decoder requires. dart:typed_data + dart:math only, so it stays
// testable and off the Flutter dependency.
//
// Output container (what buildImageJpegBin returns):
//   [16B device header] [JFIF JPEG bytes: SOI … EOI]
//
// The 16-byte header mirrors the RGB565 gui_rgb_data_head_t in its first 8 bytes
// (so the device reads one layout for both and branches on the type byte), then
// adds a uint32 JPEG size and a 4-byte alignment tail. See _packJpegHeader.

import 'dart:math' as math;
import 'dart:typed_data';

/// Device image container header length, in bytes; precedes the JFIF JPEG
/// payload. See [_packJpegHeader] for the field layout.
const int kJpegHeaderBytes = 16;

// ── Standard quantization tables (Annex K.1), natural (row-major) order ──────
const List<int> _stdLumQuant = [
  16, 11, 10, 16, 24, 40, 51, 61, //
  12, 12, 14, 19, 26, 58, 60, 55, //
  14, 13, 16, 24, 40, 57, 69, 56, //
  14, 17, 22, 29, 51, 87, 80, 62, //
  18, 22, 37, 56, 68, 109, 103, 77, //
  24, 35, 55, 64, 81, 104, 113, 92, //
  49, 64, 78, 87, 103, 121, 120, 101, //
  72, 92, 95, 98, 112, 100, 103, 99, //
];

const List<int> _stdChromQuant = [
  17, 18, 24, 47, 99, 99, 99, 99, //
  18, 21, 26, 66, 99, 99, 99, 99, //
  24, 26, 56, 99, 99, 99, 99, 99, //
  47, 66, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
  99, 99, 99, 99, 99, 99, 99, 99, //
];

// Zig-zag order: _zigzag[k] = natural index emitted at scan position k.
const List<int> _zigzag = [
  0, 1, 8, 16, 9, 2, 3, 10, //
  17, 24, 32, 25, 18, 11, 4, 5, //
  12, 19, 26, 33, 40, 48, 41, 34, //
  27, 20, 13, 6, 7, 14, 21, 28, //
  35, 42, 49, 56, 57, 50, 43, 36, //
  29, 22, 15, 23, 30, 37, 44, 51, //
  58, 59, 52, 45, 38, 31, 39, 46, //
  53, 60, 61, 54, 47, 55, 62, 63, //
];

// ── Standard Huffman tables (Annex K.3): BITS (16 length-counts) + HUFFVAL ────
const List<int> _dcLumBits = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
const List<int> _dcLumVals = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

const List<int> _dcChromBits = [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0];
const List<int> _dcChromVals = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

const List<int> _acLumBits = [
  0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d //
];
const List<int> _acLumVals = [
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, //
  0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, //
  0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, //
  0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0, //
  0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, //
  0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28, //
  0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, //
  0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, //
  0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, //
  0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, //
  0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, //
  0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, //
  0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, //
  0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, //
  0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, //
  0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, //
  0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, //
  0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2, //
  0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, //
  0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, //
  0xf9, 0xfa //
];

const List<int> _acChromBits = [
  0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77 //
];
const List<int> _acChromVals = [
  0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, //
  0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71, //
  0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, //
  0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0, //
  0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, //
  0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26, //
  0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, //
  0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, //
  0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, //
  0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, //
  0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, //
  0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, //
  0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, //
  0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, //
  0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, //
  0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, //
  0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, //
  0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, //
  0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, //
  0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, //
  0xf9, 0xfa //
];

// ── Precomputed orthonormal DCT-II basis: _dctC[u*8+x] ────────────────────────
// The orthonormal 2D DCT-II equals the JPEG FDCT (1/4)C(u)C(v)ΣΣ… exactly, so
// applying this 1D matrix separably (rows then columns) yields JPEG coefficients
// directly — no post-scaling needed before dividing by the quant table.
final Float64List _dctC = _buildDctMatrix();

Float64List _buildDctMatrix() {
  final m = Float64List(64);
  for (int u = 0; u < 8; u++) {
    final double a = u == 0 ? math.sqrt(1 / 8) : math.sqrt(2 / 8);
    for (int x = 0; x < 8; x++) {
      m[u * 8 + x] = a * math.cos((2 * x + 1) * u * math.pi / 16);
    }
  }
  return m;
}

// ── Canonical Huffman code table (Annex C): symbol -> (code, bit length) ──────
class _Huff {
  final Int32List code = Int32List(256);
  final Int32List size = Int32List(256);

  _Huff(List<int> bits, List<int> vals) {
    // HUFFSIZE: bit length of each value, in table order.
    final huffSize = <int>[];
    for (int l = 0; l < 16; l++) {
      for (int j = 0; j < bits[l]; j++) {
        huffSize.add(l + 1);
      }
    }
    // HUFFCODE: consecutive codes within each length, doubled between lengths.
    final huffCode = List<int>.filled(huffSize.length, 0);
    if (huffSize.isNotEmpty) {
      int c = 0;
      int si = huffSize[0];
      int k = 0;
      while (k < huffSize.length) {
        while (k < huffSize.length && huffSize[k] == si) {
          huffCode[k] = c;
          c++;
          k++;
        }
        c <<= 1;
        si++;
      }
    }
    for (int i = 0; i < vals.length; i++) {
      code[vals[i]] = huffCode[i];
      size[vals[i]] = huffSize[i];
    }
  }
}

// ── MSB-first bit writer with 0xFF byte-stuffing (entropy-coded segment) ──────
class _BitWriter {
  final BytesBuilder out;
  int _acc = 0; // pending bits, left-aligned within the low `_n` bits
  int _n = 0; // number of pending bits (< 8 after each put)

  _BitWriter(this.out);

  void put(int code, int size) {
    if (size == 0) return;
    _acc = (_acc << size) | (code & ((1 << size) - 1));
    _n += size;
    while (_n >= 8) {
      _n -= 8;
      final int b = (_acc >> _n) & 0xFF;
      out.addByte(b);
      if (b == 0xFF) out.addByte(0x00); // stuff a zero after every real 0xFF
    }
  }

  // Flush the final partial byte, padding with 1-bits (JPEG convention).
  void finish() {
    if (_n > 0) put((1 << (8 - _n)) - 1, 8 - _n);
  }
}

// Bit length of |v| (the JPEG "category"/SSSS); 0 for v == 0.
int _category(int v) {
  int a = v < 0 ? -v : v;
  int c = 0;
  while (a > 0) {
    c++;
    a >>= 1;
  }
  return c;
}

// The `size`-bit magnitude field: |v| for v>0, one's complement for v<0.
int _mantissa(int v, int size) => (v >= 0 ? v : v - 1) & ((1 << size) - 1);

Int32List _scaleQuant(List<int> base, int quality) {
  int q = quality;
  if (q < 1) q = 1;
  if (q > 100) q = 100;
  final int scale = q < 50 ? (5000 ~/ q) : (200 - q * 2);
  final out = Int32List(64);
  for (int i = 0; i < 64; i++) {
    int v = (base[i] * scale + 50) ~/ 100;
    if (v < 1) v = 1;
    if (v > 255) v = 255; // baseline: 8-bit quant precision
    out[i] = v;
  }
  return out;
}

// Forward DCT of a level-shifted 8×8 block into `dst` (natural order).
void _fdct(Float64List block, Float64List tmp, Float64List dst) {
  // Rows: tmp[y*8+u] = Σ_x block[y*8+x] * C[u,x]
  for (int y = 0; y < 8; y++) {
    final int r = y * 8;
    for (int u = 0; u < 8; u++) {
      final int cu = u * 8;
      double s = 0;
      for (int x = 0; x < 8; x++) {
        s += block[r + x] * _dctC[cu + x];
      }
      tmp[r + u] = s;
    }
  }
  // Columns: dst[v*8+u] = Σ_y tmp[y*8+u] * C[v,y]
  for (int u = 0; u < 8; u++) {
    for (int v = 0; v < 8; v++) {
      final int cv = v * 8;
      double s = 0;
      for (int y = 0; y < 8; y++) {
        s += tmp[y * 8 + u] * _dctC[cv + y];
      }
      dst[v * 8 + u] = s;
    }
  }
}

// Encode one 8×8 block (FDCT → quantize → zig-zag → Huffman). Returns this
// block's quantized DC so the caller can carry it as the next DC predictor.
int _encodeBlock(
  _BitWriter bw,
  Float64List block,
  Float64List tmp,
  Float64List coeff,
  Int32List quant,
  _Huff dc,
  _Huff ac,
  int prevDc,
) {
  _fdct(block, tmp, coeff);
  final q = Int32List(64);
  for (int i = 0; i < 64; i++) {
    q[i] = (coeff[i] / quant[i]).round();
  }

  // DC: Huffman(category) + magnitude of (dc - prevDc).
  final int diff = q[0] - prevDc;
  final int s = _category(diff);
  bw.put(dc.code[s], dc.size[s]);
  if (s > 0) bw.put(_mantissa(diff, s), s);

  // AC: run-length of zeros + Huffman(run<<4 | size) + magnitude, in zig-zag.
  int run = 0;
  for (int k = 1; k < 64; k++) {
    final int c = q[_zigzag[k]];
    if (c == 0) {
      run++;
      continue;
    }
    while (run > 15) {
      bw.put(ac.code[0xF0], ac.size[0xF0]); // ZRL (16 zeros)
      run -= 16;
    }
    final int sz = _category(c);
    final int sym = (run << 4) | sz;
    bw.put(ac.code[sym], ac.size[sym]);
    bw.put(_mantissa(c, sz), sz);
    run = 0;
  }
  if (run > 0) bw.put(ac.code[0x00], ac.size[0x00]); // EOB

  return q[0];
}

void _u16(BytesBuilder b, int v) {
  b.addByte((v >> 8) & 0xFF);
  b.addByte(v & 0xFF);
}

void _writeDqt(BytesBuilder b, int id, Int32List quant) {
  b.addByte(0xFF);
  b.addByte(0xDB);
  _u16(b, 2 + 1 + 64);
  b.addByte(id & 0x0F); // Pq=0 (8-bit) | Tq=id
  for (int k = 0; k < 64; k++) {
    b.addByte(quant[_zigzag[k]] & 0xFF); // quant values in zig-zag order
  }
}

void _writeDht(BytesBuilder b, int tcTh, List<int> bits, List<int> vals) {
  b.addByte(0xFF);
  b.addByte(0xC4);
  _u16(b, 2 + 1 + 16 + vals.length);
  b.addByte(tcTh);
  for (int i = 0; i < 16; i++) {
    b.addByte(bits[i]);
  }
  for (final v in vals) {
    b.addByte(v);
  }
}

/// Encode [rgba] (w*h*4, R,G,B,A; alpha ignored — assumed opaque) into baseline
/// JPEG bytes (SOI…EOI), YCbCr with 4:2:0 chroma subsampling. [quality] is the
/// IJG 1..100 scale. Pure JFIF JPEG — no custom header (see [buildImageJpegBin]).
Uint8List encodeBaselineJpegYuv420(
  Uint8List rgba,
  int width,
  int height, {
  required int quality,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('invalid size ${width}x$height');
  }
  if (rgba.length < width * height * 4) {
    throw ArgumentError('rgba too short for ${width}x$height');
  }

  final Int32List qLum = _scaleQuant(_stdLumQuant, quality);
  final Int32List qChrom = _scaleQuant(_stdChromQuant, quality);
  final dcLum = _Huff(_dcLumBits, _dcLumVals);
  final acLum = _Huff(_acLumBits, _acLumVals);
  final dcChrom = _Huff(_dcChromBits, _dcChromVals);
  final acChrom = _Huff(_acChromBits, _acChromVals);

  final b = BytesBuilder();
  // SOI
  b.addByte(0xFF);
  b.addByte(0xD8);
  // APP0 / JFIF
  b.addByte(0xFF);
  b.addByte(0xE0);
  _u16(b, 16);
  b.add(const [0x4A, 0x46, 0x49, 0x46, 0x00]); // "JFIF\0"
  b.add(const [1, 1]); // version 1.1
  b.addByte(0); // density units: none
  _u16(b, 1); // Xdensity
  _u16(b, 1); // Ydensity
  b.addByte(0); // Xthumbnail
  b.addByte(0); // Ythumbnail
  // DQT ×2
  _writeDqt(b, 0, qLum);
  _writeDqt(b, 1, qChrom);
  // SOF0 (baseline): Y=2×2 (4:2:0), Cb/Cr=1×1
  b.addByte(0xFF);
  b.addByte(0xC0);
  _u16(b, 8 + 3 * 3);
  b.addByte(8); // sample precision
  _u16(b, height);
  _u16(b, width);
  b.addByte(3); // components
  b.add(const [1, 0x22, 0]); // Y : H=2,V=2, quant table 0
  b.add(const [2, 0x11, 1]); // Cb: H=1,V=1, quant table 1
  b.add(const [3, 0x11, 1]); // Cr: H=1,V=1, quant table 1
  // DHT ×4
  _writeDht(b, 0x00, _dcLumBits, _dcLumVals);
  _writeDht(b, 0x10, _acLumBits, _acLumVals);
  _writeDht(b, 0x01, _dcChromBits, _dcChromVals);
  _writeDht(b, 0x11, _acChromBits, _acChromVals);
  // SOS
  b.addByte(0xFF);
  b.addByte(0xDA);
  _u16(b, 6 + 2 * 3);
  b.addByte(3);
  b.add(const [1, 0x00]); // Y : DC table 0, AC table 0
  b.add(const [2, 0x11]); // Cb: DC table 1, AC table 1
  b.add(const [3, 0x11]); // Cr: DC table 1, AC table 1
  b.add(const [0, 63, 0]); // Ss, Se, Ah/Al

  // ── Entropy-coded segment ──────────────────────────────────────────────────
  final bw = _BitWriter(b);
  final tmp = Float64List(64);
  final coeff = Float64List(64);
  final yb = Float64List(64); // reused per luma block
  final cbb = Float64List(64);
  final crb = Float64List(64);
  // 16×16 MCU scratch (Y/Cb/Cr, not yet level-shifted).
  final ys = Float64List(256);
  final cbs = Float64List(256);
  final crs = Float64List(256);

  final int mcuW = (width + 15) >> 4;
  final int mcuH = (height + 15) >> 4;
  int dcY = 0, dcCb = 0, dcCr = 0;

  for (int my = 0; my < mcuH; my++) {
    for (int mx = 0; mx < mcuW; mx++) {
      // Fill the 16×16 scratch, replicating edge pixels past the image bounds.
      for (int yy = 0; yy < 16; yy++) {
        int py = my * 16 + yy;
        if (py >= height) py = height - 1;
        for (int xx = 0; xx < 16; xx++) {
          int px = mx * 16 + xx;
          if (px >= width) px = width - 1;
          final int i = (py * width + px) * 4;
          final double r = rgba[i].toDouble();
          final double g = rgba[i + 1].toDouble();
          final double bl = rgba[i + 2].toDouble();
          final int p = yy * 16 + xx;
          ys[p] = 0.299 * r + 0.587 * g + 0.114 * bl;
          cbs[p] = -0.168736 * r - 0.331264 * g + 0.5 * bl + 128;
          crs[p] = 0.5 * r - 0.418688 * g - 0.081312 * bl + 128;
        }
      }
      // 4 luma blocks (raster order within the MCU), level-shifted by −128.
      for (int by = 0; by < 2; by++) {
        for (int bx = 0; bx < 2; bx++) {
          for (int yy = 0; yy < 8; yy++) {
            final int srow = (by * 8 + yy) * 16 + bx * 8;
            final int drow = yy * 8;
            for (int xx = 0; xx < 8; xx++) {
              yb[drow + xx] = ys[srow + xx] - 128;
            }
          }
          dcY = _encodeBlock(bw, yb, tmp, coeff, qLum, dcLum, acLum, dcY);
        }
      }
      // One Cb and one Cr block: each chroma sample = mean of a 2×2 pixel group.
      for (int cy = 0; cy < 8; cy++) {
        for (int cx = 0; cx < 8; cx++) {
          final int s0 = (cy * 2) * 16 + cx * 2;
          final int s1 = s0 + 16;
          final double cb =
              (cbs[s0] + cbs[s0 + 1] + cbs[s1] + cbs[s1 + 1]) * 0.25;
          final double cr =
              (crs[s0] + crs[s0 + 1] + crs[s1] + crs[s1 + 1]) * 0.25;
          final int d = cy * 8 + cx;
          cbb[d] = cb - 128;
          crb[d] = cr - 128;
        }
      }
      dcCb = _encodeBlock(bw, cbb, tmp, coeff, qChrom, dcChrom, acChrom, dcCb);
      dcCr = _encodeBlock(bw, crb, tmp, coeff, qChrom, dcChrom, acChrom, dcCr);
    }
  }
  bw.finish();

  // EOI
  b.addByte(0xFF);
  b.addByte(0xD9);
  return b.toBytes();
}

// Type byte at header offset 1 marking the payload as JPEG. Parallels the
// RGB565 gui_rgb_data_head_t format field (RGB565 = 0), so the device reads the
// same first 8 bytes for both containers and branches on this byte.
const int _jpegHeaderType = 0x0C; // 12 = JPEG

/// Pack the 16-byte device image container header. Its first 8 bytes mirror the
/// RGB565 `gui_rgb_data_head_t` layout exactly, so the device reads one header
/// shape for both formats and distinguishes them by offset 1 (0 = RGB565,
/// 12 = JPEG); JPEG then adds the payload size and an alignment tail:
///
///   0       flags bitfield         = 0x00
///   1       type                   = 0x0C (JPEG)
///   2..3    width          (uint16 LE)
///   4..5    height         (uint16 LE)
///   6       version                = 0x00
///   7       rsvd2                  = 0x00
///   8..11   JPEG data size (uint32 LE)
///   12..15  alignment              = 0x00000000
Uint8List _packJpegHeader(int width, int height, int jpegLength) {
  final buf = Uint8List(kJpegHeaderBytes);
  final dv = ByteData.view(buf.buffer);
  dv.setUint8(0, 0x00); // all bit fields zero
  dv.setUint8(1, _jpegHeaderType);
  dv.setUint16(2, width & 0xFFFF, Endian.little);
  dv.setUint16(4, height & 0xFFFF, Endian.little);
  dv.setUint8(6, 0x00); // version
  dv.setUint8(7, 0x00); // rsvd2
  dv.setUint32(8, jpegLength & 0xFFFFFFFF, Endian.little);
  // bytes 12..15: alignment field, left zero.
  return buf;
}

/// Encode [rgba] to the device image container: the 16-byte header (see
/// [_packJpegHeader]) followed by baseline-4:2:0 JPEG bytes. This is what the
/// image page sends when quality < 100 (quality == 100 keeps the RGB565 path).
Uint8List buildImageJpegBin(
  Uint8List rgba,
  int width,
  int height, {
  required int quality,
}) {
  final Uint8List jpeg =
      encodeBaselineJpegYuv420(rgba, width, height, quality: quality);
  final Uint8List header = _packJpegHeader(width, height, jpeg.length);
  final out = Uint8List(header.length + jpeg.length);
  out.setRange(0, header.length, header);
  out.setRange(header.length, out.length, jpeg);
  return out;
}
