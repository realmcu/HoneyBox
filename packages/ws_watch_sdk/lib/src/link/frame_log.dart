import 'dart:typed_data';

import '../model/frame.dart';

/// Raw L1 observation. Protocol names and key views are added by debug only.
class WSLinkEvent {
  WSLinkEvent(
      {required this.direction,
      required this.kind,
      required List<int> raw,
      this.seq,
      this.requestId,
      this.traceId,
      required this.connectionGeneration,
      DateTime? time})
      : raw = Uint8List.fromList(raw).asUnmodifiableView(),
        time = time ?? DateTime.now();
  final DateTime time;
  final int connectionGeneration;
  final String? requestId, traceId;
  final WSFrameDirection direction;
  final WSFrameKind kind;
  final int? seq;
  final Uint8List raw;
}
