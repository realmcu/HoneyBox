import 'dart:async';
import 'dart:typed_data';

import '../pages/watch/health/watch_health_data.dart';
import 'watch_model_protocol.dart';

typedef WatchHealthCommandAvailable = bool Function();
typedef WatchHealthSendCommand = int? Function(Uint8List frame);
typedef WatchHealthClock = DateTime Function();

class WatchHealthSyncException implements Exception {
  const WatchHealthSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WatchHealthModelRepository implements WatchHealthRepository {
  WatchHealthModelRepository({
    required WatchHealthCommandAvailable commandAvailable,
    required WatchHealthSendCommand sendCommand,
    required Stream<Uint8List> notifications,
    this.timeout = const Duration(seconds: 8),
    WatchHealthClock clock = DateTime.now,
  })  : _commandAvailable = commandAvailable,
        _sendCommand = sendCommand,
        _notifications = notifications,
        _clock = clock;

  final WatchHealthCommandAvailable _commandAvailable;
  final WatchHealthSendCommand _sendCommand;
  final Stream<Uint8List> _notifications;
  final WatchHealthClock _clock;
  final Duration timeout;

  bool _syncing = false;

  @override
  Future<WatchHealthSnapshot> sync(String deviceId) async {
    if (_syncing) {
      throw const WatchHealthSyncException('Health synchronization is busy');
    }
    if (!_commandAvailable()) {
      throw const WatchHealthSyncException('Watch command channel unavailable');
    }

    _syncing = true;
    final completer = Completer<WatchHealthSnapshot>();
    StreamSubscription<Uint8List>? subscription;
    Timer? timer;

    void finishError(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted) return;
      timer?.cancel();
      if (stackTrace == null) {
        completer.completeError(error);
      } else {
        completer.completeError(error, stackTrace);
      }
    }

    void resetTimeout() {
      timer?.cancel();
      timer = Timer(timeout, () {
        finishError(TimeoutException('Watch health synchronization timed out'));
      });
    }

    subscription = _notifications.listen((frame) {
      if (completer.isCompleted) return;
      try {
        final model = WatchModelProtocol.parseSnapshot(frame);
        if (model == null) return;
        timer?.cancel();
        completer.complete(WatchHealthSnapshot.fromModel(
          syncedAt: _clock(),
          model: model,
        ));
      } catch (error, stackTrace) {
        finishError(error, stackTrace);
      }
    }, onError: finishError);

    int? sequence;
    try {
      sequence = _sendCommand(WatchModelProtocol.buildGetRequest());
    } catch (_) {
      sequence = null;
    }
    if (sequence == null) {
      finishError(const WatchHealthSyncException(
        'Failed to send the health data request',
      ));
    } else {
      resetTimeout();
    }

    try {
      return await completer.future;
    } finally {
      timer?.cancel();
      await subscription.cancel();
      _syncing = false;
    }
  }
}
