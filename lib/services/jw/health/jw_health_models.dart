import '../history/jw_history_models.dart';

enum JwHealthPeriod { day, week }

enum JwHealthMetric {
  heartRate,
  bloodOxygen,
  skinTemperature,
  hrv,
  pressure,
  bloodPressure
}

enum JwSleepStage { nonWorn, light, deep, awake, rem }

/// UTC containers carry device wall-clock components, not UTC instants.
/// Week is the selected calendar day and its six preceding days.
DateTime jwHealthDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
String jwHealthDayKey(DateTime date) => date.toIso8601String().substring(0, 10);

class JwHealthTotals {
  final int? steps;
  final double? distanceMeters, energyKcal, sleepMinutes;
  const JwHealthTotals(
      {this.steps, this.distanceMeters, this.energyKcal, this.sleepMinutes});
}

class JwHealthDay {
  final DateTime date;
  final JwHealthTotals totals;
  const JwHealthDay({required this.date, required this.totals});
}

/// Hourly totals from observed quarter-hour activity records.
/// Null fields are unobserved; a measured zero remains zero.
class JwHealthActivityBin {
  final DateTime start, end;
  final int? steps;
  final double? distanceMeters, energyKcal;
  const JwHealthActivityBin(
      {required this.start,
      required this.end,
      this.steps,
      this.distanceMeters,
      this.energyKcal});
}

/// Device daily statistics retain decoder field names and record provenance.
/// These statistics never represent timestamped raw samples.
class JwHealthDailySummary {
  final DateTime date;
  final String recordId;
  final Map<String, num> values;
  final Set<String> issues;
  JwHealthDailySummary(
      {required this.date,
      required this.recordId,
      required Map<String, num> values,
      Iterable<String> issues = const []})
      : values = Map.unmodifiable(values),
        issues = Set.unmodifiable(issues);
}

class JwHealthSample {
  final DateTime time;
  final double value;
  final double? secondaryValue;
  final String recordId;
  const JwHealthSample(
      {required this.time,
      required this.value,
      required this.recordId,
      this.secondaryValue});
}

class JwHealthMetricSeries {
  final JwHealthMetric metric;

  /// Null means no live capability information; saved samples remain visible.
  final bool? supported;
  final List<JwHealthSample> samples;
  JwHealthMetricSeries(
      {required this.metric,
      this.supported,
      required Iterable<JwHealthSample> samples})
      : samples = List.unmodifiable(samples);
  double? get average => samples.isEmpty
      ? null
      : samples.fold<double>(0, (sum, s) => sum + s.value) / samples.length;
  double? get minimum => samples.isEmpty
      ? null
      : samples.map((s) => s.value).reduce((a, b) => a < b ? a : b);
  double? get maximum => samples.isEmpty
      ? null
      : samples.map((s) => s.value).reduce((a, b) => a > b ? a : b);
}

class JwHealthSleepSegment {
  final DateTime start, end;
  final JwSleepStage stage;
  final String recordId;
  const JwHealthSleepSegment(
      {required this.start,
      required this.end,
      required this.stage,
      required this.recordId});
  double get minutes => end.difference(start).inSeconds / 60;
  bool get isSleep =>
      stage == JwSleepStage.light ||
      stage == JwSleepStage.deep ||
      stage == JwSleepStage.rem;
}

class JwHealthCoverage {
  final int recordCount;
  final Set<String> partialRecordIds, daysWithRecords, issues;
  final Set<String> selectedRecordIssues, storageIssues;

