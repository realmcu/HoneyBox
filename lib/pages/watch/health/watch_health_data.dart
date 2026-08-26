import '../../../services/watch_health_protocol.dart';

enum WatchHealthPeriod { day, week, month }

/// One 15-minute activity bucket, as stored after a version 1 sync.
///
/// [timestamp] is the natural-quarter bucket start and is authoritative. The
/// record describes `[timestamp, timestamp + 15 minutes)`, including when a
/// partial bucket contains samples for only part of that logical interval.
class WatchSportRecord {
  const WatchSportRecord({
    required this.timestamp,
    required this.mode,
    required this.steps,
    required this.caloriesDeciKcal,
    required this.distanceMeters,
    this.heartRate = 0,
    this.hasHeartRate = false,
    this.partialBucket = false,
  });

  final DateTime timestamp;
  final int mode;
  final int steps;

  /// Calories in 0.1 kcal units, matching the wire format.
  final int caloriesDeciKcal;
  final int distanceMeters;

  /// Bucket-average bpm; meaningful only when [hasHeartRate].
  final int heartRate;
  final bool hasHeartRate;

  /// Device flushed this bucket before its 15 minutes elapsed.
  final bool partialBucket;
}

/// One sleep state transition. Not produced yet -- the device has no sleep
/// storage, so a sync never yields these.
class WatchSleepRecord {
  const WatchSleepRecord({
    required this.timestamp,
    required this.state,
    this.backfilled = false,
  });

  final DateTime timestamp;

  /// See `WatchSleepState` in watch_health_protocol.dart.
  final int state;
  final bool backfilled;
}

class WatchSleepStage {
  const WatchSleepStage({
    required this.state,
    required this.name,
    required this.minutes,
  });

  /// See `WatchSleepState` in watch_health_protocol.dart.
  final int state;
  final String name;
  final int minutes;
}

class WatchHealthTrendPoint {
  const WatchHealthTrendPoint({
    required this.label,
    required this.steps,
    required this.heartRate,
  });

  final String label;
  final int steps;
  final int? heartRate;
}

class WatchHealthTrend {
  const WatchHealthTrend({
    required this.label,
    required this.summary,
    required this.points,
  });

  final String label;
  final String summary;
  final List<WatchHealthTrendPoint> points;
}

class WatchHealthSnapshot {
  WatchHealthSnapshot.fromRecords({
    required this.syncedAt,
    required List<WatchSportRecord> sportRecords,
    required List<WatchSleepRecord> sleepRecords,
  })  : sportRecords = List.unmodifiable(sportRecords),
        sleepRecords = List.unmodifiable(sleepRecords);

  final DateTime syncedAt;
  final List<WatchSportRecord> sportRecords;
  final List<WatchSleepRecord> sleepRecords;

  DateTime get _today =>
      DateTime.utc(syncedAt.year, syncedAt.month, syncedAt.day);

  Iterable<WatchSportRecord> get _todaySport =>
      sportRecords.where((record) => _sameDate(record.timestamp, _today));

  /// Today's buckets that carry a valid average bpm, oldest first.
  ///
  /// Version 1 has no per-sample heart rate stream (key 0x0D is reserved), so
  /// every bpm figure below is a 15-minute bucket average.
  List<WatchSportRecord> get _todayHeartRateBuckets => _todaySport
      .where((record) => record.hasHeartRate && record.heartRate > 0)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  /// Today's buckets carrying a valid average bpm, oldest first. Exposed for
  /// the heart-rate list UI; each entry is a 15-minute average, not a sample.
  List<WatchSportRecord> get heartRateBuckets => _todayHeartRateBuckets;

  int get steps => _todaySport.fold(0, (sum, record) => sum + record.steps);

  int get distanceMeters =>
      _todaySport.fold(0, (sum, record) => sum + record.distanceMeters);

  double get caloriesKcal => _todaySport.fold(
        0,
        (sum, record) => sum + record.caloriesDeciKcal / 10,
      );

  int? get latestHeartRate => _todayHeartRateBuckets.isEmpty
      ? null
      : _todayHeartRateBuckets.last.heartRate;

  int? get minimumHeartRate => _todayHeartRateBuckets.isEmpty
      ? null
      : _todayHeartRateBuckets.map((record) => record.heartRate).reduce(_min);

  int? get maximumHeartRate => _todayHeartRateBuckets.isEmpty
      ? null
      : _todayHeartRateBuckets.map((record) => record.heartRate).reduce(_max);

