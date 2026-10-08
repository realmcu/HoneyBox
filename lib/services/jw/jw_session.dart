import 'dart:async';
import 'dart:typed_data';
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
  final int seq;
  final JwRequest request;
  var ack = Completer<bool>();
  final reply = Completer<JwMessage>();
  _Pending(this.seq, this.request) {
    // Disconnect can arrive inside the platform write before the await below.
    _watchAck();
    reply.future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }
  void _watchAck() {
    ack.future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  void resetAck() {
    ack = Completer<bool>();
    _watchAck();
  }

  void fail(JwLinkException e) {
    if (!ack.isCompleted) ack.completeError(e);
    if (!reply.isCompleted) reply.completeError(e);
  }
}

class JwSession {
  final JwTransport transport;
  final Duration ackTimeout;
  final Duration replyTimeout;
  final int ackRetries;
  final _decoder = JwFrameDecoder();
  final _incomingFrames = StreamController<JwFrame>.broadcast(sync: true);
  final _outgoingFrames = StreamController<JwFrame>.broadcast(sync: true);
  final _events = StreamController<JwMessage>.broadcast(sync: true);
  final _failures = StreamController<JwLinkException>.broadcast(sync: true);
  final _seen = <String>{};
  final _abort = Completer<void>();
  final _tasks = <int, void Function(JwLinkException)>{};
  StreamSubscription<Uint8List>? _rx;
  StreamSubscription<void>? _down;
  Future<void> _tail = Future.value();
  Future<void> _ackTail = Future.value();
  Future<void>? _opening;
  Future<void>? _closing;
  _Pending? _pending;
  JwLinkException? _failure;
  var _epoch = 0;
  var _seq = 0;
  var _taskId = 0;
  var _queued = 0;
  var _ackQueued = 0;
  bool _accept = false;
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
  void _observeOutgoing(Uint8List bytes) {
    if (!_outgoingFrames.isClosed) {
      _outgoingFrames.add(JwFrameDecoder().add(bytes).single);
    }
  }

  Stream<JwMessage> get events => _events.stream;
  Stream<JwLinkException> get failures => _failures.stream;
  bool get isOpen => _isOpen;
  Future<void> open() => _opening ??= _open();
  Future<void> _open() async {
    if (_closed) throw const JwLinkException('open', 'Session already closed');
    final epoch = ++_epoch;
    _accept = true;
    _decoder.clear();
    _rx = transport.notifications.listen((bytes) {
      if (!_accept || epoch != _epoch) return;
      for (final frame in _decoder.add(bytes)) {
        _receive(frame);
      }
    },
        onError: (Object _) => _fail(
            const JwLinkException('notify', 'Notification stream failed')));
    _down = transport.disconnected.listen(
        (_) => _fail(const JwLinkException('disconnect', 'Link disconnected')));
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
    final p = _Pending(_seq = (_seq + 1) & 0xffff, request);
    _pending = p;
    final frame = JwCodec.encode(
        seq: p.seq,
        payload: JwCodec.encodeL2(
            request.command, [JwField(request.key, request.value)]));
    try {
      final retryLimit = request.ackRetryLimit ?? ackRetries;
      for (var attempt = 0; attempt <= retryLimit; attempt++) {
        if (attempt > 0) {
          p.resetAck();
          // A real matching application reply remains proof across retries.
          if (p.reply.isCompleted) p.ack.complete(true);
        }
        if (!_isOpen) {
          throw _failure ??
              const JwLinkException('disconnect', 'Session ended');
        }
        try {
          _observeOutgoing(frame);
          await transport.write(frame, withResponse: true);
        } catch (e) {
          throw e is JwLinkException
              ? e
              : const JwLinkException('write', 'FF02 write failed');
        }
        try {
          final accepted = await p.ack.future.timeout(ackTimeout);
          if (accepted) break;
          if (attempt == retryLimit) {
            throw const JwLinkException('nack', 'Device rejected the frame');
          }
        } on TimeoutException {
          if (attempt == retryLimit) {
            throw const JwLinkException('ack', 'Transport ACK timed out');
          }
        }
      }
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

  void _receive(JwFrame frame) {
    if (!_incomingFrames.isClosed) _incomingFrames.add(frame);
    final p = _pending;
    if (frame.ack) {
      if (p?.seq == frame.seq && !p!.ack.isCompleted) {
        p.ack.complete(!frame.error);
      }
      return;
    }
    if (!frame.noAck) _ack(frame.seq);
    final key = '${frame.seq}:${frame.payload.join(',')}';
    if (!_seen.add(key)) return;
    if (_seen.length > 128) _seen.remove(_seen.first);
    JwMessage message;
    try {
      message = JwCodec.decodeL2(frame.payload);
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
        if (!p.ack.isCompleted) p.ack.complete(true);
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

  void _ack(int seq) {
    if (_ackQueued >= 64) {
      _fail(const JwLinkException('queue', 'ACK queue full'));
      return;
    }
    final epoch = _epoch;
    _ackQueued++;
    _ackTail = _ackTail.then((_) async {
      if (!_accept || epoch != _epoch) return;
      try {
        final frame =
            JwCodec.encode(seq: seq, payload: Uint8List(0), ack: true);
        _observeOutgoing(frame);
        await transport.write(frame, withResponse: true);
      } catch (_) {
        _fail(const JwLinkException('write', 'ACK write failed'));
      }
    }).whenComplete(() => _ackQueued--);
  }

  void _fail(JwLinkException error) {
    if (_failure != null) return;
    _failure = error;
    _epoch++;
    _isOpen = false;
    _accept = false;
    _decoder.clear();
    _seen.clear();
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
    await _rx?.cancel();
    await _down?.cancel();
    try {
      await transport.disconnect();
    } finally {
      await _incomingFrames.close();
      await _outgoingFrames.close();
      await _events.close();
      await _failures.close();
    }
  }
}
