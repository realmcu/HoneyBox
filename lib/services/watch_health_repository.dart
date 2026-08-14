import 'dart:async';
import 'dart:typed_data';

import '../pages/watch/health/watch_health_data.dart';
import 'watch_health_protocol.dart';

typedef WatchHealthCommandAvailable = bool Function();
typedef WatchHealthSendCommand = int? Function(Uint8List frame);
typedef WatchHealthClock = DateTime Function();

class WatchHealthSyncException implements Exception {
  const WatchHealthSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WatchHealthBleRepository implements WatchHealthRepository {
  WatchHealthBleRepository({
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
    final sports = <WatchSportRecord>[];
    final sleeps = <WatchSleepRecord>[];
    StreamSubscription<Uint8List>? subscription;
    Timer? timer;
    var started = false;

    // Version 1 sessions are per Data type and must not switch mid-flight, so
    // every follow-up request repeats the type the device opened with.
    const dataType = WatchHealthDataType.activity;

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

    bool sendRequest() {
      if (!_commandAvailable()) return false;
      try {
        return _sendCommand(
              WatchHealthProtocol.buildRequest(dataType: dataType),
            ) !=
            null;
      } catch (_) {
        return false;
      }
    }

    subscription = _notifications.listen((frame) {
      if (completer.isCompleted) return;
      try {
        final events = WatchHealthProtocol.parseFrame(frame);
        if (events.isEmpty) return;
        resetTimeout();
        for (final event in events) {
          // Markers for a Data type we didn't ask for belong to no session of
          // ours; ignore them rather than letting them drive the state machine.
          if (event is WatchHealthMarkerEvent && event.dataType != dataType) {
            continue;
          }

          if (event is WatchHealthMarkerEvent &&
              event.marker == WatchHealthMarker.syncStart) {
            started = true;
            sports.clear();
            sleeps.clear();
          } else if (!started) {
            continue;
          } else if (event is WatchSportData) {
            sports.addAll(event.items.map((item) => WatchSportRecord(
                  timestamp: item.timestamp,
                  mode: item.mode,
                  steps: item.steps,
                  caloriesDeciKcal: item.caloriesDeciKcal,
                  distanceMeters: item.distanceMeters,
                  heartRate: item.heartRate,
                  hasHeartRate: item.hasHeartRate,
                  partialBucket: item.partialBucket,
                )));
          } else if (event is WatchSleepData) {
            // Not reachable today: the device has no sleep storage, so an
            // activity session never yields sleep pages. Decoded anyway so a
            // future firmware needs no change here.
            sleeps.addAll(event.items.map((item) => WatchSleepRecord(
                  timestamp: item.timestamp,
                  state: item.state,
                  backfilled: item.backfilled,
                )));
          } else if (event is WatchHealthMarkerEvent &&
              event.marker == WatchHealthMarker.more) {
            if (!sendRequest()) {
              finishError(const WatchHealthSyncException(
                'Failed to request the next health data batch',
              ));
              return;
            }
          } else if (event is WatchHealthMarkerEvent &&
              event.marker == WatchHealthMarker.syncEnd) {
            timer?.cancel();
            completer.complete(WatchHealthSnapshot.fromRecords(
              syncedAt: _clock(),
              sportRecords: sports,
              sleepRecords: sleeps,
            ));
            return;
          }
        }
      } catch (error, stackTrace) {
        finishError(error, stackTrace);
      }
    }, onError: finishError);

    if (!sendRequest()) {
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
