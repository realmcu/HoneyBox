import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import '../config.dart';
import '../model/frame.dart';
import 'frame_log.dart';
import '../errors.dart';
import '../transport/connection.dart';
import 'frame.dart';
import 'frame_assembler.dart';

class WSReceivedPayload {
  WSReceivedPayload(this.seq, this.bytes);
  final int seq;
  final Uint8List bytes;
}

class WSLink {
  WSLink(this.connection,
      {this.config = const WSLinkConfig(), this.generation = 1}) {
    config.validate();
    if (connection.maxWriteLength <= 0) {
      throw ArgumentError('invalid write limit');
    }
    _assembler = WSFrameAssembler(
        timeout: config.rxAssembleTimeout,
        maxPayloadLength: config.maxPayloadLength,
        onFrame: _receive,
        onError: (kind, raw, seq) {
          _event(WSFrameDirection.rx, kind, raw, seq: seq);
          if (seq != null) _acknowledge(seq, error: true);
        });
    _rx = connection.received.listen(_assembler.add,
        onError: (Object error, StackTrace stack) {
      unawaited(close(WSDisconnectedException('receive failed: $error')));
    }, onDone: () {
      unawaited(close(const WSDisconnectedException('receive stream ended')));
    });
    _disconnect = connection.disconnected.listen((_) {
      unawaited(close(const WSDisconnectedException('transport disconnected')));
    });
  }
  final WSTransportConnection connection;
  final WSLinkConfig config;
  final int generation;
  final _payloads = StreamController<WSReceivedPayload>.broadcast(sync: true);
  final _events = StreamController<WSLinkEvent>.broadcast(sync: true);
  final _ended = Completer<Object>();
  final Set<void Function(Object)> _interrupts = {};
  late final WSFrameAssembler _assembler;
  late final StreamSubscription<Uint8List> _rx;
  late final StreamSubscription<void> _disconnect;
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
  Stream<WSReceivedPayload> get payloads => _payloads.stream;
  Stream<WSLinkEvent> get frames => _events.stream;
  Future<Object> get terminated => _ended.future;
  bool get isClosed => _failure != null;
  int get bufferedBytes => _assembler.bufferedBytes;

  Future<void> send(Uint8List payload,
      {int? maxRetries, String? requestId, String? traceId}) {
    final copy = Uint8List.fromList(payload);
    if (copy.length > config.maxPayloadLength) {
      return Future.error(ArgumentError('payload too large'));
    }
    final retries = maxRetries ?? config.maxRetries;
    if (retries < 0) {
      return Future.error(ArgumentError('maxRetries must be nonnegative'));
    }
    final task =
        _dataTail.then((_) => _send(copy, retries, requestId, traceId));
    _dataTail = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<void> _send(Uint8List payload, int retries, String? requestId,
      String? traceId) async {
    _checkOpen();
    final seq = _seq;
    _seq = (_seq + 1) & 0xffff;
    final raw = WSFrame(seq: seq, payload: payload).encode();
    try {
      for (var attempt = 0; attempt <= retries; attempt++) {
        _checkOpen();
        final waiter = Completer<bool>();
        _ack = waiter;
        _ackSeq = seq;
        _ackRequestId = requestId;
        _ackTraceId = traceId;
        _event(WSFrameDirection.tx,
            attempt == 0 ? WSFrameKind.data : WSFrameKind.retry, raw,
            seq: seq, requestId: requestId, traceId: traceId);
        await _queueWrite(raw, seq, requestId, traceId, false);
        try {
          final ok = await _deadline(waiter.future, config.ackTimeout,
              const WSTimeoutException(WSTimeoutKind.ack, 'L1 ACK timed out'));
          if (ok) return;
          if (attempt == retries) {
            throw const WSNackException('ERR ACK retries exhausted');
          }
        } on WSTimeoutException {
          if (attempt == retries) rethrow;
        }
      }
    } finally {
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
    final job = _WriteJob(raw, seq, requestId, traceId);
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
            final limit = connection.maxWriteLength;
            if (limit <= 0) throw StateError('invalid transport write limit');
            final end = min(offset + limit, job.raw.length);
            final chunk = Uint8List.fromList(job.raw.sublist(offset, end));
            _event(WSFrameDirection.tx, WSFrameKind.chunk, chunk,
                seq: job.seq, requestId: job.requestId, traceId: job.traceId);
            _checkOpen();
            await _deadline(
                connection.write(chunk),
                config.chunkWriteTimeout,
                const WSTimeoutException(
                    WSTimeoutKind.write, 'chunk write timed out'));
            offset = end;
          }
          job.done.complete();
        } catch (error, stack) {
          // The peer may hold a partial frame. Never append a fresh frame to it.
          unawaited(close(error));
          if (!job.done.isCompleted) job.done.completeError(error, stack);
        }
      }
    } finally {
      _writing = false;
    }
  }

  void _receive(WSFrame frame, Uint8List raw) {
    if (isClosed) return;
    _event(
        WSFrameDirection.rx,
        frame.isAck
            ? (frame.isError ? WSFrameKind.errAck : WSFrameKind.ack)
            : WSFrameKind.data,
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
    _acknowledge(frame.seq);
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
      _event(WSFrameDirection.rx, WSFrameKind.sequenceConflict, raw,
          seq: frame.seq);
    }
    _seen.add(_SeenFrame(frame.seq, frame.payload, now));
    while (_seen.length > config.deduplicationCapacity) {
      _seen.removeFirst();
    }
    if (!isClosed) _payloads.add(WSReceivedPayload(frame.seq, frame.payload));
  }

  void _acknowledge(int seq, {bool error = false}) {
    if (isClosed) return;
    final raw = WSFrame(seq: seq, isAck: true, isError: error).encode();
    _event(
        WSFrameDirection.tx, error ? WSFrameKind.errAck : WSFrameKind.ack, raw,
        seq: seq);
    unawaited(
        _queueWrite(raw, seq, null, null, true).catchError((Object _) {}));
  }

  void _event(WSFrameDirection direction, WSFrameKind kind, List<int> raw,
      {int? seq, String? requestId, String? traceId}) {
    if (!_events.isClosed) {
      _events.add(WSLinkEvent(
          direction: direction,
          kind: kind,
          raw: raw,
          seq: seq,
          requestId: requestId,
          traceId: traceId,
          connectionGeneration: generation));
    }
  }

  void _checkOpen() {
    if (_failure != null) throw _failure!;
  }

  Future<void> close(
      [Object reason = const WSDisconnectedException('link closed')]) {
    if (_closing != null) return _closing!;
    _failure = reason;
    _ended.complete(reason);
    for (final interrupt in _interrupts.toList()) {
      interrupt(reason);
    }
    _interrupts.clear();
    _assembler.dispose();
    _seen.clear();
    for (final job in [..._acks, ..._data]) {
      job.done.completeError(reason);
    }
    _acks.clear();
    _data.clear();
    _closing = _cleanup();
    return _closing!;
  }

  Future<void> _cleanup() async {
    await _rx.cancel();
    await _disconnect.cancel();
    try {
      await connection.disconnect();
    } catch (_) {/* Still release local resources. */}
    try {
      await connection.dispose();
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
  _WriteJob(this.raw, this.seq, this.requestId, this.traceId);
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
