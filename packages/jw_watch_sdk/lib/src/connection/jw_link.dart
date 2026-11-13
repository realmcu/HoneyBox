import 'dart:async';
import 'dart:typed_data';

import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport/watch_transport.dart';

import '../debug/jw_debug_log.dart';
import '../model/jw_error.dart';
import 'jw_protocol.dart';

final class _PendingRequest {
  _PendingRequest(this.request);

  final JWProtocolRequest request;
  final response = Completer<JWProtocolMessage>();
  WatchFrameSend? send;
}

/// JW L2 request/reply matching over the common T3 frame channel.
///
/// Exactly one L2 request is active at a time. That preserves the Android
/// SDK's command serialization and prevents a late same-key response from
/// completing a newer request.
final class JWLink {
  JWLink(this.connection, {WatchFrameConfig? config})
      : _channel = WatchFrameChannel(
          WatchFramePort.fromConnection(connection),
          profile: WatchFrameProfile.jw,
          config: config ??
              const WatchFrameConfig(
                ackTimeout: Duration(seconds: 3),
                maxRetries: 2,
                maxPayloadLength: 236,
              ),
          mapError: _mapFrameError,
        );

  static int _nextSessionId = 0;
  final int _sessionId = ++_nextSessionId;
  String get _logContext =>
      'device=${connection.target.deviceId} session=$_sessionId';
  final WatchTransportConnection connection;
  final WatchFrameChannel _channel;
  final _events = StreamController<JWProtocolMessage>.broadcast(sync: true);
  final _failures = StreamController<JWException>.broadcast(sync: true);
  StreamSubscription<WatchReceivedPayload>? _payloadSubscription;
  StreamSubscription<WatchFrameEvent>? _wireSubscription;
  Future<void> _tail = Future.value();
  _PendingRequest? _pending;
  JWException? _failure;
  bool _open = false;
  bool _disposed = false;
  Future<void>? _disposing;

  /// Completes only when the physical channel ends or its owner closes it.
  Future<Object> get terminated => _channel.terminated;

  Stream<JWProtocolMessage> get events => _events.stream;
  Stream<JWException> get failures => _failures.stream;
  bool get isOpen => _open && !_disposed && _failure == null;

  Future<void> open() async {
    if (_disposed) {
      throw const JWException(JWErrorCode.disposed, 'Link has been disposed');
    }
    if (_open) return;
    _payloadSubscription = _channel.payloads.listen(_onPayload);
    _wireSubscription = _channel.frames.listen(_onWireFrame);
    unawaited(
        _channel.terminated.then((error) => _fail(_mapFrameError(error))));
    try {
      await connection.connect();
      _open = true;
    } catch (error) {
      _fail(_mapFrameError(error));
      rethrow;
    }
  }

  Future<JWProtocolMessage> request(JWProtocolRequest request) {
    if (request.responseKey == null) {
      return Future.error(
          ArgumentError('JW request needs a response key; use send instead'));
    }
    return _enqueue(() => _execute(request));
  }

  Future<void> send(JWProtocolRequest request) =>
      _enqueue(() async => _execute(request, expectResponse: false));

