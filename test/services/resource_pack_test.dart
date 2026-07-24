import 'dart:typed_data';

import 'package:honeybox/services/resource_pack.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  group('buildResourcePack', () {
    test('writes the header, offset table and payloads in order', () {
      final a = _bytes([0xAA, 0xAB, 0xAC]); // 3 bytes
      final b = _bytes([0xB0, 0xB1, 0xB2, 0xB3, 0xB4]); // 5 bytes
      final thumb = _bytes([0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6]); // 7

      final pack = buildResourcePack(
        type: ResourceType.image,
        bgColor: 0xFF123456, // alpha byte must be stripped to 0
        resources: [a, b],
        thumbnail: thumb,
      );

      const int num = 3; // a, b, thumbnail
      const int headerBytes =
          kResourcePackHeaderBytes + num * 4; // 10 + 12 = 22
      const int total = headerBytes + 3 + 5 + 7; // 37

      expect(pack.length, total);
      final dv = ByteData.sublistView(pack);
      expect(dv.getUint8(0), ResourceType.image, reason: 'type');
      expect(dv.getUint8(1), num, reason: 'resource_num counts the thumbnail');
      expect(dv.getUint32(2, Endian.little), 0x00123456,
          reason: 'bg_color u32 LE, alpha byte forced to 0');
      expect(dv.getUint32(6, Endian.little), total,
          reason: 'size = whole package');

      // offset[] — a at headerBytes, then contiguous.
      expect(dv.getUint32(10, Endian.little), headerBytes); // 22
      expect(dv.getUint32(14, Endian.little), headerBytes + 3); // 25
      expect(dv.getUint32(18, Endian.little), headerBytes + 8); // 30

      // Payloads land at their offsets.
      expect(pack.sublist(22, 25), equals(a));
      expect(pack.sublist(25, 30), equals(b));
      expect(pack.sublist(30, 37), equals(thumb));
    });

    test('a lone thumbnail still forms a 1-resource package', () {
      final thumb = _bytes([1, 2, 3, 4]);
      final pack = buildResourcePack(
        type: ResourceType.danmaku,
        bgColor: 0,
        resources: const [],
        thumbnail: thumb,
      );
      final parsed = parseResourcePack(pack)!;
      expect(parsed.resourceNum, 1);
      expect(parsed.thumbnail, equals(thumb));
    });

    test('throws when resource_num would overflow the u8 field', () {
      final many = List<Uint8List>.generate(255, (_) => Uint8List(0));
      expect(
        () => buildResourcePack(
          type: ResourceType.image,
          bgColor: 0,
          resources: many, // + thumbnail = 256
          thumbnail: Uint8List(1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('parseResourcePack', () {
    test('round-trips a built package', () {
      final a = _bytes([10, 20, 30]);
      final b = _bytes([40]);
      final thumb = _bytes([50, 60, 70, 80]);
      final pack = buildResourcePack(
        type: ResourceType.video,
        bgColor: 0x11ABCDEF, // alpha byte must be stripped to 0
        resources: [a, b],
        thumbnail: thumb,
      );

      final parsed = parseResourcePack(pack)!;
      expect(parsed.type, ResourceType.video);
      expect(parsed.bgColor, 0x00ABCDEF);
      expect(parsed.size, pack.length);
      expect(parsed.resourceNum, 3);
      expect(parsed.resources[0], equals(a));
      expect(parsed.resources[1], equals(b));
      expect(parsed.resources[2], equals(thumb));
      expect(parsed.thumbnail, equals(thumb));
      // Offset table: header = 10 + 3*4 = 22, then a(3B)@22, b(1B)@25, thumb@26.
      expect(parsed.offsets, equals([22, 25, 26]));
    });

    test('rejects a truncated buffer and a wrong size field', () {
      final pack = buildResourcePack(
        type: ResourceType.image,
        bgColor: 0,
        resources: [
          _bytes([1, 2])
        ],
        thumbnail: _bytes([3, 4]),
      );
      // Truncated below the payload end.
      expect(parseResourcePack(pack.sublist(0, pack.length - 1)), isNull);

      // Corrupt the size field so it no longer matches the buffer length.
      final corrupt = Uint8List.fromList(pack);
      ByteData.view(corrupt.buffer)
          .setUint32(6, pack.length + 4, Endian.little);
      expect(parseResourcePack(corrupt), isNull);

      // Too short even for the fixed header.
      expect(parseResourcePack(Uint8List(4)), isNull);
    });
  });
}
