import 'dart:typed_data';

/// One unsolicited 0x05 field observed during [JWWatchSession.syncHealthData].
final class JWHistorySyncFrame {
  const JWHistorySyncFrame({required this.key, required this.value});

  final int key;
  final Uint8List value;
}