  /// Sends [trigger] and collects unsolicited setting responses on [events].
  /// Sends a fire-and-forget SETTINGS command and awaits the next matching
  /// unsolicited business reply on [events] (address book `0x6E`, etc.).
  Future<JWProtocolMessage> sendAndAwaitUnsolicited({
    required JWProtocolRequest request,
    required int responseCommand,
    required int responseKey,
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _enqueue(() async {
      final completer = Completer<JWProtocolMessage>();
      late final StreamSubscription<JWProtocolMessage> subscription;
      subscription = events.listen((message) {
        if (message.command == responseCommand && message.key == responseKey) {
          if (!completer.isCompleted) completer.complete(message);
        }
      });
      try {
        await _execute(request, expectResponse: false);
        return await _untilTerminated(completer.future, timeout);
      } on TimeoutException {
        throw const JWException(JWErrorCode.businessReplyTimeout,
            'JW unsolicited settings reply timed out');
      } finally {
        await subscription.cancel();
      }
    });
  }

  Future<List<JWProtocolMessage>> collectSettingResponses({
    required JWProtocolRequest trigger,
    required int responseCommand,
    required int responseKey,
    required bool Function(JWProtocolMessage message) isComplete,
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _enqueue(() async {
      final messages = <JWProtocolMessage>[];
      late final StreamSubscription<JWProtocolMessage> subscription;
      final done = Completer<void>();
      subscription = events.listen((message) {
        if (message.command != responseCommand || message.key != responseKey) {
          return;
        }
        messages.add(message);
        if (isComplete(message)) {
          if (!done.isCompleted) done.complete();
        }
      });
      try {
        await _execute(trigger, expectResponse: false);
        await _untilTerminated(done.future, timeout);
      } on TimeoutException {
        if (messages.isEmpty) {
          throw const JWException(
              JWErrorCode.businessReplyTimeout, 'JW alarm2 read timed out');
        }
      } finally {
        await subscription.cancel();
      }
      return messages;
    });
  }

  Future<T> _untilTerminated<T>(Future<T> work, Duration timeout) async {
    if (!isOpen) {
      throw _failure ?? const JWException(JWErrorCode.disposed, 'Link closed');
    }
    final interrupted = Completer<T>();
    final subscription = failures.listen((error) {
      if (!interrupted.isCompleted) interrupted.completeError(error);
    });
    final timer = Timer(timeout, () {
      if (!interrupted.isCompleted) {
        interrupted.completeError(TimeoutException('JW reply timed out'));
      }
    });
    try {
      return await Future.any([work, interrupted.future]);
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (!isOpen) {
      return Future.error(_failure ??
          const JWException(
              JWErrorCode.unavailable, 'JW byte channel is unavailable'));
    }
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      if (result.isCompleted) return;
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<JWProtocolMessage> _execute(JWProtocolRequest request,
      {bool expectResponse = true}) async {
    if (!isOpen) {
      throw _failure ?? const JWException(JWErrorCode.disposed, 'Link closed');
    }
    final pending = _PendingRequest(request);
    // Link loss can arrive while awaiting the ACK, before awaiting the reply.
    // Attach an error handler now; awaiting response below still gets the error.
    pending.response.future.ignore();
    _pending = pending;
    JWWatchDebugLog.apiIn('JWLink.${expectResponse ? 'request' : 'send'}',
        '$_logContext ${JWWatchDebugLog.describeRequest(request)}');
    try {
      final encoded = encodeJWRequest(request);
      pending.send = _channel.startSend(encoded);
      await pending.send!.completed;
      if (!expectResponse) {
        return JWProtocolMessage(0, 0, Uint8List(0));
      }
      final reply = await pending.response.future.timeout(request.replyTimeout);
      return reply;
    } on TimeoutException {
      const error = JWException(
          JWErrorCode.businessReplyTimeout, 'JW business reply timed out');
      JWWatchDebugLog.apiOut('JWLink.request',
          '$_logContext timeout ${JWWatchDebugLog.describeRequest(request)}');
      throw error;
    } catch (error) {
      final mapped = _mapFrameError(error);
      JWWatchDebugLog.apiOut('JWLink.${expectResponse ? 'request' : 'send'}',
          '$_logContext failed $mapped');
      throw mapped;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  void _onWireFrame(WatchFrameEvent event) {
    JWWatchDebugLog.wireFrame(
      event,
      awaitingAckSeq: _pending?.send?.sequence,
      context: _logContext,
    );
  }

  void _onPayload(WatchReceivedPayload payload) {
    List<JWProtocolMessage> messages;
    try {
      messages = decodeJWMessages(payload.bytes);
    } on FormatException catch (error) {
      JWWatchDebugLog.l2DecodeFailed(payload.bytes, error,
          l1Seq: payload.seq, context: _logContext);
      return;
    }
    for (final message in messages) {
      final pending = _pending;
      if (pending != null &&
          message.command ==
              (pending.request.responseCommand ?? pending.request.command) &&
          message.key == pending.request.responseKey &&
          !pending.response.isCompleted) {
        JWWatchDebugLog.l2MatchedBusinessReply(
          request: pending.request,
          reply: message,
          outboundSeq: pending.send?.sequence,
          context: _logContext,
        );
        if (pending.send != null) _channel.confirmReceived(pending.send!);
        pending.response.complete(message);
      } else if (!_events.isClosed) {
        _events.add(message);
      }
    }
  }

  void _fail(JWException error) {
    if (_failure != null) return;
    _failure = error;
    _open = false;
    final pending = _pending;
    if (pending != null && !pending.response.isCompleted) {
      pending.response.completeError(error);
    }
    if (!_failures.isClosed) _failures.add(error);
  }

  Future<void> dispose() =>
      _disposing ??= _dispose().catchError((Object error) {
        _disposing = null;
        throw error;
      });

  Future<void> _dispose() async {
    _disposed = true;
    _fail(const JWException(
        JWErrorCode.transportDisconnected, 'JW session disposed'));
    await _wireSubscription?.cancel();
    await _payloadSubscription?.cancel();
    await _channel
        .close(const JWException(JWErrorCode.disposed, 'Link closed'));
    // Frame cleanup preserves its termination cause. Explicit owner cleanup
    // must also surface transport cleanup errors and permit retrying them.
    await connection.dispose();
    await _events.close();
    await _failures.close();
  }
}

JWException _mapFrameError(Object error) {
  if (error is JWException) return error;
  if (error is WatchFrameWriteException) {
    return const JWException(JWErrorCode.writeFailed, 'JW frame write failed');
  }
  if (error is WatchFrameException) {
    final code = switch (error.kind) {
      WatchFrameErrorKind.disconnected => JWErrorCode.transportDisconnected,
      WatchFrameErrorKind.ackTimeout => JWErrorCode.ackTimeout,
      WatchFrameErrorKind.writeTimeout => JWErrorCode.writeTimeout,
      WatchFrameErrorKind.nack => JWErrorCode.nack,
      WatchFrameErrorKind.receive => JWErrorCode.receiveFailed,
      WatchFrameErrorKind.write => JWErrorCode.writeFailed,
      WatchFrameErrorKind.queueFull => JWErrorCode.queueFull,
    };
    return JWException(code, error.message);
  }
  if (error is WatchTransportException) {
    return JWException(JWErrorCode.transport, error.message);
  }
  return JWException(JWErrorCode.protocol, 'JW request failed: $error');
}
