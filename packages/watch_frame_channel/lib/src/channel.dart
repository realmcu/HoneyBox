import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'config.dart';
import 'observation.dart';
import 'errors.dart';
import 'port.dart';
import 'frame.dart';
import 'frame_assembler.dart';

class WatchReceivedPayload {
  WatchReceivedPayload(this.seq, Uint8List bytes)
      : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final int seq;
  final Uint8List bytes;
}

class WatchFrameChannel {
  WatchFrameChannel(this.connection,
      {this.config = const WatchFrameConfig(),
      this.generation = 1,
      this.profile = WatchFrameProfile.ws,
      this.mapError = _identity}) {
    config.validate();
    if (config.maxPayloadLength > profile.maxPayloadLength) {
      throw ArgumentError('payload limit exceeds wire profile');
    }
    _seq = config.initialSequence;
    if (connection.maxWriteLength() <= 0) {
      throw ArgumentError('invalid write limit');
    }
    _assembler = WatchFrameAssembler(
        profile: profile,
        timeout: config.rxAssembleTimeout,
        maxPayloadLength: config.maxPayloadLength,
        onFrame: _receive,
        onError: (kind, raw, seq) {
          _event(WatchFrameDirection.rx, kind, raw, seq: seq);
          if (seq != null && profile.acknowledgeCorruption) {
            _acknowledge(seq, error: true);
          }
        });
    _rx = connection.received.listen(_assembler.add,
        onError: (Object error, StackTrace stack) {
      // A receive error is not proof that the transport disconnected. The
      // owning transport is the sole authority for physical link lifecycle.
      _interruptActive(
          _error(WatchFrameErrorKind.receive, 'receive failed: $error'));
    }, onDone: () {
      // Some adapters can end/recreate their notification stream before the
      // platform emits its connection-state callback. Do not infer a disconnect.
      _interruptActive(
          _error(WatchFrameErrorKind.receive, 'receive stream ended'));
    });
    _disconnect = connection.disconnected.listen((_) {
      unawaited(close(
          _error(WatchFrameErrorKind.disconnected, 'transport disconnected')));
    });
  }
  final WatchFramePort connection;
  final WatchFrameConfig config;
  final int generation;
  final WatchFrameProfile profile;
  final Object Function(Object error) mapError;
  final Set<WatchFrameSend> _sends = {};
  WatchFrameSend? _active;
  Object _error(WatchFrameErrorKind kind, String message) =>
      mapError(WatchFrameException(kind, message));
  final _payloads =
      StreamController<WatchReceivedPayload>.broadcast(sync: true);
  final _events = StreamController<WatchFrameEvent>.broadcast(sync: true);
  final _ended = Completer<Object>();
  final Set<void Function(Object)> _interrupts = {};
  late final WatchFrameAssembler _assembler;
  late final StreamSubscription<Uint8List> _rx;
  late final StreamSubscription<void> _disconnect;
  final Set<_WriteJob> _writes = {};
  final Queue<_WriteJob> _acks = Queue();
  final Queue<_WriteJob> _data = Queue();
  final Queue<_SeenFrame> _seen = Queue();
  Future<void> _dataTail = Future.value();
  Future<void>? _closing;
  Completer<bool>? _ack;
  int? _ackSeq;
  String? _ackRequestId, _ackTraceId;
  int _seq = 1;
  bool _writing = false;
  Object? _failure;
  Stream<WatchReceivedPayload> get payloads => _payloads.stream;
  Stream<WatchFrameEvent> get frames => _events.stream;
  Future<Object> get terminated => _ended.future;
  bool get isClosed => _failure != null;
  int get bufferedBytes => _assembler.bufferedBytes;

  Future<void> send(Uint8List payload,
          {int? maxRetries, String? requestId, String? traceId}) =>
      startSend(payload,
              maxRetries: maxRetries, requestId: requestId, traceId: traceId)
          .completed;

  /// The handle identifies exactly one send in this channel/generation.
  /// Only a session which has matched its own L2 reply should confirm it.
  WatchFrameSend startSend(Uint8List payload,
      {int? maxRetries, String? requestId, String? traceId}) {
    final handle = WatchFrameSend._(generation);
    final copy = Uint8List.fromList(payload);
    final retries = maxRetries ?? config.maxRetries;
    Object? failure;
    if (copy.length > config.maxPayloadLength || retries < 0) {
      failure = ArgumentError('invalid payload length or retry count');
    } else if (isClosed) {
      failure = _failure;
    } else if (_sends.length >= config.sendQueueCapacity) {
      failure = _error(WatchFrameErrorKind.queueFull, 'send queue full');
    }
    if (failure != null) {
      handle._done.completeError(failure);
      return handle;
    }
    _sends.add(handle);
    _dataTail = _dataTail.then((_) async {
      if (handle._done.isCompleted) return;
      try {
        await _send(copy, retries, requestId, traceId, handle);
        if (!handle._done.isCompleted) handle._done.complete();
      } catch (error, stack) {
        if (!handle._done.isCompleted) handle._done.completeError(error, stack);
      } finally {
        _sends.remove(handle);
      }
    });
    return handle;
  }

