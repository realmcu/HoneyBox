import 'dart:typed_data';

import 'package:honeybox/services/image_bin.dart';
import 'package:flutter_test/flutter_test.dart';

// Build w*h*4 RGBA from a per-pixel generator returning [r,g,b,a].
Uint8List _rgba(int w, int h, List<int> Function(int x, int y) gen) {
  final out = Uint8List(w * h * 4);
  int o = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final px = gen(x, y);
      out[o++] = px[0];
      out[o++] = px[1];
      out[o++] = px[2];
      out[o++] = px[3];
    }
  }
  return out;
}

// Fetch decoded pixel (x,y) as [r,g,b,a].
List<int> _at(ImageBinPixels img, int x, int y) {
  final o = (y * img.width + x) * 4;
  return [img.rgba[o], img.rgba[o + 1], img.rgba[o + 2], img.rgba[o + 3]];
}

void main() {
  group('rgb565FromArgb', () {
    test('packs primaries and ignores alpha', () {
      expect(rgb565FromArgb(0xFFFF0000), 0xF800); // red
      expect(rgb565FromArgb(0xFF00FF00), 0x07E0); // green
      expect(rgb565FromArgb(0xFF0000FF), 0x001F); // blue
      // Alpha byte must not affect the result.
      expect(rgb565FromArgb(0x00FF0000), 0xF800);
    });
  });

  group('rgbaToArgb8565Bytes', () {
    test('emits 3 bytes/px: little-endian RGB565 then the raw alpha byte', () {
      // px0 pure red (a=200), px1 pure green (a=50).
      final rgba =
          _rgba(2, 1, (x, y) => x == 0 ? [255, 0, 0, 200] : [0, 255, 0, 50]);
      final bytes = rgbaToArgb8565Bytes(rgba, 2, 1);
      expect(bytes.length, 2 * 1 * 3);
      // Red = 0xF800 → lo 0x00, hi 0xF8, alpha 200.
      expect(bytes[0], 0x00);
      expect(bytes[1], 0xF8);
      expect(bytes[2], 200);
      // Green = 0x07E0 → lo 0xE0, hi 0x07, alpha 50.
      expect(bytes[3], 0xE0);
      expect(bytes[4], 0x07);
      expect(bytes[5], 50);
    });
  });

  group('buildArgb8565BinAdaptive / decodeArgb8565Bin', () {
    test('uncompressed header + round-trip preserves alpha exactly', () {
      const w = 8, h = 6;
      // A noisy pattern so RLE loses → uncompressed path is chosen.
      final rgba = _rgba(
          w, h, (x, y) => [x * 30, y * 40, (x ^ y) * 20, (x * 8 + y) & 0xFF]);
      final res = buildArgb8565BinAdaptive(rgba, w, h);

      expect(res.compressed, isFalse, reason: 'noisy content should not RLE');
      expect(res.bin.length, 8 + w * h * 3, reason: 'header + raw pixels');
      expect(res.rawSize, 8 + w * h * 3);

      final hdr = ByteData.sublistView(res.bin);
      expect(hdr.getUint8(0), 0x00, reason: 'flags: not compressed');
      expect(hdr.getUint8(1), 1, reason: 'format byte = ARGB8565');
      expect(hdr.getUint16(2, Endian.little), w);
      expect(hdr.getUint16(4, Endian.little), h);

      final dec = decodeArgb8565Bin(res.bin)!;
      expect(dec.width, w);
      expect(dec.height, h);
      // Alpha is stored straight (not quantized), so it must round-trip exactly.
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          expect(_at(dec, x, y)[3], (x * 8 + y) & 0xFF);
        }
      }
    });

    test('solid content compresses (RLE) and decodes identically', () {
      const w = 16, h = 16;
      final rgba = _rgba(w, h, (x, y) => [100, 150, 200, 128]);
      final res = buildArgb8565BinAdaptive(rgba, w, h);

      expect(res.compressed, isTrue, reason: 'a solid fill should RLE well');
      expect(res.rleSize, lessThan(res.rawSize));
      // imdc byte0 encodes pixel_bytes = BYTES_3 (1) in bits 6-7 with RLE
      // feature_1 = 1: (1<<2) | (1<<6) = 0x44.
      expect(res.bin[8], 0x44, reason: 'imdc algorithmType: RLE + BYTES_3');

      final dec = decodeArgb8565Bin(res.bin)!;
      expect(dec.width, w);
      expect(dec.height, h);
      final p = _at(dec, 7, 9);
      expect(p[3], 128, reason: 'alpha exact');
      // Colour is 565-quantized then expanded; assert it matches a raw-encoded
      // decode of the same source (encoder self-consistency).
      final rawDec = decodeArgb8565Bin((buildArgb8565BinAdaptive(
              _rgba(1, 1, (x, y) => [100, 150, 200, 128]), 1, 1))
          .bin)!;
      expect(p.sublist(0, 3), _at(rawDec, 0, 0).sublist(0, 3));
    });

    test('raw and RLE encodings decode to the same pixels', () {
      const w = 12, h = 10;
      // Blocky content: RLE-friendly runs but with variety across lines.
      final rgba = _rgba(w, h,
          (x, y) => [(x ~/ 3) * 60, (y ~/ 2) * 50, 80, x < 6 ? 255 : 100]);
      final res = buildArgb8565BinAdaptive(rgba, w, h);
      final decAdaptive = decodeArgb8565Bin(res.bin)!;

      // Force the uncompressed encoding by feeding fully-unique pixels is hard;
      // instead compare the adaptive result against a decode of the raw bytes
      // reconstructed from the pixel converter directly.
      final rawPixels = rgbaToArgb8565Bytes(rgba, w, h);
      // Rebuild an uncompressed bin by hand: 8-byte header (flags 0, fmt 1) + px.
      final manual = Uint8List(8 + rawPixels.length);
      final mdv = ByteData.view(manual.buffer);
      mdv.setUint8(0, 0);
      mdv.setUint8(1, 1);
      mdv.setUint16(2, w, Endian.little);
      mdv.setUint16(4, h, Endian.little);
      manual.setRange(8, manual.length, rawPixels);
      final decManual = decodeArgb8565Bin(manual)!;

      expect(decAdaptive.rgba, equals(decManual.rgba));
    });

    test('decodeArgb8565Bin rejects short/invalid input', () {
      expect(decodeArgb8565Bin(Uint8List(4)), isNull);
      final bad = Uint8List(8); // zero width/height
      expect(decodeArgb8565Bin(bad), isNull);
    });
  });
}
