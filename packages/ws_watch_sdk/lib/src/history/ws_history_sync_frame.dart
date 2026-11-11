import 'dart:typed_data';

/// One unsolicited `0x05` field observed during [WSWatchSession.syncHealthData].
final class WSHistorySyncFrame {
  const WSHistorySyncFrame({required this.key, required this.value});

  final int key;
  final Uint8List value;
}