  /// Waits for writes already queued, including control ACKs (not L1 ACK waits).
  Future<void> flushWrites() =>
      Future.wait(_writes.map((job) => job.done.future)).then((_) {});

  bool confirmReceived(WatchFrameSend handle) {
    if (isClosed ||
        handle.generation != generation ||
        !identical(_active, handle) ||
        handle._done.isCompleted) {
      return false;
    }
    handle._confirmed = true;
    if (_ack != null && !_ack!.isCompleted) _ack!.complete(true);
    return true;
  }

  Future<void> _send(Uint8List payload, int retries, String? requestId,
      String? traceId, WatchFrameSend handle) async {
    _checkOpen();
    _active = handle;
    final seq = _seq;
    handle._seq = seq;
    _seq = (_seq + 1) & 0xffff;
    final raw = WatchFrame(seq: seq, payload: payload).encode();
    try {
      for (var attempt = 0; attempt <= retries; attempt++) {
        _checkOpen();
        final waiter = Completer<bool>();
        _ack = waiter;
        if (handle._confirmed) waiter.complete(true);
        _ackSeq = seq;
        _ackRequestId = requestId;
        _ackTraceId = traceId;
        _event(WatchFrameDirection.tx,
            attempt == 0 ? WatchFrameKind.data : WatchFrameKind.retry, raw,
            seq: seq, requestId: requestId, traceId: traceId);
        await _queueWrite(raw, seq, requestId, traceId, false);
        try {
          final ok = await _deadline(
              waiter.future, config.ackTimeout, const _AckTimeout());
          if (ok || handle._confirmed) return;
          if (attempt == retries) {
            throw _error(WatchFrameErrorKind.nack, 'ERR ACK retries exhausted');
          }
        } on _AckTimeout {
          if (attempt == retries) {
            throw _error(WatchFrameErrorKind.ackTimeout, 'L1 ACK timed out');
          }
        }
      }
    } finally {
      _active = null;
      _ack = null;
      _ackSeq = null;
      _ackRequestId = null;
      _ackTraceId = null;
    }
  }

  Future<T> _race<T>(Future<T> operation) async {
    final interrupted = Completer<T>();
    void interrupt(Object error) {
      interrupted.completeError(error);
    }

    _interrupts.add(interrupt);
    try {
      if (_failure != null) interrupt(_failure!);
      return await Future.any([operation, interrupted.future]);
    } finally {
      _interrupts.remove(interrupt);
    }
  }

  Future<T> _deadline<T>(
      Future<T> operation, Duration duration, Object error) async {
    final expiry = Completer<T>();
    final timer = Timer(duration, () => expiry.completeError(error));
    try {
      return await _race(Future.any([operation, expiry.future]));
    } finally {
      timer.cancel();
    }
  }

  Future<void> _queueWrite(Uint8List raw, int seq, String? requestId,
      String? traceId, bool priority) {
    if (isClosed) return Future.error(_failure!);
    if (priority && _acks.length >= config.controlQueueCapacity) {
      final error = _error(WatchFrameErrorKind.queueFull, 'control queue full');
      return Future.error(error);
    }
    final job = _WriteJob(raw, seq, requestId, traceId, priority);
    _writes.add(job);
    (priority ? _acks : _data).add(job);
    if (!_writing) unawaited(_pumpWrites());
    return job.done.future;
  }

  Future<void> _pumpWrites() async {
    _writing = true;
    try {
      while (!isClosed && (_acks.isNotEmpty || _data.isNotEmpty)) {
        final job = (_acks.isNotEmpty ? _acks : _data).removeFirst();
        try {
          for (var offset = 0; offset < job.raw.length;) {
            _checkOpen();
            final limit = connection.maxWriteLength();
            if (limit <= 0) throw StateError('invalid transport write limit');
            final end = min(offset + limit, job.raw.length);
            final chunk = Uint8List.fromList(job.raw.sublist(offset, end));
            _event(WatchFrameDirection.tx, WatchFrameKind.chunk, chunk,
                seq: job.seq, requestId: job.requestId, traceId: job.traceId);
            _checkOpen();
            await _deadline(
                connection.write(chunk),
                config.chunkWriteTimeout,
                _error(
                    WatchFrameErrorKind.writeTimeout, 'chunk write timed out'));
            offset = end;
          }
          job.done.complete();
        } catch (error, stack) {
          // A failed write/ACK is an operation error, not a connection-state
          // signal. The transport's disconnected callback alone closes this
          // channel. Keeping the channel open also lets callers inspect and
          // retry without manufacturing a physical disconnect.
          final failure = error is WatchFrameException ||
                  identical(error, _failure)
              ? error
              : mapError(
                  WatchFrameWriteException(error, isControl: job.isControl));
          if (!job.done.isCompleted) job.done.completeError(failure, stack);
        } finally {
          _writes.remove(job);
        }
      }
    } finally {
      _writing = false;
    }
  }

