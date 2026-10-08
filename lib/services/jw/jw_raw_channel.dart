import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'jw_codec.dart';
import 'jw_transport.dart';

/// A single connection's raw port. No legacy L1 or command provider sees it.
class JwRawChannel implements JwTransport, JwImmediateAlertTransport {
  @override
  final int mtu;
  @override
  final Stream<Uint8List> notifications;
  @override
  final Stream<void> disconnected;
  final Future<void> Function() subscribeFn;
  final Future<void> Function(Uint8List, {required bool withResponse}) writeFn;
  final Future<Uint8List?> Function(String) readFn;
  final Future<void> Function() disconnectFn;
  final Future<void> Function(Uint8List)? immediateAlertWriteFn;
  final bool immediateAlertWithResponse;
  final _alertAttempts =
      StreamController<JwImmediateAlertAttempt>.broadcast(sync: true);
  @override
  bool get immediateAlertAvailable => _alive && immediateAlertWriteFn != null;
  @override
  Stream<JwImmediateAlertAttempt> get immediateAlertAttempts =>
      _alertAttempts.stream;
  @override
  Future<void> writeImmediateAlert(bool enabled) {
    if (!_alive || !_subscribed) {
      return Future.error(StateError('JW channel not ready'));
    }
    final write = immediateAlertWriteFn;
    if (write == null) {
      return Future.error(StateError('IAS endpoint unavailable'));
    }
    final level = enabled ? 2 : 0;
    final queued = _tail.then((_) async {
      _check();
      _alertAttempts.add(JwImmediateAlertAttempt(level,
          withResponse: immediateAlertWithResponse));
      await write(Uint8List.fromList([level]));
      _check();
    });
    _tail = queued.catchError((Object _) {});
    return _cancelOnDisconnect(queued);
  }

  final _abort = Completer<void>();
  late final StreamSubscription<void> _downSub;
  Future<void>? _subscribeFuture;
  Future<void> _tail = Future.value();
  bool _alive = true;
  bool _subscribed = false;
  JwRawChannel(
      {required this.mtu,
      required this.notifications,
      required this.disconnected,
      required this.subscribeFn,
      required this.writeFn,
      required this.readFn,
      required this.disconnectFn,
      this.immediateAlertWriteFn,
      this.immediateAlertWithResponse = true}) {
    _downSub = disconnected.listen((_) => invalidate());
  }
  void _check() {
    if (!_alive) throw StateError('JW channel disconnected');
  }

  Future<T> _cancelOnDisconnect<T>(Future<T> operation) => Future.any([
        operation,
        _abort.future
            .then<T>((_) => throw StateError('JW channel disconnected'))
      ]);
  @override
  Future<void> subscribe() => _subscribeFuture ??= _subscribe();
  Future<void> _subscribe() async {
    _check();
    await _cancelOnDisconnect(subscribeFn());
    _check();
    _subscribed = true;
  }

  @override
  Future<void> write(Uint8List frame, {required bool withResponse}) {
    if (!_alive || !_subscribed) {
      return Future.error(StateError('JW channel not ready'));
    }
    if (!withResponse ||
        frame.length > JwCodec.maxFrameLength ||
        frame.isEmpty) {
      return Future.error(ArgumentError('JW requires bounded response writes'));
    }
    final bytes = Uint8List.fromList(frame);
    final queued = _tail.then((_) async {
      _check();
      final size = (mtu - 3).clamp(1, JwCodec.maxFrameLength).toInt();
      for (var offset = 0; offset < bytes.length; offset += size) {
        _check();
        await writeFn(bytes.sublist(offset, min(offset + size, bytes.length)),
            withResponse: true);
      }
      _check();
    });
    _tail = queued.catchError((Object _) {});
    return _cancelOnDisconnect(queued);
  }

  @override
  Future<Uint8List?> read(String uuid) {
    _check();
    return _cancelOnDisconnect(readFn(uuid));
  }

  /// Called by the owning manager before tearing down its characteristic handles.
  void invalidate() {
    if (!_alive) return;
    _alive = false;
    _subscribed = false;
    _abort.complete();
    unawaited(_alertAttempts.close());
    unawaited(_downSub.cancel());
  }

  @override
  Future<void> disconnect() async {
    invalidate();
    await disconnectFn();
  }
}
