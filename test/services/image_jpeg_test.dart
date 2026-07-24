import 'dart:typed_data';

import 'package:honeybox/services/image_jpeg.dart';
import 'package:flutter_test/flutter_test.dart';

// A simple opaque RGBA gradient, w*h*4 bytes.
Uint8List _gradient(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  int o = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      rgba[o++] = (x * 255 ~/ (w - 1 < 1 ? 1 : w - 1)) & 0xFF; // R
      rgba[o++] = (y * 255 ~/ (h - 1 < 1 ? 1 : h - 1)) & 0xFF; // G
      rgba[o++] = 128; // B
      rgba[o++] = 0xFF; // A
    }
  }
  return rgba;
}

// Walk JPEG marker segments, returning the SOF0 payload (bytes after its length
// field) and the set of marker bytes seen up to and including SOS.
class _Parsed {
  final Uint8List? sof0;
  final Set<int> markers;
  final bool endsWithEoi;
  _Parsed(this.sof0, this.markers, this.endsWithEoi);
}

_Parsed _walk(Uint8List jpeg, int start) {
  int p = start;
  final markers = <int>{};
  Uint8List? sof0;
  // SOI
  expect(jpeg[p], 0xFF);
  expect(jpeg[p + 1], 0xD8);
  p += 2;
  while (p + 1 < jpeg.length) {
    expect(jpeg[p], 0xFF, reason: 'expected marker prefix at $p');
    final int marker = jpeg[p + 1];
    p += 2;
    markers.add(marker);
    if (marker == 0xDA) break; // SOS — entropy data follows
    final int segLen = (jpeg[p] << 8) | jpeg[p + 1];
    if (marker == 0xC0) {
      sof0 = jpeg.sublist(p + 2, p + segLen);
    }
    p += segLen;
  }
  final bool eoi =
      jpeg[jpeg.length - 2] == 0xFF && jpeg[jpeg.length - 1] == 0xD9;
  return _Parsed(sof0, markers, eoi);
}

void main() {
  test('buildImageJpegBin writes the 16-byte device header', () {
    const w = 240, h = 200; // non-square, height not a multiple of 16
    final bytes = buildImageJpegBin(_gradient(w, h), w, h, quality: 80);
    expect(kJpegHeaderBytes, 16);
    final hdr = ByteData.sublistView(bytes, 0, 16);
    expect(hdr.getUint8(0), 0x00, reason: 'flags = 0');
    expect(hdr.getUint8(1), 0x0C, reason: 'type = 12 (JPEG)');
    expect(hdr.getUint16(2, Endian.little), w, reason: 'width LE');
    expect(hdr.getUint16(4, Endian.little), h, reason: 'height LE');
    expect(hdr.getUint8(6), 0x00, reason: 'version = 0');
    expect(hdr.getUint8(7), 0x00, reason: 'rsvd2 = 0');
    expect(hdr.getUint32(12, Endian.little), 0, reason: 'alignment = 0');
    // JPEG data size (bytes 8..11) == the actual trailing JPEG length.
    final int jpegSize = hdr.getUint32(8, Endian.little);
    expect(jpegSize, bytes.length - 16);
    // Payload is a JPEG: SOI right after the header, EOI at the very end.
    expect(bytes[16], 0xFF);
    expect(bytes[17], 0xD8);
    expect(bytes[16 + jpegSize - 2], 0xFF);
    expect(bytes[16 + jpegSize - 1], 0xD9);
  });

  test('encodes a baseline JFIF JPEG with 4:2:0 sampling (Y = 2x2)', () {
    final jpeg =
        encodeBaselineJpegYuv420(_gradient(48, 48), 48, 48, quality: 75);
    final parsed = _walk(jpeg, 0);

    expect(parsed.endsWithEoi, isTrue, reason: 'must end with EOI (FFD9)');
    expect(parsed.markers.contains(0xDB), isTrue, reason: 'has DQT');
    expect(parsed.markers.contains(0xC0), isTrue, reason: 'baseline SOF0');
    expect(parsed.markers.contains(0xC4), isTrue, reason: 'has DHT');
    expect(parsed.markers.contains(0xDA), isTrue, reason: 'has SOS');
    // Progressive (C2) must NOT be present — baseline only.
    expect(parsed.markers.contains(0xC2), isFalse);

    final sof = parsed.sof0!;
    // [precision][H hi/lo][W hi/lo][Nf][ (id,samp,tq) x Nf ]
    expect(sof[0], 8, reason: '8-bit precision');
    final int height = (sof[1] << 8) | sof[2];
    final int width = (sof[3] << 8) | sof[4];
    expect(width, 48);
    expect(height, 48);
    expect(sof[5], 3, reason: '3 components (YCbCr)');
    // Component 1 (Y): sampling factor 0x22 == H2 V2 → 4:2:0.
    expect(sof[7], 0x22, reason: 'Y must be 2x2 subsampled (4:2:0)');
    // Cb/Cr: 1x1.
    expect(sof[10], 0x11);
    expect(sof[13], 0x11);
  });

  test('handles non-multiple-of-16 dimensions (edge MCU padding)', () {
    // 360 is not a multiple of 16 → last MCU column/row is padded.
    final jpeg =
        encodeBaselineJpegYuv420(_gradient(360, 360), 360, 360, quality: 60);
    final parsed = _walk(jpeg, 0);
    expect(parsed.endsWithEoi, isTrue);
    final sof = parsed.sof0!;
    expect((sof[1] << 8) | sof[2], 360);
    expect((sof[3] << 8) | sof[4], 360);
  });

  test('lower quality yields a smaller file', () {
    final rgba = _gradient(64, 64);
    final hi = encodeBaselineJpegYuv420(rgba, 64, 64, quality: 95);
    final lo = encodeBaselineJpegYuv420(rgba, 64, 64, quality: 20);
    expect(lo.length, lessThan(hi.length));
  });

  test('isImageJpegBin / imageJpegPayload round-trip the container', () {
    const w = 96, h = 64;
    final bin = buildImageJpegBin(_gradient(w, h), w, h, quality: 70);
    expect(isImageJpegBin(bin), isTrue);

    // Payload is the header-stripped JFIF stream: starts SOI, ends EOI, and its
    // length equals both the size field and (total - header).
    final payload = imageJpegPayload(bin)!;
    expect(payload.length, bin.length - kJpegHeaderBytes);
    expect(
        payload.length, ByteData.sublistView(bin).getUint32(8, Endian.little));
    expect(payload[0], 0xFF);
    expect(payload[1], 0xD8);
    expect(payload[payload.length - 2], 0xFF);
    expect(payload[payload.length - 1], 0xD9);
  });

  test('JPEG detection rejects an RGB565 .bin and short buffers', () {
    // An RGB565 gui_rgb_data_head_t carries format 0 at offset 1, so even if its
    // bytes 16/17 happened to be FFD8 it must not be taken for JPEG.
    final rgb565 = Uint8List(64);
    rgb565[1] = 0x00; // format = RGB565
    rgb565[16] = 0xFF;
    rgb565[17] = 0xD8;
    expect(isImageJpegBin(rgb565), isFalse);
    expect(imageJpegPayload(rgb565), isNull);

    // Right type byte but no room for the SOI marker → not a container.
    final truncated = Uint8List(kJpegHeaderBytes);
    truncated[1] = 0x0C;
    expect(isImageJpegBin(truncated), isFalse);
    expect(imageJpegPayload(truncated), isNull);
  });
}
