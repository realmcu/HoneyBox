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

/// Executes the HoneyProtocol 0x05 history + today synchronization sequence.
class WatchHealthBleRepository implements WatchHealthRepository {
  WatchHealthBleRepository({
    required WatchHealthCommandAvailable commandAvailable,
    required WatchHealthSendCommand sendCommand,
    required Stream<Uint8List> notifications,
    this.timeout = const Duration(seconds: 10),
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
    final sportItems = <WatchSportItem>[];
    final sleepItems = <WatchSleepItem>[];
    StreamSubscription<Uint8List>? subscription;
    Timer? timer;
    var awaitingToday = false;
    var syncEnded = false;

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
        finishError(TimeoutException(
          awaitingToday
              ? 'Watch today-data response timed out'
              : 'Watch health synchronization timed out',
        ));
      });
    }

    int? send(Uint8List frame) {
      try {
        return _sendCommand(frame);
      } catch (error) {
        finishError(WatchHealthSyncException('Send failed: $error'));
        return null;
      }
    }

    subscription = _notifications.listen((frame) {
      if (completer.isCompleted) return;
      try {
        final events = WatchHealthProtocol.parseFrame(frame);
        if (events.isEmpty) return;
        timer?.cancel();

        for (final event in events) {
          if (event is WatchSportData) {
            sportItems.addAll(event.items);
          } else if (event is WatchSleepData) {
            sleepItems.addAll(event.items);
          } else if (event is WatchHealthSyncEnd) {
            syncEnded = true;
            if (!event.success) {
              finishError(WatchHealthSyncException(
                'Watch reported health sync error ${event.result}',
              ));
              return;
            }
            if (send(WatchHealthProtocol.buildSyncAck()) == null) return;
            awaitingToday = true;
            if (send(WatchHealthProtocol.buildTodayRequest()) == null) return;
          } else if (event is WatchHealthTodayData && awaitingToday) {
            completer.complete(WatchHealthSnapshot.fromRecords(
              syncedAt: _clock(),
              sportRecords: sportItems
                  .map((item) => WatchSportRecord(
                        timestamp: item.timestamp,
                        mode: item.mode,
                        steps: item.steps,
                        caloriesDeciKcal: item.caloriesDeciKcal,
                        distanceMeters: item.distanceMeters,
                        heartRate: item.heartRate,
                        hasHeartRate: item.hasHeartRate,
                        partialBucket: item.partialBucket,
                      ))
                  .toList(growable: false),
              sleepRecords: sleepItems
                  .map((item) => WatchSleepRecord(
                        timestamp: item.timestamp,
                        state: item.state,
                        backfilled: item.backfilled,
                      ))
                  .toList(growable: false),
              todaySteps: event.steps,
              todayDistanceMeters: event.distanceMeters,
              todayCaloriesDeciKcal: event.caloriesDeciKcal,
              latestTodayHeartRate: event.latestHeartRate,
            ));
            timer?.cancel();
            return;
          }
        }

        if (!syncEnded || awaitingToday) resetTimeout();
      } catch (error, stackTrace) {
        finishError(error, stackTrace);
      }
    }, onError: finishError);

    if (send(WatchHealthProtocol.buildRequestAll()) != null) {
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
