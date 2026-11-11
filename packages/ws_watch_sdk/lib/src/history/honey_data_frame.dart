import 'dart:typed_data';

/// Splits a `0x05` data Value (`recordLen` 1B + `count` 2B BE + records) into record byte slices.
abstract final class HoneyDataFrame {
  static List<Uint8List> splitValueFrames(Uint8List value) {
    if (value.length < 3) {
      throw FormatException('data frame value too short');
    }
    final recordLen = value[0];
    final count = (value[1] << 8) | value[2];
    final expected = 3 + recordLen * count;
    if (value.length < expected) {
      throw FormatException('data frame length mismatch');
    }
    final out = <Uint8List>[];
    var offset = 3;
    for (var i = 0; i < count; i++) {
      out.add(Uint8List.sublistView(value, offset, offset + recordLen));
      offset += recordLen;
    }
    return out;
  }
}
