import 'dart:typed_data';

import 'address.dart';
import 'status.dart';

class WSProtocolEntry {
  const WSProtocolEntry(
      {required this.address,
      required this.name,
      required this.specRef,
      this.status = WSProtocolStatus.active,
      this.isReply = false,
      this.reason,
      this.factoryOnly = false,
      this.maxRetries});
  final WSProtocolAddress address;
  final String name, specRef;
  final WSProtocolStatus status;
  final bool isReply, factoryOnly;
  final String? reason;
  final int? maxRetries;
}

class WSCommand<T> {
  const WSCommand(
      {required this.request, required this.encodeData, this.maxRetries});
  final WSProtocolEntry request;
  final Uint8List Function(T value) encodeData;
  final int? maxRetries;
}

class WSQuery<T, R> {
  const WSQuery(
      {required this.request,
      required this.reply,
      required this.encodeData,
      required this.decodeData,
      this.replyTimeout});
  final WSProtocolEntry request, reply;
  final Uint8List Function(T value) encodeData;
  final R Function(Uint8List data) decodeData;
  final Duration? replyTimeout;
}

class WSReport<T> {
  const WSReport({required this.entry, required this.decodeData});
  final WSProtocolEntry entry;
  final T Function(Uint8List data) decodeData;
}
