import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class WSUserId {
  WSUserId(this.value) {
    if (value.isEmpty ||
        value.length > 32 ||
        value.codeUnits.any((c) => c == 0 || c > 127)) {
      throw ArgumentError.value(
          value, 'userId', 'must contain 1–32 non-NUL ASCII characters');
    }
  }
  factory WSUserId.random() {
    final random = Random.secure();
    return WSUserId(List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join());
  }
  final String value;
  Uint8List encode() => Uint8List(32)..setAll(0, ascii.encode(value));
}
