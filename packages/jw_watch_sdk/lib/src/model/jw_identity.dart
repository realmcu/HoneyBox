import 'dart:typed_data';

/// Stable 32-byte protocol identity used for JW login and first binding.
///
/// The SDK deliberately does not silently create a new identity: replacing an
/// existing identity can make a previously bound device reject the user.
final class JWIdentity {
  factory JWIdentity(String value) {
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'value', 'Expected 32 hex characters');
    }
    final normalized = value.toLowerCase();
    return JWIdentity._(normalized);
  }

  JWIdentity._(this.value)
      : bytes = Uint8List.fromList(value.codeUnits).asUnmodifiableView();

  final String value;
  final Uint8List bytes;
}
