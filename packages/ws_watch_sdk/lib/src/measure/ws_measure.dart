import '../connection/ws_link.dart';
import '../debug/ws_debug_log.dart';
import '../honey/honey_measure.dart';

final class WSMeasure {
  WSMeasure({
    required WSLink link,
    required bool Function() isReady,
    Duration replyTimeout = const Duration(seconds: 8),
  })  : _link = link,
        _isReady = isReady,
        _replyTimeout = replyTimeout;

  final WSLink _link;
  final bool Function() _isReady;
  final Duration _replyTimeout;

  Future<void> startHeartRateSpot() async {
    WSWatchDebugLog.apiIn('WSMeasure.startHeartRateSpot');
    _requireReady();
    final reply = await _link.request(
      HoneyMeasureCommand.startHeartRate(),
      replyKey: HoneyMeasureCommand.keyStartHeartRateReply,
      timeout: _replyTimeout,
    );
    if (!HoneyMeasureCommand.isStartHeartRateSuccess(reply)) {
      throw StateError('heart rate spot measure could not start');
    }
  }

  Future<void> stopHeartRateSpot() async {
    WSWatchDebugLog.apiIn('WSMeasure.stopHeartRateSpot');
    _requireReady();
    await _link.send(HoneyMeasureCommand.stopHeartRate());
  }

  void _requireReady() {
    if (!_isReady()) {
      throw StateError('WSMeasure requires an authenticated ready session');
    }
  }
}
