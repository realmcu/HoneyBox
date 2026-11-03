import 'dart:typed_data';

enum WatchFrameDirection { tx, rx }

enum WatchFrameKind {
  data,
  ack,
  errAck,
  retry,
  chunk,
  crcError,
  assembleTimeout,
  invalidHeader,
  sequenceConflict
}

/// L1 observation. Protocol names and key views are added by debug only.
class WatchFrameEvent {
  WatchFrameEvent(
      {required this.direction,
      required this.kind,
      required List<int> raw,
      this.seq,
      this.requestId,
      this.traceId,
      required this.connectionGeneration})
      : raw = Uint8List.fromList(raw).asUnmodifiableView(),
        time = DateTime.now();
  final DateTime time;
  final int connectionGeneration;
  final String? requestId, traceId;
  final WatchFrameDirection direction;
  final WatchFrameKind kind;
  final int? seq;
  final Uint8List raw;
}
