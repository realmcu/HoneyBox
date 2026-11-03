import 'dart:async';
import 'dart:typed_data';

import '../errors.dart';
import '../model/frame.dart';
import '../link/frame_log.dart';
import '../protocol/address.dart';
import '../protocol/message.dart';
import '../protocol/status.dart';
import '../protocol/core_registry.dart';
import '../session/session.dart';
import 'models.dart';

class WSRawRequest {
  WSRawRequest(
      {required this.cmd,
      required this.version,
      required this.key,
      required List<int> data,
      this.settingOpcode,
      this.replyAddress,
      this.replyTimeout})
      : data = Uint8List.fromList(data).asUnmodifiableView();
  final int cmd, version, key;
  final int? settingOpcode;
  final Uint8List data;
  final WSReplyAddress? replyAddress;
  final Duration? replyTimeout;
}

class WSProtocolView {
  const WSProtocolView(
      {required this.address,
      required this.name,
      required this.specRef,
      required this.status,
      this.reason});
  final WSProtocolAddress address;
  final String name, specRef;
  final WSProtocolStatus status;
  final String? reason;
}

abstract interface class WSDebugApi {
  Stream<WSFrameEvent> get frames;
  Stream<WSDeviceReport> get reports;
  List<WSProtocolView> get protocols;
  Future<T> trace<T>(String traceId, Future<T> Function() action);
  Future<Uint8List?> sendRaw(WSRawRequest request);
}

/// Internal bridge. M3 attaches only the prepared/authorized current session.
class WSDebugController implements WSDebugApi {
  final _frames = StreamController<WSFrameEvent>.broadcast(sync: true);
  final _reports = StreamController<WSDeviceReport>.broadcast(sync: true);
  WSSession? _session;
  StreamSubscription<WSLinkEvent>? _frameSubscription;
  StreamSubscription<WSDeviceReport>? _reportSubscription;
  bool _disposed = false;
  Future<void>? _disposing;
  bool Function()? _allowRaw;

  void attach(WSSession session, {required bool Function() allowRaw}) {
    if (_disposed) throw const WSDisposedException();
    if (_session != null) throw StateError('detach the previous session first');
    _session = session;
    _attachedViews = _views(session);
    _allowRaw = allowRaw;
    _frameSubscription = session.link.frames.listen((event) {
      if (_disposed || !identical(session, _session)) return;
      var keys = <WSKeyView>[];
      String? requestId = event.requestId, traceId = event.traceId;
      if ((event.kind == WSFrameKind.data || event.kind == WSFrameKind.retry) &&
          event.raw.length >= 8) {
        try {
          keys = WSMessage.decode(
                  event.raw.sublist(8),
                  event.direction == WSFrameDirection.tx
                      ? WSWireDirection.phoneToDevice
                      : WSWireDirection.deviceToPhone)
              .map((m) {
            if (event.direction == WSFrameDirection.rx) {
              final context = session.contextForReply(m.address);
              requestId ??= context?.requestId;
              traceId ??= context?.traceId;
            }
            final entry = session.registry.lookup(m.address);
            return WSKeyView(m.address, entry?.name, entry?.status);
          }).toList();
        } catch (_) {/* A malformed payload remains visible as raw bytes. */}
      }
      _frames.add(WSFrameEvent(
          direction: event.direction,
          kind: event.kind,
          raw: event.raw,
          seq: event.seq,
          requestId: requestId,
          traceId: traceId,
          connectionGeneration: event.connectionGeneration,
          time: event.time,
          keys: List.unmodifiable(keys)));
    });
    _reportSubscription = session.reports.listen((report) {
      if (!_disposed && identical(session, _session)) _reports.add(report);
    });
  }

  Future<void> detach() async {
    _session = null;
    _attachedViews = null;
    _allowRaw = null;
    await _frameSubscription?.cancel();
    await _reportSubscription?.cancel();
    _frameSubscription = null;
    _reportSubscription = null;
  }

  @override
  Stream<WSFrameEvent> get frames => _frames.stream;
  @override
  Stream<WSDeviceReport> get reports => _reports.stream;
  static List<WSProtocolView> _views(WSSession? session) => List.unmodifiable(
      (session?.registry ?? WSInitializationProtocol.registry()).entries.map(
          (e) => WSProtocolView(
              address: e.address,
              name: e.name,
              specRef: e.specRef,
              status: e.status,
              reason: e.reason)));
  static final _defaultViews = _views(null);
  List<WSProtocolView>? _attachedViews;
  @override
  List<WSProtocolView> get protocols => _attachedViews ?? _defaultViews;
  @override
  Future<T> trace<T>(String traceId, Future<T> Function() action) async {
    if (_disposed) throw const WSDisposedException();
    return await runZoned(action, zoneValues: {wsTraceZoneKey: traceId});
  }

  @override
  Future<Uint8List?> sendRaw(WSRawRequest request) async {
    if (_disposed) throw const WSDisposedException();
    final session = _session;
    if (session == null || session.isClosed || _allowRaw?.call() != true) {
      throw const WSSessionInvalidatedException(
          'no prepared session for raw requests');
    }
    return session.sendRaw(
        address: WSProtocolAddress(
            cmd: request.cmd,
            version: request.version,
            key: request.key,
            settingOpcode: request.settingOpcode,
            direction: WSWireDirection.phoneToDevice),
        data: request.data,
        replyAddress: request.replyAddress,
        replyTimeout: request.replyTimeout);
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await detach();
    await _frames.close();
    await _reports.close();
  }
}