  void _receive(WatchFrame frame, Uint8List raw) {
    if (isClosed) return;
    _event(
        WatchFrameDirection.rx,
        frame.isAck
            ? (frame.isError ? WatchFrameKind.errAck : WatchFrameKind.ack)
            : WatchFrameKind.data,
        raw,
        seq: frame.seq,
        requestId: frame.isAck && _ackSeq == frame.seq ? _ackRequestId : null,
        traceId: frame.isAck && _ackSeq == frame.seq ? _ackTraceId : null);
    if (isClosed) return;
    if (frame.isAck) {
      if (_ackSeq == frame.seq && _ack != null && !_ack!.isCompleted) {
        _ack!.complete(!frame.isError);
      }
      return;
    }
    if (!frame.noAck) _acknowledge(frame.seq);
    if (isClosed) return;
    final now = DateTime.now();
    while (_seen.isNotEmpty &&
        now.difference(_seen.first.at) > config.deduplicationWindow) {
      _seen.removeFirst();
    }
    if (_seen
        .any((e) => e.seq == frame.seq && _equal(e.payload, frame.payload))) {
      return;
    }
    if (_seen.any((e) => e.seq == frame.seq)) {
      _event(WatchFrameDirection.rx, WatchFrameKind.sequenceConflict, raw,
          seq: frame.seq);
    }
    _seen.add(_SeenFrame(frame.seq, frame.payload, now));
    while (_seen.length > config.deduplicationCapacity) {
      _seen.removeFirst();
    }
    if (!isClosed) {
      _payloads.add(WatchReceivedPayload(frame.seq, frame.payload));
    }
  }

  void _acknowledge(int seq, {bool error = false}) {
    if (isClosed) return;
    final raw = WatchFrame(seq: seq, isAck: true, isError: error).encode();
    _event(WatchFrameDirection.tx,
        error ? WatchFrameKind.errAck : WatchFrameKind.ack, raw,
        seq: seq);
    unawaited(
        _queueWrite(raw, seq, null, null, true).catchError((Object _) {}));
  }

  void _event(WatchFrameDirection direction, WatchFrameKind kind, List<int> raw,
      {int? seq, String? requestId, String? traceId}) {
    if (!_events.isClosed) {
      _events.add(WatchFrameEvent(
          direction: direction,
          kind: kind,
          raw: raw,
          seq: seq,
          requestId: requestId,
          traceId: traceId,
          connectionGeneration: generation));
    }
  }

  void _interruptActive(Object error) {
    final ack = _ack;
    if (ack != null && !ack.isCompleted) ack.completeError(error);
  }

  void _checkOpen() {
    if (_failure != null) throw _failure!;
  }

  Future<void> close([Object? reason]) {
    reason ??= _error(WatchFrameErrorKind.disconnected, 'channel closed');
    if (_closing != null) return _closing!;
    final closing = Completer<void>();
    _closing = closing.future;
    _failure = reason;
    _ended.complete(reason);
    for (final interrupt in _interrupts.toList()) {
      interrupt(reason);
    }
    _interrupts.clear();
    _assembler.dispose();
    _seen.clear();
    for (final handle in _sends.toList()) {
      if (!handle._done.isCompleted) handle._done.completeError(reason);
    }
    _sends.clear();
    for (final job in [..._acks, ..._data]) {
      job.done.completeError(reason);
    }
    _acks.clear();
    _data.clear();
    _cleanup().then(closing.complete, onError: closing.completeError);
    return _closing!;
  }

  Future<void> _cleanup() async {
    await _rx.cancel();
    await _disconnect.cancel();
    try {
      await connection.close();
    } catch (_) {/* Termination retains its original cause. */}
    await _payloads.close();
    await _events.close();
  }
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _WriteJob {
  _WriteJob(this.raw, this.seq, this.requestId, this.traceId, this.isControl);
  final bool isControl;
  final Uint8List raw;
  final int seq;
  final String? requestId, traceId;
  final done = Completer<void>();
}

class _SeenFrame {
  _SeenFrame(this.seq, this.payload, this.at);
  final int seq;
  final Uint8List payload;
  final DateTime at;
}

Object _identity(Object error) => error;

class _AckTimeout {
  const _AckTimeout();
}

class WatchFrameSend {
  WatchFrameSend._(this.generation) {
    // A synchronous disconnect can precede the caller attaching its await.
    _done.future.ignore();
  }
  final int generation;
  int? _seq;
  bool _confirmed = false;
  final _done = Completer<void>();
  int? get sequence => _seq;
  Future<void> get completed => _done.future;
}
