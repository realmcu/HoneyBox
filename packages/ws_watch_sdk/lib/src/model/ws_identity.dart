import 'dart:typed_data';

/// Stable identity for WS 0x03 login/bind (32-byte ASCII wire, spec §用户 ID).
final class WSIdentity {
  static const int wireAsciiCapacity = 32;

  factory WSIdentity(String value) => WSIdentity._(_normalize(value));

  WSIdentity._(this.value)
      : wire = Uint8List(wireAsciiCapacity)
          ..setRange(0, value.codeUnits.length, value.codeUnits);

  final String value;
  final Uint8List wire;

  static String _normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, 'value', 'userId must not be empty');
    }
    final units = trimmed.codeUnits;
    if (units.length > wireAsciiCapacity) {
      throw ArgumentError.value(
          raw, 'value', 'userId must fit in $wireAsciiCapacity ASCII bytes');
    }
    for (final unit in units) {
      if (unit < 0x20 || unit > 0x7e) {
        throw ArgumentError.value(
            raw, 'value', 'userId must be printable ASCII for WS bind');
      }
    }
    return trimmed;
  }
}
