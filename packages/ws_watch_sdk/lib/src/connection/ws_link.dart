import 'dart:async';

import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport/watch_transport.dart';

import '../config/ws_config.dart';
import '../debug/ws_debug_log.dart';
import '../model/ws_error.dart';
import '../wire/ws_l2_message.dart';

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

  static int _nextSessionId = 0;
  final int _sessionId = ++_nextSessionId;
  String get _logContext =>
      'device=${connection.target.deviceId} session=$_sessionId';
  final WatchTransportConnection connection;
  final WatchFrameChannel _channel;
  final _failures = StreamController<WSException>.broadcast(sync: true);
  final _incoming = StreamController<WSL2Message>.broadcast(sync: true);
  StreamSubscription<WatchReceivedPayload>? _payloadSubscription;
  StreamSubscription<WatchFrameEvent>? _wireSubscription;
  WatchFrameSend? _outboundSend;
  _PendingWSRequest? _pending;
  Future<void> _tail = Future.value();
  WSException? _failure;
  Future<void>? _closing;
  bool _open = false;
  bool _disposed = false;

  Stream<WSException> get failures => _failures.stream;
  Stream<WSL2Message> get incoming => _incoming.stream;
  bool get isOpen => _open && !_disposed && _failure == null;

  Future<void> open() async {
    if (_disposed) {
      throw const WSException(WSErrorCode.disposed, 'Link disposed');
    }
    if (_open) return;
    _payloadSubscription = _channel.payloads.listen((payload) => runZoned(
        () => _onPayload(payload),
        zoneValues: {#wsLogContext: _logContext}));
    _wireSubscription = _channel.frames.listen((event) => runZoned(
        () => _onWireFrame(event),
        zoneValues: {#wsLogContext: _logContext}));
    unawaited(
      _channel.terminated.then((error) => _fail(_mapFrameError(error))),
    );
    try {
      await connection.connect();
      if (_disposed)
        throw const WSException(
            WSErrorCode.disposed, "Link closed during connect");
      if (_failure != null) throw _failure!;
      _open = true;
    } catch (error) {
      _fail(_mapFrameError(error));
      rethrow;
    }
  }

  Future<WSL2Message> request(
    WSL2Message message, {
    required int replyKey,
    Duration? timeout,
  }) {
    return _enqueue(
        () => _execute(message, replyKey: replyKey, timeout: timeout));
  }

  Future<WSL2Message> requestWhere(
    WSL2Message message, {
    required bool Function(WSL2Message reply) matches,
    Duration? timeout,
  }) {
    return _enqueue(
      () => _execute(message, matches: matches, timeout: timeout),
    );
  }

  Future<void> send(WSL2Message message) {
    return _enqueue(() async {
      WSWatchDebugLog.apiIn(
        'WSLink.send',
        WSWatchDebugLog.describeWSL2Message(message),
      );
      final outbound = _channel.startSend(message.encode());
      _outboundSend = outbound;
      try {
        await outbound.completed;
        WSWatchDebugLog.apiOut('WSLink.send', 'ok seq=${outbound.sequence}');
      } catch (error) {
        final mapped = error is WSException ? error : _mapFrameError(error);
        WSWatchDebugLog.linkFailure(
          'WSLink.send',
          mapped,
          detail: 'L1 send/ACK failed after seq=${outbound.sequence}',
        );
        throw mapped;
      } finally {
        if (identical(_outboundSend, outbound)) _outboundSend = null;
      }
    });
  }

  Future<void> close() => _closing ??= _close().catchError((Object error) {
        _closing = null;
        throw error;
      });

  Future<void> _close() async {
    const error = WSException(WSErrorCode.disposed, 'Link closed before reply');
    _fail(error);
    _disposed = true;
    _open = false;
    await _wireSubscription?.cancel();
    _wireSubscription = null;
    await _payloadSubscription?.cancel();
    _payloadSubscription = null;
    await _channel.close(error);
    // Surface cleanup failures to the Hub; the frame channel cleanup is best effort.
    await connection.dispose();
    await _failures.close();
    await _incoming.close();
  }

  void _requireOpen() {
    if (_disposed)
      throw const WSException(WSErrorCode.disposed, 'Link disposed');
    if (_failure != null) throw _failure!;
    if (!_open)
      throw const WSException(WSErrorCode.unavailable, 'Link not open');
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    try {
      _requireOpen();
    } catch (error, stack) {
      return Future.error(error, stack);
    }
    final run = _tail.then((_) {
      _requireOpen();
      return runZoned(action, zoneValues: {#wsLogContext: _logContext});
    });
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<WSL2Message> _execute(
    WSL2Message message, {
    int? replyKey,
    bool Function(WSL2Message reply)? matches,
    Duration? timeout,
  }) async {
    if (_disposed || !_open) {
      throw const WSException(WSErrorCode.disposed, 'Link not open');
    }
    if (_pending != null) {
      throw const WSException(
          WSErrorCode.unavailable, 'Another WS request is active');
    }
    WSWatchDebugLog.apiIn(
      'WSLink.request',
      WSWatchDebugLog.describeWSL2Message(message),
    );
    final pending = _PendingWSRequest(
      request: message,
      command: message.command,
      replyKey: replyKey,
      matches: matches,
      completer: Completer<WSL2Message>(),
    );
    pending.completer.future.ignore();
    _pending = pending;
    final outbound = _channel.startSend(message.encode());
    _outboundSend = outbound;
    try {
      try {
        await outbound.completed;
      } catch (error) {
        final mapped = error is WSException ? error : _mapFrameError(error);
        WSWatchDebugLog.linkFailure(
          'WSLink.request',
          mapped,
          detail: 'L1 send/ACK failed after seq=${outbound.sequence}',
        );
        throw mapped;
      }
      return await pending.completer.future.timeout(
        timeout ?? const Duration(seconds: 8),
        onTimeout: () {
          const error = WSException(
              WSErrorCode.businessReplyTimeout, 'WS reply timed out');
          WSWatchDebugLog.linkFailure(
            'WSLink.request',
            error,
            detail:
                'L2 reply timeout ${WSWatchDebugLog.describeWSL2Message(message)}',
          );
          throw error;
        },
      );
    } catch (error) {
      if (error is WSException) {
        rethrow;
      }
      final mapped = _mapFrameError(error);
      WSWatchDebugLog.linkFailure('WSLink.request', mapped);
      throw mapped;
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
    List<WSL2Message> messages;
    try {
      messages = WSL2Message.decodeAll(payload.bytes);
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
    if (_disposed || _failure != null) return;
    _failure = error;
    _open = false;
    _pending?.fail(error);
    _pending = null;
    if (!_failures.isClosed) _failures.add(error);
  }
}

final class _PendingWSRequest {
  _PendingWSRequest({
    required this.request,
    required this.command,
    this.replyKey,
    this.matches,
    required this.completer,
  });

  final WSL2Message request;
  final int command;
  final int? replyKey;
  final bool Function(WSL2Message reply)? matches;
  final Completer<WSL2Message> completer;

  bool accepts(WSL2Message message) {
    if (message.command != command) return false;
    if (matches != null) return matches!(message);
    return message.key == replyKey;
  }

  void fail(WSException error) {
    if (!completer.isCompleted) completer.completeError(error);
  }
}

WSException _mapFrameError(Object error) {
  if (error is WSException) return error;
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
