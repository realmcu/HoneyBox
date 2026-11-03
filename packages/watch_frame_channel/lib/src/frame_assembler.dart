import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'observation.dart';
import 'frame.dart';

class WatchFrameAssembler {
  WatchFrameAssembler(
      {required this.timeout,
      required this.maxPayloadLength,
      required this.onFrame,
      required this.onError,
      this.profile = WatchFrameProfile.ws}) {
    if ((timeout != null && timeout! <= Duration.zero) ||
        maxPayloadLength < 0 ||
        maxPayloadLength > profile.maxPayloadLength) {
      throw ArgumentError("invalid assembler configuration");
    }
  }
  final Duration? timeout;
  final WatchFrameProfile profile;
  final int maxPayloadLength;
  final void Function(WatchFrame frame, Uint8List raw) onFrame;
  final void Function(WatchFrameKind kind, Uint8List raw, int? seq) onError;
  final ListQueue<int> _buffer = ListQueue();
  Timer? _timer;
  bool _disposed = false;
  int get bufferedBytes => _buffer.length;

  void add(Uint8List chunk) {
    if (_disposed || chunk.isEmpty) return;
    _timer?.cancel();
    // Never retain more than a header plus the configured payload limit.
    var offset = 0;
    while (offset < chunk.length && !_disposed) {
      final count =
          min(chunk.length - offset, maxPayloadLength + 8 - _buffer.length);
      _buffer.addAll(chunk.sublist(offset, offset + count));
      offset += count;
      _drain();
    }
    if (_buffer.isNotEmpty && !_disposed && timeout != null) {
      _timer = Timer(timeout!, () {
        final raw = Uint8List.fromList(_buffer.toList());
        final seq =
            WatchFrame.validHeader(raw, maxPayloadLength, profile: profile)
                ? (raw[6] << 8) | raw[7]
                : null;
        _buffer.clear();
        onError(WatchFrameKind.assembleTimeout, raw, seq);
      });
    }
  }

  void _drain() {
    while (_buffer.isNotEmpty && !_disposed) {
      if (_buffer.first != 0xab) {
        _buffer.removeFirst();
        continue;
      }
      if (_buffer.length < 8) return;
      final header = _buffer.take(8).toList();
      if (!WatchFrame.validHeader(header, maxPayloadLength, profile: profile)) {
        final bad = Uint8List.fromList(_buffer.take(8).toList());
        _buffer.removeFirst();
        onError(WatchFrameKind.invalidHeader, bad, null);
        continue;
      }
      final size = 8 + ((header[2] << 8) | header[3]);
      if (_buffer.length < size) return;
      final raw = Uint8List.fromList(_buffer.take(size).toList());
      WatchFrame frame;
      try {
        frame = WatchFrame.decode(raw,
            profile: profile, maxPayloadLength: maxPayloadLength);
      } on FormatException {
        // JW historically scans through corrupt bytes for a fresh frame marker.
        for (var i = 0; i < (profile == WatchFrameProfile.jw ? 1 : size); i++) {
          _buffer.removeFirst();
        }
        onError(WatchFrameKind.crcError, raw, (raw[6] << 8) | raw[7]);
        continue;
      }
      for (var i = 0; i < size; i++) {
        _buffer.removeFirst();
      }
      onFrame(frame, raw);
    }
  }

  void clear() {
    _timer?.cancel();
    _buffer.clear();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _buffer.clear();
  }
}
