import 'dart:typed_data';

/// CRC-16/ARC: poly A001 reflected, init 0000, xorout 0000.
int wsCrc16(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xa001 : crc >> 1;
    }
  }
  return crc;
}

class WSFrame {
  WSFrame(
      {required this.seq,
      List<int> payload = const [],
      this.isAck = false,
      this.isError = false})
      : payload = Uint8List.fromList(payload).asUnmodifiableView() {
    RangeError.checkValueInInterval(seq, 0, 65535, 'seq');
    if (payload.length > 65535 ||
        (isAck && payload.isNotEmpty) ||
        (isError && !isAck)) {
      throw ArgumentError('invalid frame');
    }
  }
  final int seq;
  final Uint8List payload;
  final bool isAck, isError;
  Uint8List encode() {
    final crc = wsCrc16(payload);
    return Uint8List.fromList([
      0xab,
      (isAck ? 0x10 : 0) | (isError ? 0x20 : 0),
      payload.length >> 8,
      payload.length & 255,
      crc >> 8,
      crc & 255,
      seq >> 8,
      seq & 255,
      ...payload
    ]);
  }

  static bool validHeader(List<int> bytes, int maxPayloadLength) {
    if (bytes.length < 8 ||
        bytes[0] != 0xab ||
        (bytes[1] != 0 && bytes[1] != 0x10 && bytes[1] != 0x30)) {
      return false;
    }
    final length = (bytes[2] << 8) | bytes[3];
    return length <= maxPayloadLength &&
        (bytes[1] == 0 || (length == 0 && bytes[4] == 0 && bytes[5] == 0));
  }

  static WSFrame decode(Uint8List bytes) {
    if (!validHeader(bytes, 65535) ||
        bytes.length != 8 + ((bytes[2] << 8) | bytes[3])) {
      throw const FormatException('invalid L1 header/length');
    }
    final payload = bytes.sublist(8);
    if (wsCrc16(payload) != ((bytes[4] << 8) | bytes[5])) {
      throw const FormatException('CRC mismatch');
    }
    return WSFrame(
        seq: (bytes[6] << 8) | bytes[7],
        payload: payload,
        isAck: bytes[1] & 0x10 != 0,
        isError: bytes[1] & 0x20 != 0);
  }
}