  List<WatchSleepStage> get sleepStages {
    final records = _sortedSleepRecords();
    final totals = <int, int>{};
    for (var i = 0; i + 1 < records.length; i++) {
      final current = records[i];
      final duration = records[i + 1].timestamp.difference(current.timestamp);
      if ((current.state == WatchSleepState.deep ||
              current.state == WatchSleepState.light) &&
          duration.inMinutes > 0) {
        totals.update(
          current.state,
          (value) => value + duration.inMinutes,
          ifAbsent: () => duration.inMinutes,
        );
      }
    }
    return [
      if ((totals[WatchSleepState.deep] ?? 0) > 0)
        WatchSleepStage(
          state: WatchSleepState.deep,
          name: '深睡',
          minutes: totals[WatchSleepState.deep]!,
        ),
      if ((totals[WatchSleepState.light] ?? 0) > 0)
        WatchSleepStage(
          state: WatchSleepState.light,
          name: '浅睡',
          minutes: totals[WatchSleepState.light]!,
        ),
    ];
  }

  int get sleepMinutes =>
      sleepStages.fold(0, (sum, stage) => sum + stage.minutes);

  String? get sleepRange {
    final records = _sortedSleepRecords();
    final startIndex = records.indexWhere((record) =>
        record.state == WatchSleepState.deep ||
        record.state == WatchSleepState.light);
    if (startIndex < 0) return null;
    final endIndex = records.indexWhere(
      (record) => record.state == WatchSleepState.wake,
      startIndex + 1,
    );
    if (endIndex < 0) return null;
    return '${_time(records[startIndex].timestamp)} - ${_time(records[endIndex].timestamp)}';
  }

  WatchHealthTrend trend(WatchHealthPeriod period) {
    return switch (period) {
      WatchHealthPeriod.day => _dayTrend(),
      WatchHealthPeriod.week => _dailyTrend(7, '近 7 天'),
      WatchHealthPeriod.month => _dailyTrend(30, '近 30 天'),
    };
  }

  WatchHealthTrend _dayTrend() {
    final points = <WatchHealthTrendPoint>[];
    for (var slot = 0; slot < 6; slot++) {
      final startHour = slot * 4;
      final endHour = startHour + 4;
      // Bucket the day by wall-clock hour. Version 0 compared a 15-minute slot
      // index here (offset >= startHour * 4); with real timestamps the hour is
      // read directly, which also stays correct for partial buckets.
      final inSlot = _todaySport.where((record) =>
          record.timestamp.hour >= startHour &&
          record.timestamp.hour < endHour);
      final steps = inSlot.fold(0, (sum, record) => sum + record.steps);
      final heartRates = inSlot
          .where((record) => record.hasHeartRate && record.heartRate > 0)
          .map((record) => record.heartRate)
          .toList();
      points.add(WatchHealthTrendPoint(
        label: '$startHour时',
        steps: steps,
        heartRate: _average(heartRates),
      ));
    }
    return WatchHealthTrend(
      label: '今天 · 分时趋势',
      summary: '今日累计 ${_number(steps)} 步',
      points: List.unmodifiable(points),
    );
  }

  WatchHealthTrend _dailyTrend(int days, String label) {
    final firstDay = _today.subtract(Duration(days: days - 1));
    final points = <WatchHealthTrendPoint>[];
    for (var i = 0; i < days; i++) {
      final date = firstDay.add(Duration(days: i));
      final dayRecords =
          sportRecords.where((record) => _sameDate(record.timestamp, date));
      final daySteps = dayRecords.fold(0, (sum, record) => sum + record.steps);
      final heartRates = dayRecords
          .where((record) => record.hasHeartRate && record.heartRate > 0)
          .map((record) => record.heartRate)
          .toList();
      points.add(WatchHealthTrendPoint(
        label: '${date.month}/${date.day}',
        steps: daySteps,
        heartRate: _average(heartRates),
      ));
    }
    final totalSteps = points.fold(0, (sum, point) => sum + point.steps);
    return WatchHealthTrend(
      label: label,
      summary: '日均 ${_number((totalSteps / days).round())} 步',
      points: List.unmodifiable(points),
    );
  }

  List<WatchSleepRecord> _sortedSleepRecords() =>
      [...sleepRecords]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _min(int a, int b) => a < b ? a : b;
  static int _max(int a, int b) => a > b ? a : b;

  static int? _average(List<int> values) => values.isEmpty
      ? null
      : (values.reduce((a, b) => a + b) / values.length).round();

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static String _number(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

abstract interface class WatchHealthRepository {
  Future<WatchHealthSnapshot> sync(String deviceId);
}
