import 'dart:typed_data';

/// Confirmed wire variants of this protocol family, not L2/business profiles.
enum WatchFrameProfile {
  ws,
  jw;

  bool get acknowledgeCorruption => this == ws;
  int get maxPayloadLength => this == jw ? 236 : 65535;
  bool acceptsFlags(int flags) => this == ws
      ? flags == 0 || flags == 0x10 || flags == 0x30
      : const [0, 0x10, 0x30, 0x40, 0x50, 0x70].contains(flags);
}

/// CRC-16/ARC: poly A001 reflected, init 0000, xorout 0000.
int watchCrc16(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xa001 : crc >> 1;
    }
  }
  return crc;
}

class WatchFrame {
  WatchFrame(
      {required this.seq,
      List<int> payload = const [],
      this.isAck = false,
      this.isError = false,
      this.noAck = false})
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
  final bool isAck, isError, noAck;
  Uint8List encode() {
    final crc = watchCrc16(payload);
    return Uint8List.fromList([
      0xab,
      (isAck ? 0x10 : 0) | (isError ? 0x20 : 0) | (noAck ? 0x40 : 0),
      payload.length >> 8,
      payload.length & 255,
      crc >> 8,
      crc & 255,
      seq >> 8,
      seq & 255,
      ...payload
    ]);
  }

  static bool validHeader(List<int> bytes, int maxPayloadLength,
      {WatchFrameProfile profile = WatchFrameProfile.ws}) {
    if (bytes.length < 8 ||
        bytes[0] != 0xab ||
        !profile.acceptsFlags(bytes[1])) {
      return false;
    }
    final length = (bytes[2] << 8) | bytes[3];
    return length <= maxPayloadLength &&
        length <= profile.maxPayloadLength &&
        ((bytes[1] & 0x10) == 0 ||
            (length == 0 && bytes[4] == 0 && bytes[5] == 0));
  }

  static WatchFrame decode(Uint8List bytes,
      {WatchFrameProfile profile = WatchFrameProfile.ws,
      int maxPayloadLength = 65535}) {
    if (!validHeader(bytes, maxPayloadLength, profile: profile) ||
        bytes.length != 8 + ((bytes[2] << 8) | bytes[3])) {
      throw const FormatException('invalid L1 header/length');
    }
    final payload = bytes.sublist(8);
    if (watchCrc16(payload) != ((bytes[4] << 8) | bytes[5])) {
      throw const FormatException('CRC mismatch');
    }
    return WatchFrame(
        seq: (bytes[6] << 8) | bytes[7],
        payload: payload,
        isAck: bytes[1] & 0x10 != 0,
        isError: bytes[1] & 0x20 != 0,
        noAck: bytes[1] & 0x40 != 0);
  }
}
