import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../config.dart';
import '../debug/models.dart';
import '../errors.dart';
import '../link/link.dart';
import '../protocol/address.dart';
import '../protocol/message.dart';
import '../protocol/protocol.dart';
import '../protocol/registry.dart';
import '../protocol/status.dart';

final wsTraceZoneKey = Object();

class WSSession {
  WSSession(this.link, this.registry, {this.config = const WSSessionConfig()}) {
    config.validate();
    _subscription = link.payloads.listen(_receive);
    unawaited(link.terminated.then((error) {
      _invalidate(error);
    }));
  }
  final WSLink link;
  final WSProtocolRegistry registry;
  final WSSessionConfig config;
  final Queue<_Request> _queue = Queue();
  final _reports = StreamController<WSDeviceReport>.broadcast(sync: true);
  late final StreamSubscription<WSReceivedPayload> _subscription;
  _Request? _active;
  _ReplyWait? _reply;
  Object? _failure;
  Timer? _replyTimer;
  Future<void>? _disposing;
  int _requestId = 0;
  Stream<WSDeviceReport> get reports => _reports.stream;
  bool get isClosed => _failure != null || link.isClosed;

  /// Debug correlation only; matching still happens in the receive pipeline.
  ({String? requestId, String? traceId})? contextForReply(
      WSProtocolAddress address) {
    if (_reply == null ||
        _reply!.done.isCompleted ||
        _reply!.address != address) {
      return null;
    }
    return (requestId: _active?.id, traceId: _active?.traceId);
  }

  Future<void> send<T>(WSCommand<T> command, T value) =>
      _enqueue<void>(() async {
        registry.checkSend(command.request.address);
        await link.send(
            WSMessage(command.request.address, command.encodeData(value))
                .encode(),
            maxRetries: command.maxRetries ?? command.request.maxRetries,
            requestId: _active!.id,
            traceId: _active!.traceId);
      });
  Future<R> query<T, R>(WSQuery<T, R> query, T value,
          {void Function()? onAcknowledged}) =>
      _enqueue<R>(() async {
        registry.checkSend(query.request.address);
        if (query.reply.address.direction != WSWireDirection.deviceToPhone ||
            registry.lookup(query.reply.address)?.status !=
                WSProtocolStatus.active) {
          throw ArgumentError('invalid reply registration');
        }
        return await _exchange(
            WSMessage(query.request.address, query.encodeData(value)),
            query.reply.address,
            (data) => query.decodeData(data),
            query.replyTimeout ?? config.replyTimeout,
            query.request.maxRetries,
            onAcknowledged: onAcknowledged) as R;
      });

  Future<Uint8List?> sendRaw(
      {required WSProtocolAddress address,
      required Uint8List data,
      WSReplyAddress? replyAddress,
      Duration? replyTimeout}) {
    // Snapshot mutable caller data before the request waits in the queue.
    final copy = Uint8List.fromList(data);
    return _enqueue<Uint8List?>(() async {
      registry.checkSend(address, raw: true);
      replyAddress?.validate();
      if (replyAddress != null &&
          replyAddress.direction != WSWireDirection.deviceToPhone) {
        throw ArgumentError('reply must be device-to-phone');
      }
      final retries = registry.lookup(address)?.maxRetries ??
          (registry.lookup(address)?.status == WSProtocolStatus.active
              ? null
              : 0);
      final message = WSMessage(address, copy);
      if (replyAddress == null) {
        await link.send(message.encode(),
            maxRetries: retries,
            requestId: _active!.id,
            traceId: _active!.traceId);
        return null;
      }
      return await _exchange(message, replyAddress, (bytes) => bytes,
          replyTimeout ?? config.replyTimeout, retries) as Uint8List;
    });
  }

