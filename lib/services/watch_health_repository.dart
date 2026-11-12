import 'dart:async';
import 'dart:typed_data';

import '../pages/watch/health/watch_health_data.dart';
import 'watch_health_protocol.dart';
import 'watch_health_store.dart';

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
    WatchHealthStore? store,
    this.timeout = const Duration(seconds: 10),
    WatchHealthClock clock = DateTime.now,
  })  : _commandAvailable = commandAvailable,
        _sendCommand = sendCommand,
        _notifications = notifications,
        _store = store ?? WatchHealthMemoryStore(),
        _clock = clock;

  final WatchHealthCommandAvailable _commandAvailable;
  final WatchHealthSendCommand _sendCommand;
  final Stream<Uint8List> _notifications;
  final WatchHealthStore _store;
  final WatchHealthClock _clock;
  final Duration timeout;

  bool _syncing = false;

  @override
  Future<WatchHealthSnapshot?> loadCached(String deviceId) =>
      _store.load(deviceId);

  @override
  Future<WatchHealthSnapshot> sync(String deviceId) async {
    if (_syncing) {
      throw const WatchHealthSyncException('Health synchronization is busy');
    }
    if (!_commandAvailable()) {
      throw const WatchHealthSyncException('Watch command channel unavailable');
    }

    _syncing = true;
    WatchHealthSnapshot? cached;
    try {
      cached = await _store.load(deviceId);
    } catch (error) {
      _syncing = false;
      throw WatchHealthSyncException(
          'Unable to read cached health data: $error');
    }

    final completer = Completer<WatchHealthSnapshot>();
    final sportItems = <WatchSportItem>[];
    final sleepItems = <WatchSleepItem>[];
    StreamSubscription<Uint8List>? subscription;
    Timer? timer;
    Future<void> queue = Future<void>.value();
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

    Future<void> handleFrame(Uint8List frame) async {
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

            final historySnapshot = _mergeWatchHealthSnapshot(
              cached: cached,
              sportItems: sportItems,
              sleepItems: sleepItems,
              syncedAt: _clock(),
            );
            try {
              await _store.save(deviceId, historySnapshot);
            } catch (error) {
              finishError(WatchHealthSyncException(
                'Unable to persist history before 0x42: $error',
              ));
              return;
            }
            if (completer.isCompleted) return;
            cached = historySnapshot;

            if (send(WatchHealthProtocol.buildSyncAck()) == null) return;
            awaitingToday = true;
            if (send(WatchHealthProtocol.buildTodayRequest()) == null) return;
          } else if (event is WatchHealthTodayData && awaitingToday) {
            final snapshot = _mergeWatchHealthSnapshot(
              cached: cached,
              sportItems: sportItems,
              sleepItems: sleepItems,
              syncedAt: _clock(),
              today: event,
            );
            try {
              await _store.save(deviceId, snapshot);
            } catch (error) {
              finishError(WatchHealthSyncException(
                'Unable to persist today data: $error',
              ));
              return;
            }
            if (completer.isCompleted) return;
            completer.complete(snapshot);
            timer?.cancel();
            return;
          }
        }

        if (!syncEnded || awaitingToday) resetTimeout();
      } catch (error, stackTrace) {
        finishError(error, stackTrace);
      }
    }

    subscription = _notifications.listen((frame) {
      queue = queue.then((_) async {
        try {
          await handleFrame(frame);
        } catch (error, stackTrace) {
          finishError(error, stackTrace);
        }
      });
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

WatchHealthSnapshot _mergeWatchHealthSnapshot({
  required WatchHealthSnapshot? cached,
  required List<WatchSportItem> sportItems,
  required List<WatchSleepItem> sleepItems,
  required DateTime syncedAt,
  WatchHealthTodayData? today,
}) {
  final sportByKey = <String, WatchSportRecord>{};
  for (final record in cached?.sportRecords ?? const <WatchSportRecord>[]) {
    sportByKey[_sportKey(record.timestamp, record.mode)] = record;
  }
  for (final item in sportItems) {
    sportByKey[_sportKey(item.timestamp, item.mode)] = WatchSportRecord(
      timestamp: item.timestamp,
      mode: item.mode,
      steps: item.steps,
      caloriesDeciKcal: item.caloriesDeciKcal,
      distanceMeters: item.distanceMeters,
      heartRate: item.heartRate,
      hasHeartRate: item.hasHeartRate,
      partialBucket: item.partialBucket,
    );
  }

  final sleepByTimestamp = <int, WatchSleepRecord>{};
  for (final record in cached?.sleepRecords ?? const <WatchSleepRecord>[]) {
    sleepByTimestamp[record.timestamp.millisecondsSinceEpoch] = record;
  }
  for (final item in sleepItems) {
    sleepByTimestamp[item.timestamp.millisecondsSinceEpoch] = WatchSleepRecord(
      timestamp: item.timestamp,
      state: item.state,
      backfilled: item.backfilled,
    );
  }

  final sports = sportByKey.values.toList(growable: false)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final sleeps = sleepByTimestamp.values.toList(growable: false)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  return WatchHealthSnapshot.fromRecords(
    syncedAt: syncedAt,
    sportRecords: sports,
    sleepRecords: sleeps,
    todaySteps: today?.steps ?? cached?.todaySteps,
    todayDistanceMeters: today?.distanceMeters ?? cached?.todayDistanceMeters,
    todayCaloriesDeciKcal:
        today?.caloriesDeciKcal ?? cached?.todayCaloriesDeciKcal,
    latestTodayHeartRate:
        today?.latestHeartRate ?? cached?.latestTodayHeartRate,
  );
}

String _sportKey(DateTime timestamp, int mode) =>
    '${timestamp.millisecondsSinceEpoch}:$mode';
