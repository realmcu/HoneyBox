import 'dart:typed_data';

/// Honey L2 wire layout per [HoneyProtocol architecture](../../../../../../HoneyProtocol/docs/architecture.rst):
/// 2-byte header (Command + Version nibble), then Key / Length BE / Value units.
final class HoneyL2Message {
  HoneyL2Message({
    required this.command,
    required this.key,
    required Uint8List value,
    this.version = 0,
  }) : value = Uint8List.fromList(value).asUnmodifiableView();

  final int command;
  final int version;
  final int key;
  final Uint8List value;

  Uint8List encode() {
    if (command < 0 || command > 255 || key < 0 || key > 255) {
      throw ArgumentError('command and key must be 0–255');
    }
    if (version < 0 || version > 15) {
      throw ArgumentError('version must be 0–15');
    }
    final length = value.length;
    if (length > 0xFFFF) {
      throw ArgumentError('value too long for L2');
    }
    return Uint8List.fromList([
      command,
      version << 4,
      key,
      length >> 8,
      length & 0xFF,
      ...value,
    ]);
  }

  /// Decodes one or more L2 messages from an L1 payload (may contain multiple KV units).
  static List<HoneyL2Message> decodeAll(Uint8List bytes) {
    if (bytes.length < 2) {
      throw FormatException('L2 payload too short');
    }
    final command = bytes[0];
    final version = bytes[1] >> 4;
    var offset = 2;
    final out = <HoneyL2Message>[];
    while (offset < bytes.length) {
      if (bytes.length - offset < 3) {
        throw FormatException('truncated L2 key header at $offset');
      }
      final key = bytes[offset];
      final length = (bytes[offset + 1] << 8) | bytes[offset + 2];
      offset += 3;
      if (length > bytes.length - offset) {
        throw FormatException('L2 value length $length overflows payload');
      }
      out.add(HoneyL2Message(
        command: command,
        version: version,
        key: key,
        value: bytes.sublist(offset, offset + length),
      ));
      offset += length;
    }
    return out;
  }
}
