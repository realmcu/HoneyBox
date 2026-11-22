import 'dart:async';

import '../connection/ws_link.dart';
import '../data/ws_data_models.dart';
import '../history/ws_history_models.dart';
import '../history/ws_health_codecs.dart';
import '../history/ws_health_history_sync.dart';
import '../history/ws_history_sync_listener.dart';
import '../storage/ws_history_store.dart';
import '../wire/ws_data_command.dart';
import '../wire/ws_data_extra_codec.dart';
import '../wire/ws_l2_message.dart';

final class WSHistory {
  WSHistory({
    required WSLink link,
    required WSHistoryStore store,
    required WSHistoryScope? Function() scope,
    bool Function()? isSessionSyncActive,
  })  : _link = link,
        _store = store,
        _scope = scope,
        _isSessionSyncActive = isSessionSyncActive;

  final WSLink _link;
  final WSHistoryStore _store;
  final WSHistoryScope? Function() _scope;
  final bool Function()? _isSessionSyncActive;
  bool _sportDetailActive = false;
  bool _healthSyncActive = false;

  bool get _historyOperationActive =>
      _healthSyncActive || (_isSessionSyncActive?.call() ?? false);

  Future<WSDeviceDataCapabilities> queryDeviceDataCapabilities() async {
    final reply = await _link.request(
      WSDataCommand.queryDeviceCapabilities(),
      replyKey: WSDataCommand.keyDeviceCapabilities,
      timeout: const Duration(seconds: 1),
    );
    return WSDataExtraCodec.decodeCapabilities(reply.value);
  }

  Future<WSSportDetail> fetchSportDetail(int sportId) async {
    if (_sportDetailActive) throw StateError('sport detail already active');
    if (_historyOperationActive) {
      throw StateError('sport detail is not allowed during health sync');
    }
    _sportDetailActive = true;
    final points = <WSSportDetailPoint>[];
    final done = Completer<void>();
    late final StreamSubscription<WSL2Message> sub;
    sub = _link.incoming.listen((message) {
      if (message.command != WSDataCommand.command ||
          message.version != WSDataCommand.version ||
          message.key != WSDataCommand.keySportDetail) return;
      try {
        final frame = WSDataExtraCodec.decodeSportDetailFrame(message.value);
        if (frame.sportId != sportId) return;
        points.addAll(frame.points);
        if (!frame.more && !done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    });
    try {
      await _link.send(WSDataCommand.sportDetailRequest(sportId));
      await done.future.timeout(const Duration(seconds: 10));
      return WSSportDetail(sportId: sportId, points: List.unmodifiable(points));
    } finally {
      _sportDetailActive = false;
      await sub.cancel();
    }
  }

  Future<List<WSHeartRate>> syncHeartRate() async {
    final scope = _scope();
    if (scope == null) {
      throw StateError(
        'history operation requires historyScope (set userId via login/bind)',
      );
    }
    if (_sportDetailActive || _historyOperationActive) {
      throw StateError('history operation already active');
    }
    _healthSyncActive = true;
    final rows = <WSHeartRate>[];
    try {
      await WSHealthHistorySync(
        link: _link,
        store: _store,
        scope: scope,
        listener: const WSHistorySyncNoOpListener(),
        syncKey: WSDataCommand.keySyncHeartRate,
        onHistoryFrame: (frame) {
          if (frame.key == WSDataCommand.keyDataHeartRate) {
            rows.addAll(WSHealthCodecs.decodeHeartRateDataFrame(
              frame.toMessage(),
            ));
          }
        },
      ).run();
      return List.unmodifiable(rows);
    } finally {
      _healthSyncActive = false;
    }
  }

  Future<List<WSHeartRate>> queryHeartRates() async {
    final scope = _scope();
    if (scope == null) {
      throw StateError(
        'history operation requires historyScope (set userId via login/bind)',
      );
    }
    return _store.queryHeartRates(WSHistoryQuery(scope: scope));
  }

  Future<void> syncHealthData(
    WSHistorySyncListener listener, {
    int syncKey = WSDataCommand.keySyncAll,
  }) {
    final scope = _scope();
    if (scope == null) {
      throw StateError(
        'history operation requires historyScope (set userId via login/bind)',
      );
    }
    if (_sportDetailActive || _historyOperationActive) {
      throw StateError('history operation already active');
    }
    _healthSyncActive = true;
    return WSHealthHistorySync(
      link: _link,
      store: _store,
      scope: scope,
      listener: listener,
      syncKey: syncKey,
    ).run().whenComplete(() => _healthSyncActive = false);
  }
}
