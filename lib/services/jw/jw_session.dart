import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'jw_codec.dart';
import 'jw_protocol.dart';
import 'jw_transport.dart';

class JwLinkException implements Exception {
  final String stage;
  final String message;
  const JwLinkException(this.stage, this.message);
  @override
  String toString() => 'JW $stage: $message';
}

class _Pending {
  final JwRequest request;
  WatchFrameSend? send;
  final reply = Completer<JwMessage>();
  _Pending(this.request) {
    reply.future.ignore();
  }
  void fail(JwLinkException e) {
    if (!reply.isCompleted) reply.completeError(e);
  }
}

class JwSession {
  final JwTransport transport;
  final Duration ackTimeout;
  final Duration replyTimeout;
  final int ackRetries;
  WatchFrameChannel? _channel;
  final _incomingFrames = StreamController<JwFrame>.broadcast(sync: true);
  final _outgoingFrames = StreamController<JwFrame>.broadcast(sync: true);
  final _events = StreamController<JwMessage>.broadcast(sync: true);
  final _failures = StreamController<JwLinkException>.broadcast(sync: true);
  final _abort = Completer<void>();
  final _tasks = <int, void Function(JwLinkException)>{};
  StreamSubscription<WatchFrameEvent>? _frames;
  StreamSubscription<WatchReceivedPayload>? _payloads;
  Future<void> _tail = Future.value();
  Future<void>? _opening;
  Future<void>? _closing;
  _Pending? _pending;
  JwLinkException? _failure;
  var _epoch = 0;
  var _taskId = 0;
  var _queued = 0;
  bool _closingFailedTransport = false;
  Future<void>? _transportClosing;
  Future<void> _disconnectTransport() =>
      _transportClosing ??= transport.disconnect();

  /// Cleanup of a failed byte stream must not replace the published failure.
  bool get isClosingFailedTransport => _closingFailedTransport;
  bool _isOpen = false;
  bool _closed = false;
  JwSession(this.transport,
      {this.ackTimeout = const Duration(seconds: 3),
      this.replyTimeout = const Duration(seconds: 5),
      this.ackRetries = 2}) {
    if (ackRetries < 0 ||
        ackTimeout <= Duration.zero ||
        replyTimeout <= Duration.zero) {
      throw ArgumentError('JW timeout/retry configuration');
    }
  }
  Stream<JwFrame> get incomingFrames => _incomingFrames.stream;