  /// Null preserves legacy constructors that do not identify selected records.
  /// Aggregation supplies IDs in the period and contributing sleep boundaries.
  final Set<String>? selectedRecordIds;
  JwHealthCoverage(
      {required this.recordCount,
      Iterable<String> partialRecordIds = const [],
      Iterable<String> daysWithRecords = const [],
      Iterable<String> issues = const [],
      Iterable<String>? selectedRecordIssues,
      Iterable<String> storageIssues = const [],
      Iterable<String>? selectedRecordIds})
      : partialRecordIds = Set.unmodifiable(partialRecordIds),
        daysWithRecords = Set.unmodifiable(daysWithRecords),
        selectedRecordIssues = Set.unmodifiable(selectedRecordIssues ?? issues),
        storageIssues = Set.unmodifiable(storageIssues),
        issues = Set.unmodifiable(
            {...issues, ...?selectedRecordIssues, ...storageIssues}),
        selectedRecordIds = selectedRecordIds == null
            ? null
            : Set.unmodifiable(selectedRecordIds);
  bool get hasPartialData => partialRecordIds.isNotEmpty;

  /// A saved local journal does not prove the device dataset is exhaustive.
  bool get deviceDatasetExhaustive => false;
}

class JwHealthSnapshot {
  final String deviceKey;
  final DateTime date, start, endExclusive;
  final JwHealthPeriod period;
  final JwHealthTotals totals;
  final List<JwHealthDay> days;
  final Map<JwHealthMetric, JwHealthMetricSeries> metrics;
  final List<JwHealthActivityBin> activityBins;
  final List<JwHealthDailySummary> dailySummaries;
  final List<JwHealthSleepSegment> sleepSegments;
  final List<JwHistoryRecord> sportRecords;
  final JwHealthCoverage coverage;
  final List<DateTime> availableDates;
  JwHealthSnapshot(
      {required this.deviceKey,
      required this.date,
      required this.start,
      required this.endExclusive,
      required this.period,
      required this.totals,
      required Iterable<JwHealthDay> days,
      Iterable<JwHealthActivityBin> activityBins = const [],
      Iterable<JwHealthDailySummary> dailySummaries = const [],
      required Map<JwHealthMetric, JwHealthMetricSeries> metrics,
      required Iterable<JwHealthSleepSegment> sleepSegments,
      required Iterable<JwHistoryRecord> sportRecords,
      required this.coverage,
      required Iterable<DateTime> availableDates})
      : days = List.unmodifiable(days),
        activityBins = List.unmodifiable(activityBins),
        dailySummaries = List.unmodifiable(dailySummaries),
        metrics = Map.unmodifiable(metrics),
        sleepSegments = List.unmodifiable(sleepSegments),
        sportRecords = List.unmodifiable(sportRecords),
        availableDates = List.unmodifiable(availableDates);
  int get stepsValidDayCount =>
      days.where((d) => d.totals.steps != null).length;
  double? get stepsDayAverage => _dayAverage(
      days.map((d) => d.totals.steps?.toDouble()).whereType<double>());
  int get sleepValidDayCount =>
      days.where((d) => d.totals.sleepMinutes != null).length;
  double? get sleepDayAverage =>
      _dayAverage(days.map((d) => d.totals.sleepMinutes).whereType<double>());

  static double? _dayAverage(Iterable<double> values) {
    var count = 0;
    var total = 0.0;
    for (final value in values) {
      count++;
      total += value;
    }
    return count == 0 ? null : total / count;
  }

  JwHealthSnapshot withPersistence(
          {required Iterable<String> partialRecordIds,
          required Iterable<DateTime> availableDates,
          Iterable<String> issues = const []}) =>
      JwHealthSnapshot(
          deviceKey: deviceKey,
          date: date,
          start: start,
          endExclusive: endExclusive,
          period: period,
          totals: totals,
          days: days,
          activityBins: activityBins,
          dailySummaries: dailySummaries,
          metrics: metrics,
          sleepSegments: sleepSegments,
          sportRecords: sportRecords,
          coverage: JwHealthCoverage(
              recordCount: coverage.recordCount,
              daysWithRecords: coverage.daysWithRecords,
              issues: coverage.issues,
              selectedRecordIssues: coverage.selectedRecordIssues,
              storageIssues: {...coverage.storageIssues, ...issues},
              selectedRecordIds: coverage.selectedRecordIds,
              partialRecordIds: partialRecordIds.where((id) =>
                  coverage.selectedRecordIds == null ||
                  coverage.selectedRecordIds!.contains(id))),
          availableDates: availableDates);
}
