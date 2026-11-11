import 'dart:async';

import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport/watch_transport.dart';

import '../config/ws_config.dart';
import '../debug/ws_debug_log.dart';
import '../model/ws_error.dart';
import '../honey/honey_l2.dart';

final class WSLink {
  WSLink(this.connection, {WSLinkConfig config = const WSLinkConfig()})
      : _channel = WatchFrameChannel(
          WatchFramePort.fromConnection(connection),
          profile: WatchFrameProfile.ws,
          config: WatchFrameConfig(
            ackTimeout: config.ackTimeout,
            maxRetries: config.maxRetries,
            chunkWriteTimeout: config.chunkWriteTimeout,
            rxAssembleTimeout: config.rxAssembleTimeout,
            maxPayloadLength: config.maxPayloadLength,
          ),
          mapError: _mapFrameError,
        );

  final WatchTransportConnection connection;
  final WatchFrameChannel _channel;
  final _failures = StreamController<WSException>.broadcast(sync: true);
  final _incoming = StreamController<HoneyL2Message>.broadcast(sync: true);
  StreamSubscription<WatchReceivedPayload>? _payloadSubscription;
  StreamSubscription<WatchFrameEvent>? _wireSubscription;
  WatchFrameSend? _outboundSend;
  _PendingHoneyRequest? _pending;
  Future<void> _tail = Future.value();
  bool _open = false;
  bool _disposed = false;

  Stream<WSException> get failures => _failures.stream;
  Stream<HoneyL2Message> get incoming => _incoming.stream;
  bool get isOpen => _open && !_disposed;

  Future<void> open() async {
    if (_disposed) {
      throw const WSException(WSErrorCode.disposed, 'Link disposed');
    }
    if (_open) return;
    _payloadSubscription = _channel.payloads.listen(_onPayload);
    _wireSubscription = _channel.frames.listen(_onWireFrame);
    unawaited(
      _channel.terminated.then((error) => _fail(_mapFrameError(error))),
    );
    try {
      await connection.connect();
      _open = true;
    } catch (error) {
      _fail(_mapFrameError(error));
      rethrow;
    }
  }

  Future<HoneyL2Message> request(
    HoneyL2Message message, {
    required int replyKey,
    Duration? timeout,
  }) {
    return _enqueue(() => _execute(message, replyKey: replyKey, timeout: timeout));
  }

  Future<HoneyL2Message> requestWhere(
    HoneyL2Message message, {
    required bool Function(HoneyL2Message reply) matches,
    Duration? timeout,
  }) {
    return _enqueue(
      () => _execute(message, matches: matches, timeout: timeout),
    );
  }

