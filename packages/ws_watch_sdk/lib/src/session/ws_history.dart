import '../connection/ws_link.dart';
import '../history/ws_history_models.dart';
import '../history/ws_health_history_sync.dart';
import '../history/ws_history_sync.dart';
import '../history/ws_history_sync_listener.dart';
import '../model/ws_heart_rate.dart';
import '../storage/ws_history_store.dart';

final class WSHistory {
  WSHistory({
    required WSLink link,
    required WSHistoryStore store,
    required WSHistoryScope? Function() scope,
  })  : _link = link,
        _store = store,
        _scope = scope;

  final WSLink _link;
  final WSHistoryStore _store;
  final WSHistoryScope? Function() _scope;

  Future<List<WSHeartRate>> syncHeartRate() async {
    final scope = _scope();
    if (scope == null) {
      throw StateError('history sync requires authenticated ready session');
    }
    final rows = await WSHistorySync.syncHeartRate(_link);
    await _store.replaceHeartRates(scope, rows);
    return rows;
  }

  Future<List<WSHeartRate>> queryHeartRates() async {
    final scope = _scope();
    if (scope == null) {
      throw StateError('history query requires authenticated ready session');
    }
    return _store.queryHeartRates(WSHistoryQuery(scope: scope));
  }

  Future<void> syncHealthData(WSHistorySyncListener listener) {
    final scope = _scope();
    if (scope == null) {
      throw StateError('history sync requires authenticated ready session');
    }
    return WSHealthHistorySync(
      link: _link,
      store: _store,
      scope: scope,
      listener: listener,
    ).run();
  }
}
