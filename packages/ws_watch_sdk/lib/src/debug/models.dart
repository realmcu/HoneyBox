import 'dart:typed_data';

import '../model/frame.dart';
import '../protocol/address.dart';
import '../protocol/status.dart';

class WSFrameEvent {
  WSFrameEvent(
      {required this.direction,
      required this.kind,
      required List<int> raw,
      this.seq,
      this.requestId,
      this.traceId,
      this.connectionGeneration = 0,
      DateTime? time,
      List<WSKeyView> keys = const []})
      : raw = Uint8List.fromList(raw).asUnmodifiableView(),
        time = time ?? DateTime.now(),
        keys = List.unmodifiable(keys);
  final DateTime time;
  final int connectionGeneration;
  final String? requestId, traceId;
  final WSFrameDirection direction;
  final WSFrameKind kind;
  final int? seq;
  final Uint8List raw;
  final List<WSKeyView> keys;
}

class WSKeyView {
  const WSKeyView(this.address, this.name, this.status);
  final WSProtocolAddress address;
  final String? name;
  final WSProtocolStatus? status;
}

enum WSReportKind {
  notification,
  unsolicitedReply,
  unknown,
  unimplemented,
  dropped,
  reserved,
  decodeError
}

class WSDeviceReport {
  WSDeviceReport(
      {required this.address,
      required this.kind,
      required List<int> data,
      this.value,
      this.error,
      this.connectionGeneration = 0,
      DateTime? time})
      : data = Uint8List.fromList(data).asUnmodifiableView(),
        time = time ?? DateTime.now();
  final WSProtocolAddress? address;
  final WSReportKind kind;
  final Uint8List data;
  final Object? value, error;
  final DateTime time;
  final int connectionGeneration;
}