  Future<void> send(HoneyL2Message message) {
    return _enqueue(() async {
      WSWatchDebugLog.apiIn(
        'WSLink.send',
        WSWatchDebugLog.describeHoney(message),
      );
      final outbound = _channel.startSend(message.encode());
      _outboundSend = outbound;
      try {
        await outbound.completed;
        WSWatchDebugLog.apiOut('WSLink.send', 'ok seq=${outbound.sequence}');
      } catch (error) {
        WSWatchDebugLog.apiOut('WSLink.send', 'failed $error');
        rethrow;
      } finally {
        if (identical(_outboundSend, outbound)) _outboundSend = null;
      }
    });
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await _wireSubscription?.cancel();
    _wireSubscription = null;
    await _payloadSubscription?.cancel();
    _payloadSubscription = null;
    _pending?.fail(const WSException(
        WSErrorCode.disposed, 'Link closed before reply'));
    _pending = null;
    await _channel.close(
        const WSException(WSErrorCode.disposed, 'link closed'));
    if (_open) {
      try {
        await connection.disconnect();
      } finally {
        await connection.dispose();
      }
    }
    await _failures.close();
    await _incoming.close();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<HoneyL2Message> _execute(
    HoneyL2Message message, {
    int? replyKey,
    bool Function(HoneyL2Message reply)? matches,
    Duration? timeout,
  }) async {
    if (_disposed || !_open) {
      throw const WSException(WSErrorCode.disposed, 'Link not open');
    }
    if (_pending != null) {
      throw const WSException(
          WSErrorCode.unavailable, 'Another Honey request is active');
    }
    WSWatchDebugLog.apiIn(
      'WSLink.request',
      WSWatchDebugLog.describeHoney(message),
    );
    final pending = _PendingHoneyRequest(
      request: message,
      command: message.command,
      replyKey: replyKey,
      matches: matches,
      completer: Completer<HoneyL2Message>(),
    );
    _pending = pending;
    final outbound = _channel.startSend(message.encode());
    _outboundSend = outbound;
    try {
      await outbound.completed;
      return await pending.completer.future.timeout(
        timeout ?? const Duration(seconds: 8),
        onTimeout: () {
          WSWatchDebugLog.apiOut(
            'WSLink.request',
            'timeout ${WSWatchDebugLog.describeHoney(message)}',
          );
          throw const WSException(
              WSErrorCode.businessReplyTimeout, 'Honey reply timed out');
        },
      );
    } catch (error) {
      if (error is! WSException) {
        WSWatchDebugLog.apiOut('WSLink.request', 'failed $error');
      }
      rethrow;
    } finally {
      if (identical(_pending, pending)) _pending = null;
      if (identical(_outboundSend, outbound)) _outboundSend = null;
    }
  }

  void _onWireFrame(WatchFrameEvent event) {
    WSWatchDebugLog.wireFrame(
      event,
      awaitingAckSeq: _outboundSend?.sequence,
    );
  }

  void _onPayload(WatchReceivedPayload payload) {
    List<HoneyL2Message> messages;
    try {
      messages = HoneyL2Message.decodeAll(payload.bytes);
    } on FormatException catch (error) {
      WSWatchDebugLog.l2DecodeFailed(payload.bytes, error, l1Seq: payload.seq);
      return;
    }
    for (final m in messages) {
      if (!_incoming.isClosed) _incoming.add(m);
      final pending = _pending;
      if (pending != null && pending.accepts(m)) {
        WSWatchDebugLog.l2MatchedBusinessReply(
          request: pending.request,
          reply: m,
          outboundSeq: _outboundSend?.sequence,
        );
        pending.completer.complete(m);
        _pending = null;
      }
    }
  }

  void _fail(WSException error) {
    if (_disposed) return;
    _pending?.fail(error);
    _pending = null;
    if (!_failures.isClosed) _failures.add(error);
  }
}

final class _PendingHoneyRequest {
  _PendingHoneyRequest({
    required this.request,
    required this.command,
    this.replyKey,
    this.matches,
    required this.completer,
  });

  final HoneyL2Message request;
  final int command;
  final int? replyKey;
  final bool Function(HoneyL2Message reply)? matches;
  final Completer<HoneyL2Message> completer;

  bool accepts(HoneyL2Message message) {
    if (message.command != command) return false;
    if (matches != null) return matches!(message);
    return message.key == replyKey;
  }

  void fail(WSException error) {
    if (!completer.isCompleted) completer.completeError(error);
  }
}

WSException _mapFrameError(Object error) {
  if (error is WatchFrameWriteException) {
    return WSException(WSErrorCode.writeFailed, error.cause.toString());
  }
  if (error is WatchFrameException) {
    return switch (error.kind) {
      WatchFrameErrorKind.ackTimeout =>
        const WSException(WSErrorCode.ackTimeout, 'ACK timeout'),
      WatchFrameErrorKind.writeTimeout =>
        const WSException(WSErrorCode.writeTimeout, 'Write timeout'),
      WatchFrameErrorKind.nack => const WSException(WSErrorCode.nack, 'NACK'),
      WatchFrameErrorKind.disconnected => const WSException(
          WSErrorCode.transportDisconnected, 'Transport disconnected'),
      WatchFrameErrorKind.receive =>
        WSException(WSErrorCode.receiveFailed, error.message),
      WatchFrameErrorKind.write =>
        WSException(WSErrorCode.writeFailed, error.message),
      WatchFrameErrorKind.queueFull =>
        const WSException(WSErrorCode.queueFull, 'Frame queue full'),
    };
  }
  return WSException(WSErrorCode.transport, error.toString());
}