  /// Attempted frames, including retries and ACKs; not proof of device receipt.
  Stream<JwFrame> get outgoingFrames => _outgoingFrames.stream;
  Stream<JwMessage> get events => _events.stream;
  Stream<JwLinkException> get failures => _failures.stream;
  bool get isOpen => _isOpen;
  Future<void> open() => _opening ??= _open();
  Future<void> _open() async {
    if (_closed) throw const JwLinkException('open', 'Session already closed');
    final epoch = ++_epoch;
    final channel = _channel = WatchFrameChannel(
        WatchFramePort(
            received: transport.notifications,
            disconnected: transport.disconnected,
            maxWriteLength: () => max(1, min(244, transport.mtu - 3)),
            write: (bytes) => transport.write(bytes, withResponse: true),
            close: () async {
              // A fully written frame which times out can be closed logically.
              // Failed chunks/receive streams need a physical reset of framing.
              if (const ['write', 'notify', 'queue']
                  .contains(_failure?.stage)) {
                _closingFailedTransport = true;
                try {
                  await _disconnectTransport();
                } finally {
                  _closingFailedTransport = false;
                }
              }
            }),
        profile: WatchFrameProfile.jw,
        generation: epoch,
        config: WatchFrameConfig(
            ackTimeout: ackTimeout,
            maxRetries: ackRetries,
            maxPayloadLength: 236,
            deduplicationCapacity: 128),
        mapError: _mapFrameError);
    _frames = channel.frames.listen((event) {
      if (epoch != _epoch || _closed) return;
      if (event.kind != WatchFrameKind.data &&
          event.kind != WatchFrameKind.retry &&
          event.kind != WatchFrameKind.ack &&
          event.kind != WatchFrameKind.errAck) {
        return;
      }
      final f = WatchFrame.decode(event.raw,
          profile: WatchFrameProfile.jw, maxPayloadLength: 236);
      final frame =
          JwFrame(f.seq, f.isAck, f.noAck, f.payload, error: f.isError);
      (event.direction == WatchFrameDirection.rx
              ? _incomingFrames
              : _outgoingFrames)
          .add(frame);
    });
    _payloads = channel.payloads.listen((frame) {
      if (epoch == _epoch && !_closed) _receive(frame.bytes);
    });
    unawaited(
        channel.terminated.then((reason) => _fail(_mapFrameError(reason))));
    try {
      await Future.any<void>([
        transport.subscribe(),
        _abort.future.then<void>((_) => throw _failure!)
      ]);
      if (epoch != _epoch || _closed) {
        throw _failure ?? const JwLinkException('subscribe', 'Interrupted');
      }
      _isOpen = true;
    } catch (e) {
      final error = e is JwLinkException
          ? e
          : const JwLinkException('subscribe', 'FF03 subscription failed');
      _fail(error);
      throw error;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (!_isOpen) {
      return Future.error(
          _failure ?? const JwLinkException('open', 'Session not ready'));
    }
    if (_queued >= 32) {
      return Future.error(const JwLinkException('queue', 'Request queue full'));
    }
    final result = Completer<T>();
    final id = ++_taskId;
    final epoch = _epoch;
    _queued++;
    _tasks[id] = (error) {
      if (!result.isCompleted) result.completeError(error);
    };
    _tail = _tail.then((_) async {
      if (result.isCompleted) return;
      try {
        if (!_isOpen || epoch != _epoch) {
          throw _failure ?? const JwLinkException('disconnect', 'Old session');
        }
        final value = await action();
        if (!result.isCompleted) result.complete(value);
      } catch (e, st) {
        if (!result.isCompleted) result.completeError(e, st);
      }
    }).whenComplete(() {
      _tasks.remove(id);
      _queued--;
    });
    return result.future;
  }

  Future<JwMessage> request(JwRequest request) {
    if (request.responseKey == null) {
      return Future.error(ArgumentError('Command has no L2 reply; use send'));
    }
    return _enqueue(() => _execute(request, expectReply: true));
  }

  Future<void> send(JwRequest request) {
    if (request.responseKey != null) {
      return Future.error(
          ArgumentError('Command requires an L2 reply; use request'));
    }
    return _enqueue(() async {
      await _execute(request, expectReply: false);
    });
  }

  Future<JwMessage> _execute(JwRequest request,
      {required bool expectReply}) async {
    final p = _Pending(request);
    _pending = p;
    try {
      p.send = _channel!.startSend(
          JwCodec.encodeL2(
              request.command, [JwField(request.key, request.value)]),
          maxRetries: request.ackRetryLimit ?? ackRetries);
      await p.send!.completed;
      if (!expectReply) return JwMessage(request.command, []);
      try {
        return await p.reply.future.timeout(replyTimeout);
      } on TimeoutException {
        throw const JwLinkException('reply', 'Application reply timed out');
      }
    } catch (e) {
      final error = e is JwLinkException
          ? e
          : const JwLinkException('protocol', 'Request failed');
      // No request after a timeout may consume a late reply from this session.
      _fail(error);
      throw error;
    } finally {
      if (identical(_pending, p)) _pending = null;
    }
  }

  void _receive(Uint8List payload) {
    final p = _pending;
    JwMessage message;
    try {
      message = JwCodec.decodeL2(payload);
    } on FormatException {
      return;
    }
    final rest = <JwField>[];
    for (final field in message.fields) {
      if (p != null &&
          (p.request.responseCommand ?? p.request.command) == message.command &&
          p.request.responseKey == field.key &&
          !p.reply.isCompleted) {
        // A matching L2 reply proves reception even when L1 ACK arrives later.
        if (p.send != null) _channel!.confirmReceived(p.send!);
        p.reply.complete(p.request.singleFieldReply
            ? message
            : JwMessage(message.command, [field]));
      } else {
        rest.add(field);
      }
    }
    if (rest.isNotEmpty && !_events.isClosed) {
      _events.add(JwMessage(message.command, rest));
    }
  }

  void _fail(JwLinkException error) {
    if (_failure != null) return;
    _failure = error;
    _epoch++;
    _isOpen = false;
    unawaited(_channel?.close(error));
    _pending?.fail(error);
    for (final cancel in _tasks.values.toList()) {
      cancel(error);
    }
    _abort.complete();
    _failures.add(error);
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    _fail(const JwLinkException('disconnect', 'Session closed'));
    await _frames?.cancel();
    await _payloads?.cancel();
    await _channel?.close(_failure);
    try {
      await _disconnectTransport();
    } finally {
      await _incomingFrames.close();
      await _outgoingFrames.close();
      await _events.close();
      await _failures.close();
    }
  }
}

JwLinkException _mapFrameError(Object error) {
  if (error is JwLinkException) return error;
  if (error is WatchFrameWriteException) {
    return JwLinkException(
        'write', error.isControl ? 'ACK write failed' : 'FF02 write failed');
  }
  if (error is! WatchFrameException) {
    return const JwLinkException('protocol', 'Request failed');
  }
  return JwLinkException(
      switch (error.kind) {
        WatchFrameErrorKind.ackTimeout => 'ack',
        WatchFrameErrorKind.writeTimeout => 'write',
        WatchFrameErrorKind.nack => 'nack',
        WatchFrameErrorKind.receive => 'notify',
        WatchFrameErrorKind.write => 'write',
        WatchFrameErrorKind.disconnected => 'disconnect',
        WatchFrameErrorKind.queueFull => 'queue',
      },
      switch (error.kind) {
        WatchFrameErrorKind.ackTimeout => 'Transport ACK timed out',
        WatchFrameErrorKind.nack => 'Device rejected the frame',
        WatchFrameErrorKind.receive => 'Notification stream failed',
        WatchFrameErrorKind.writeTimeout ||
        WatchFrameErrorKind.write =>
          'FF02 write failed',
        WatchFrameErrorKind.disconnected => 'Link disconnected',
        WatchFrameErrorKind.queueFull => 'Frame queue full',
      });
}
