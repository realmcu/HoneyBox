import 'dart:typed_data';

/// Stable 32-byte protocol identity used for JW login and first binding.
///
/// The SDK deliberately does not silently create a new identity: replacing an
/// existing identity can make a previously bound device reject the user.
///
/// Callers may pass shorter or longer hex strings; [JWIdentity] normalizes them
/// to exactly 32 lowercase hex digits (left-padded with `0`, excess truncated).
final class JWIdentity {
  static const int wireHexLength = 32;

  static final RegExp _hexDigit = RegExp(r'[0-9a-fA-F]');

  /// Normalizes arbitrary user input into the canonical 32-hex wire form.
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, 'value', 'userId must not be empty');
    }
    final buffer = StringBuffer();
    for (final match in _hexDigit.allMatches(trimmed)) {
      buffer.write(match.group(0));
    }
    var hex = buffer.toString();
    if (hex.isEmpty) {
      throw ArgumentError.value(
        raw,
        'value',
        'userId must contain at least one hex digit (0-9, a-f)',
      );
    }
    if (hex.length > wireHexLength) {
      hex = hex.substring(0, wireHexLength);
    } else if (hex.length < wireHexLength) {
      hex = hex.padLeft(wireHexLength, '0');
    }
    return hex.toLowerCase();
  }

  factory JWIdentity(String value) => JWIdentity._(normalize(value));

  JWIdentity._(this.value)
      : bytes = Uint8List.fromList(value.codeUnits).asUnmodifiableView();

  final String value;
  final Uint8List bytes;
}
