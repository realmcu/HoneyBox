import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../model/frame.dart';
import 'frame.dart';

class WSFrameAssembler {
  WSFrameAssembler(
      {required this.timeout,
      required this.maxPayloadLength,
      required this.onFrame,
      required this.onError});
  final Duration timeout;
  final int maxPayloadLength;
  final void Function(WSFrame frame, Uint8List raw) onFrame;
  final void Function(WSFrameKind kind, Uint8List raw, int? seq) onError;
  final List<int> _buffer = [];
  Timer? _timer;
  bool _disposed = false;
  int get bufferedBytes => _buffer.length;

  void add(Uint8List chunk) {
    if (_disposed || chunk.isEmpty) return;
    _timer?.cancel();
    // Never retain more than a header plus the configured payload limit.
    var offset = 0;
    while (offset < chunk.length) {
      final count =
          min(chunk.length - offset, maxPayloadLength + 8 - _buffer.length);
      _buffer.addAll(chunk.sublist(offset, offset + count));
      offset += count;
      _drain();
    }
    if (_buffer.isNotEmpty) {
      _timer = Timer(timeout, () {
        final raw = Uint8List.fromList(_buffer);
        final seq = WSFrame.validHeader(raw, maxPayloadLength)
            ? (raw[6] << 8) | raw[7]
            : null;
        _buffer.clear();
        onError(WSFrameKind.assembleTimeout, raw, seq);
      });
    }
  }

  void _drain() {
    while (_buffer.isNotEmpty && !_disposed) {
      if (_buffer.first != 0xab) {
        _buffer.removeAt(0);
        continue;
      }
      if (_buffer.length < 8) return;
      if (!WSFrame.validHeader(_buffer, maxPayloadLength)) {
        final bad = Uint8List.fromList(_buffer.take(8).toList());
        _buffer.removeAt(0);
        onError(WSFrameKind.invalidHeader, bad, null);
        continue;
      }
      final size = 8 + ((_buffer[2] << 8) | _buffer[3]);
      if (_buffer.length < size) return;
      final raw = Uint8List.fromList(_buffer.sublist(0, size));
      _buffer.removeRange(0, size);
      try {
        onFrame(WSFrame.decode(raw), raw);
      } on FormatException {
        onError(WSFrameKind.crcError, raw, (raw[6] << 8) | raw[7]);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _buffer.clear();
  }
}
