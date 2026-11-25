import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ota/device_probe.dart';
import 'package:honeybox/services/ota/firmware_inspection.dart';
import 'package:honeybox/services/ota/ota_preflight.dart';
import 'package:honeybox/services/ota/rtl87x3g_firmware_image.dart';
import 'package:honeybox/services/ota/rtl87x3g_firmware_parser.dart';

Uint8List buildImage({int imageId = rtl87x3gMcuAppImageId, int ic = 0x13}) {
  const payload = 32;
  final bytes = Uint8List(rtl87x3gImageHeaderSize + payload);
  bytes.setRange(0, 6, 'IMGHDR'.codeUnits);
  final data = ByteData.sublistView(bytes);
  data.setUint32(rtl87x3gControlHeaderOffset, 0x8000, Endian.little);
  bytes[rtl87x3gControlHeaderOffset + 4] = ic;
  data.setUint16(rtl87x3gControlHeaderOffset + 6, imageId, Endian.little);
  data.setUint32(rtl87x3gControlHeaderOffset + 12, payload, Endian.little);
  data.setUint64(280, (3 << 56) | (2 << 48) | (1 << 32), Endian.little);
  return bytes;
}

Uint8List buildMpPackage(Uint8List image) {
  final header = Uint8List(512);
  var offset = 0;
  void tlv(int id, List<int> value) {
    header[offset++] = id & 0xff;
    header[offset++] = id >> 8;
    header[offset++] = value.length;
    header.setRange(offset, offset + value.length, value);
    offset += value.length;
  }

  tlv(0x0001, const [0x01, 0x00]);
  tlv(0x0012, const [rtl87x3gMcuAppImageId & 0xff, rtl87x3gMcuAppImageId >> 8]);
  final size = image.length;
  tlv(0x0014, [
    size & 0xff,
    (size >> 8) & 0xff,
    (size >> 16) & 0xff,
    size >> 24,
  ]);
  return Uint8List.fromList([...header, ...image]);
}

void main() {
  test('parses a bare RTL87x3G APP image', () {
    final image = Rtl87x3gFirmwareImage.parse(buildImage());
    expect(image.imageId, rtl87x3gMcuAppImageId);
    expect(image.icType, rtl87x3gIcType);
    expect(image.payloadLength, 32);
    expect(image.imageSize, rtl87x3gImageHeaderSize + 32);
    expect(image.version, 0x00010203);
    expect(image.controlHeader.length, 16);
  });

  test('rejects a non-MCUAPP image', () {
    expect(
      () => Rtl87x3gFirmwareImage.parse(buildImage(imageId: 0x2700)),
      throwsFormatException,
    );
  });

  test('calculates the RTL DFU block checksum', () {
    expect(
      Rtl87x3gFirmwareImage.blockChecksum([0x12, 0x34, 0x56, 0x78]),
      0x444c,
    );
  });

  test('parses the app_MP package and extracts the DFU image', () {
    final package = Rtl87x3gOtaPackage.parse(buildMpPackage(buildImage()));
    expect(package.image.imageId, rtl87x3gMcuAppImageId);
    expect(package.mpImageId, rtl87x3gMcuAppImageId);
    expect(package.mpImageSize, rtl87x3gImageHeaderSize + 32);
  });

  test('parser accepts matching device and reports target version', () async {
    final directory = await Directory.systemTemp.createTemp('rtl87x3g-ota-');
    final file = File('${directory.path}/app.bin');
    await file.writeAsBytes(buildMpPackage(buildImage()));
    addTearDown(() => directory.delete(recursive: true));
    final result = await const Rtl87x3gFirmwareParser().parse(
      file.path,
      const DeviceCapabilities(
        confirmed: true,
        icType: rtl87x3gIcType,
        currentVersion: 1,
        batteryPercent: 80,
      ),
    );
    expect(result.type, 'Realtek RTL87x3G');
    expect(
      result.checks.firstWhere((c) => c.id == 'format').status,
      OtaCheckStatus.pass,
    );
    expect(
      result.checks.firstWhere((c) => c.id == 'compatibility').status,
      OtaCheckStatus.pass,
    );
    final images = (result.rawStatus as Map)['images'] as List;
    expect((images.single as Map)['version'], 0x00010203);
  });

  test('extended FFF1 layout exposes RTL8773G chip type', () {
    final bytes = Uint8List(16)
      ..[0] = rtl87x3gIcType
      ..[1] = 0x0a
      ..[2] = 0x0d
      ..[4] = 0x80
      ..[10] = 196;
    final info = OtaDeviceInfoRecord.parse(bytes);
    expect(info?.icType, rtl87x3gIcType);
    expect(info?.tempBankSizeBytes, 0x80000);
  });
}