  Future<Object?> _exchange(WSMessage message, WSProtocolAddress address,
      Object? Function(Uint8List) decode, Duration timeout, int? retries,
      {void Function()? onAcknowledged}) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError('reply timeout must be positive');
    }
    final reply = _ReplyWait(address, decode);
    _reply = reply; // Must precede first transport write.
    try {
      await link.send(message.encode(),
          maxRetries: retries,
          requestId: _active!.id,
          traceId: _active!.traceId);
      onAcknowledged?.call();
      if (!reply.done.isCompleted) {
        _replyTimer = Timer(timeout, () {
          if (!reply.done.isCompleted) {
            reply.done.complete(_Outcome.error(const WSTimeoutException(
                WSTimeoutKind.reply, 'L2 reply timed out')));
          }
        });
      }
      final result = await reply.done.future;
      if (result.error != null) {
        if (result.error is WSTimeoutException) {
          const invalid = WSSessionInvalidatedException(
              'query timed out; reconnect before further requests');
          _invalidate(invalid, activeError: result.error);
          unawaited(link.close(invalid));
        }
        Error.throwWithStackTrace(
            result.error!, result.stack ?? StackTrace.current);
      }
      return result.value;
    } on WSTimeoutException catch (error) {
      // Exhausted ACK deadlines leave the same ambiguous late-reply risk.
      if (!isClosed) {
        const invalid = WSSessionInvalidatedException(
            'query timed out; reconnect before further requests');
        _invalidate(invalid, activeError: error);
        unawaited(link.close(invalid));
      }
      rethrow;
    } finally {
      _replyTimer?.cancel();
      _replyTimer = null;
      if (identical(_reply, reply)) _reply = null;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (isClosed) {
      return Future.error(
          _failure ?? const WSDisconnectedException('session closed'));
    }
    if (_active != null && _queue.length >= config.queueCapacity) {
      return Future.error(WSQueueFullException(config.queueCapacity));
    }
    final request = _Request('${link.generation}:${++_requestId}',
        Zone.current[wsTraceZoneKey] as String?, action);
    _queue.add(request);
    if (_active == null) unawaited(_next());
    return request.done.future.then((value) => value as T);
  }

  Future<void> _next() async {
    if (_active != null || _failure != null || _queue.isEmpty) return;
    final request = _queue.removeFirst();
    _active = request;
    try {
      final result = await request.action();
      if (!request.done.isCompleted) request.done.complete(result);
    } catch (error, stack) {
      if (!request.done.isCompleted) request.done.completeError(error, stack);
    } finally {
      if (identical(_active, request)) _active = null;
      if (_failure == null) unawaited(_next());
    }
  }

  void _receive(WSReceivedPayload payload) {
    if (isClosed) return;
    try {
      for (final message
          in WSMessage.decode(payload.bytes, WSWireDirection.deviceToPhone)) {
        if (isClosed) break;
        final waiting = _reply;
        if (waiting != null &&
            !waiting.done.isCompleted &&
            waiting.address == message.address) {
          try {
            waiting.done.complete(_Outcome.value(waiting.decode(message.data)));
          } catch (error, stack) {
            waiting.done.complete(_Outcome.error(
                WSProtocolDecodeException(message.address.cmd,
                    message.address.key, message.data, '$error'),
                stack));
          }
          continue;
        }
        final entry = registry.lookup(message.address);
        final kind = switch (entry?.status) {
          WSProtocolStatus.dropped => WSReportKind.dropped,
          WSProtocolStatus.reserved => WSReportKind.reserved,
          WSProtocolStatus.unimplemented => WSReportKind.unimplemented,
          null => WSReportKind.unknown,
          WSProtocolStatus.active => entry!.isReply
              ? WSReportKind.unsolicitedReply
              : WSReportKind.notification,
        };
        try {
          _report(WSDeviceReport(
              address: message.address,
              kind: kind,
              data: message.data,
              value: registry.decodeReport(message.address, message.data)));
        } catch (error) {
          _report(WSDeviceReport(
              address: message.address,
              kind: WSReportKind.decodeError,
              data: message.data,
              error: error));
        }
      }
    } catch (error) {
      _report(WSDeviceReport(
          address: null,
          kind: WSReportKind.decodeError,
          data: payload.bytes,
          error: error));
    }
  }

  void _report(WSDeviceReport report) {
    if (!_reports.isClosed) _reports.add(report);
  }

  void _invalidate(Object reason, {Object? activeError}) {
    if (_failure != null) return;
    _failure = reason;
    _replyTimer?.cancel();
    if (_reply != null && !_reply!.done.isCompleted) {
      _reply!.done.complete(_Outcome.error(reason));
    }
    if (_active != null && !_active!.done.isCompleted) {
      _active!.done.completeError(activeError ?? reason);
    }
    for (final job in _queue) {
      job.done.completeError(reason);
    }
    _queue.clear();
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _invalidate(const WSDisconnectedException('session disposed'));
    await _subscription.cancel();
    await link.close();
    await _reports.close();
  }
}

class _Request {
  _Request(this.id, this.traceId, this.action);
  final String id;
  final String? traceId;
  final Future<Object?> Function() action;
  final done = Completer<Object?>();
}

class _ReplyWait {
  _ReplyWait(this.address, this.decode);
  final WSProtocolAddress address;
  final Object? Function(Uint8List) decode;
  final done = Completer<_Outcome>();
}

class _Outcome {
  _Outcome.value(this.value)
      : error = null,
        stack = null;
  _Outcome.error(this.error, [this.stack]) : value = null;
  final Object? value, error;
  final StackTrace? stack;
}
