import 'dart:typed_data';

const int rtl87x3gImageHeaderSize = 0x400;
const int rtl87x3gControlHeaderOffset = 196;
const int rtl87x3gControlHeaderSize = 16;
const int rtl87x3gMcuAppImageId = 0x2793;
const int rtl87x3gIcType = 0x13;
const int rtl87x3gAppBankSize = 0x180000;

/// A bare RTL87x3G APP image accepted by the normal-mode DFU service.
///
/// The file already contains the 1 KiB `IMGHDR` image header. It is not the
/// 512-byte MP wrapper used by the existing RTL8762/S200 path.
final class Rtl87x3gFirmwareImage {
  final Uint8List bytes;
  final int controlFlags;
  final int icType;
  final int secureVersion;
  final int imageId;
  final int headerLength;
  final int payloadLength;
  final int imageSize;
  final int version;
  final int version64;
  final int commitId;

  const Rtl87x3gFirmwareImage({
    required this.bytes,
    required this.controlFlags,
    required this.icType,
    required this.secureVersion,
    required this.imageId,
    required this.headerLength,
    required this.payloadLength,
    required this.imageSize,
    required this.version,
    required this.version64,
    required this.commitId,
  });

  Uint8List get controlHeader => Uint8List.fromList(
        bytes.sublist(
          rtl87x3gControlHeaderOffset,
          rtl87x3gControlHeaderOffset + rtl87x3gControlHeaderSize,
        ),
      );

  static Rtl87x3gFirmwareImage parse(Uint8List source) {
    if (source.length < rtl87x3gImageHeaderSize) {
      throw const FormatException('固件小于 RTL87x3G 的 1 KiB 镜像头');
    }
    if (String.fromCharCodes(source.sublist(0, 6)) != 'IMGHDR') {
      throw const FormatException('不是 RTL87x3G 的 IMGHDR 固件');
    }
    final data = ByteData.sublistView(source);
    final flags = data.getUint32(rtl87x3gControlHeaderOffset, Endian.little);
    final ic = source[rtl87x3gControlHeaderOffset + 4];
    final secure = source[rtl87x3gControlHeaderOffset + 5];
    final imageId = data.getUint16(
      rtl87x3gControlHeaderOffset + 6,
      Endian.little,
    );
    final headerLength = data.getUint32(
      rtl87x3gControlHeaderOffset + 8,
      Endian.little,
    );
    final payload = data.getUint32(
      rtl87x3gControlHeaderOffset + 12,
      Endian.little,
    );
    if (imageId != rtl87x3gMcuAppImageId) {
      throw FormatException(
        '镜像 ID 不是 MCUAPP(0x${rtl87x3gMcuAppImageId.toRadixString(16)})：'
        '0x${imageId.toRadixString(16)}',
      );
    }
    if (ic != rtl87x3gIcType) {
      throw FormatException(
        '固件芯片类型不是 RTL8773G(0x13)：0x${ic.toRadixString(16)}',
      );
    }
    final expectedSize = rtl87x3gImageHeaderSize + payload;
    if (expectedSize != source.length) {
      throw FormatException('镜像长度不一致：控制头要求 $expectedSize，文件为 ${source.length}');
    }
    if (source.length > rtl87x3gAppBankSize) {
      throw FormatException(
        '镜像超过 eBadge APP bank 容量：${source.length} > $rtl87x3gAppBankSize',
      );
    }
    final version64 = data.getUint64(280, Endian.little);
    final version = ((version64 >> 56) & 0xff) |
        (((version64 >> 48) & 0xff) << 8) |
        (((version64 >> 32) & 0xffff) << 16);
    final commitId = data.getUint32(288, Endian.little);
    return Rtl87x3gFirmwareImage(
      bytes: source,
      controlFlags: flags,
      icType: ic,
      secureVersion: secure,
      imageId: imageId,
      headerLength: headerLength,
      payloadLength: payload,
      imageSize: source.length,
      version: version,
      version64: version64,
      commitId: commitId,
    );
  }

  static int blockChecksum(List<int> block) {
    if (block.length.isOdd) {
      throw const FormatException('DFU 数据块长度必须为偶数');
    }
    var checksum = 0;
    for (var i = 0; i < block.length; i += 2) {
      checksum ^= (block[i] << 8) | block[i + 1];
    }
    return checksum & 0xffff;
  }
}

/// Realtek MP-wrapped OTA file (`app_MP-*.bin`).
///
/// The 512-byte MP header carries package metadata; the actual DFU image is
/// the complete IMGHDR image beginning at offset 512.
final class Rtl87x3gOtaPackage {
  final Uint8List fileBytes;
  final Rtl87x3gFirmwareImage image;
  final int mpImageId;
  final int mpImageSize;
  final Map<int, List<int>> tlvs;

  const Rtl87x3gOtaPackage({
    required this.fileBytes,
    required this.image,
    required this.mpImageId,
    required this.mpImageSize,
    required this.tlvs,
  });

  static Rtl87x3gOtaPackage parse(Uint8List source) {
    const mpHeaderSize = 512;
    if (source.length < mpHeaderSize + rtl87x3gImageHeaderSize) {
      throw const FormatException('MP OTA 文件过短');
    }
    if (source[0] != 0x01 || source[1] != 0x00) {
      throw const FormatException('不是 Realtek MP 包：缺少 01 00 头');
    }
    final tlvs = <int, List<int>>{};
    var offset = 0;
    var terminated = false;
    while (offset + 2 <= mpHeaderSize) {
      final id = source[offset] | (source[offset + 1] << 8);
      if (id == 0) {
        terminated = true;
        break;
      }
      if (offset + 3 > mpHeaderSize) {
        throw const FormatException('MP TLV 头截断');
      }
      final length = source[offset + 2];
      if (offset + 3 + length > mpHeaderSize || tlvs.containsKey(id)) {
        throw FormatException('MP TLV 长度越界或重复：0x${id.toRadixString(16)}');
      }
      tlvs[id] = List<int>.unmodifiable(
        source.sublist(offset + 3, offset + 3 + length),
      );
      offset += 3 + length;
    }
    if (!terminated) {
      throw const FormatException('MP TLV 缺少结束标记');
    }
    int number(int id, int expectedLength) {
      final value = tlvs[id];
      if (value == null || value.length != expectedLength) {
        throw FormatException('MP 字段 0x${id.toRadixString(16)} 缺失或长度错误');
      }
      var result = 0;
      for (var i = 0; i < value.length; i++) {
        result |= value[i] << (8 * i);
      }
      return result;
    }

    final mpImageId = number(0x12, 2);
    final mpImageSize = number(0x14, 4);
    if (mpImageSize != source.length - mpHeaderSize) {
      throw FormatException(
        'MP ImageSize=$mpImageSize，实际镜像=${source.length - mpHeaderSize}',
      );
    }
    final imageBytes = Uint8List.sublistView(source, mpHeaderSize);
    final image = Rtl87x3gFirmwareImage.parse(imageBytes);
    if (mpImageId != image.imageId) {
      throw FormatException(
        'MP ImageID=0x${mpImageId.toRadixString(16)} 与镜像 '
        '0x${image.imageId.toRadixString(16)} 不一致',
      );
    }
    return Rtl87x3gOtaPackage(
      fileBytes: source,
      image: image,
      mpImageId: mpImageId,
      mpImageSize: mpImageSize,
      tlvs: Map.unmodifiable(tlvs),
    );
  }
}
