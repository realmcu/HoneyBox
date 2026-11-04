import 'dart:typed_data';
import 'package:watch_frame_channel/watch_frame_channel.dart';
import '../config.dart';
import '../errors.dart';
import '../model/frame.dart';
import '../transport/connection.dart';
import 'frame_log.dart';

class WSReceivedPayload {
  WSReceivedPayload(this.seq, this.bytes);
  final int seq;
  final Uint8List bytes;
}

/// WS compatibility facade; L0/L1 is implemented by watch_frame_channel.
class WSLink {
  WSLink(this.connection,
      {this.config = const WSLinkConfig(), this.generation = 1}) {
    config.validate();
    _channel = WatchFrameChannel(
        WatchFramePort(
            received: connection.received,
            disconnected: connection.disconnected,
            maxWriteLength: () => connection.maxWriteLength,
            write: connection.write,
            close: () async {
              try {
                await connection.disconnect();
              } finally {
                await connection.dispose();
              }
            }),
        generation: generation,
        mapError: _mapError,
        config: WatchFrameConfig(
            ackTimeout: config.ackTimeout,
            maxRetries: config.maxRetries,
            chunkWriteTimeout: config.chunkWriteTimeout,
            rxAssembleTimeout: config.rxAssembleTimeout,
            maxPayloadLength: config.maxPayloadLength,
            deduplicationCapacity: config.deduplicationCapacity,
            deduplicationWindow: config.deduplicationWindow));
    payloads = _channel.payloads.map((p) => WSReceivedPayload(p.seq, p.bytes));
    frames = _channel.frames.map((e) => WSLinkEvent(
        direction: WSFrameDirection.values[e.direction.index],
        kind: WSFrameKind.values[e.kind.index],
        raw: e.raw,
        seq: e.seq,
        requestId: e.requestId,
        traceId: e.traceId,
        connectionGeneration: e.connectionGeneration,
        time: e.time));
  }
  final WSTransportConnection connection;
  final WSLinkConfig config;
  final int generation;
  late final WatchFrameChannel _channel;
  late final Stream<WSReceivedPayload> payloads;
  late final Stream<WSLinkEvent> frames;
  Future<Object> get terminated => _channel.terminated;
  bool get isClosed => _channel.isClosed;
  int get bufferedBytes => _channel.bufferedBytes;
  Future<void> send(Uint8List payload,
          {int? maxRetries, String? requestId, String? traceId}) =>
      _channel.send(payload,
          maxRetries: maxRetries, requestId: requestId, traceId: traceId);
  Future<void> close(
          [Object reason = const WSDisconnectedException('link closed')]) =>
      _channel.close(reason);
}

Object _mapError(Object error) {
  if (error is WatchFrameWriteException) return error.cause;
  if (error is! WatchFrameException) return error;
  return switch (error.kind) {
    WatchFrameErrorKind.ackTimeout =>
      WSTimeoutException(WSTimeoutKind.ack, error.message),
    WatchFrameErrorKind.writeTimeout =>
      WSTimeoutException(WSTimeoutKind.write, error.message),
    WatchFrameErrorKind.nack => WSNackException(error.message),
    WatchFrameErrorKind.disconnected => WSDisconnectedException(error.message),
    WatchFrameErrorKind.receive || WatchFrameErrorKind.write =>
      WSOperationException(error.message),
    WatchFrameErrorKind.queueFull => const WSQueueFullException(64),
  };
}
