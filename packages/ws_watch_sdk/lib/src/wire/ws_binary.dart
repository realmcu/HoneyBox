import 'dart:convert';
import 'dart:typed_data';

abstract final class WSBinary {
  static Uint8List u16(int value) {
    requireRange(value, 0, 0xffff, 'value');
    final out = ByteData(2)..setUint16(0, value);
    return out.buffer.asUint8List();
  }

  static Uint8List u32(int value) {
    requireRange(value, 0, 0xffffffff, 'value');
    final out = ByteData(4)..setUint32(0, value);
    return out.buffer.asUint8List();
  }

  static int readU16(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes).getUint16(offset);

  static int readU32(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes).getUint32(offset);

  static Uint8List utf8Bytes(String value, {required int maxBytes}) {
    final bytes = utf8.encode(value);
    if (bytes.length > maxBytes) {
      throw ArgumentError.value(
          value, 'value', 'UTF-8 length exceeds $maxBytes');
    }
    return Uint8List.fromList(bytes);
  }

  static String utf8String(Uint8List value) =>
      utf8.decode(value, allowMalformed: false);

  static void requireLength(Uint8List value, int minimum, String label) {
    if (value.length < minimum) {
      throw FormatException('$label requires at least $minimum bytes');
    }
  }

  static void requireRange(int value, int min, int max, String label) {
    if (value < min || value > max) {
      throw ArgumentError.value(value, label, 'expected $min..$max');
    }
  }
}
