import '../history/jw_history_models.dart';
import '../jw_models.dart';
import 'jw_health_models.dart';

class JwHealthAggregator {
  static JwHealthSnapshot aggregate(
      {required String deviceKey,
      required Iterable<JwHistoryRecord> records,
      required DateTime date,
      required JwHealthPeriod period,
      JwCapabilities? capabilities}) {
    final selected = jwHealthDate(date);
    final start = selected
        .subtract(Duration(days: period == JwHealthPeriod.week ? 6 : 0));
    final end = selected.add(const Duration(days: 1));
    final unique = <String, JwHistoryRecord>{};
    for (final row in records) {
      if (row.deviceKey != deviceKey) continue;
      final previous = unique[row.recordId];
      // Replays retain the original first-seen provenance.
      if (previous == null || _revisionOrder(row, previous) < 0) {
        unique[row.recordId] = row;
      }
    }
    final latest = <(JwHistoryType, String), JwHistoryRecord>{};
    for (final row in unique.values) {
      final key = (row.type, row.sourceIdentity);
      final previous = latest[key];
      if (previous == null || _revisionOrder(row, previous) > 0) {
        latest[key] = row;
      }
    }
    final rows = latest.values.toList()..sort(_timeOrder);
    bool inPeriod(JwHistoryRecord r) {
      final d = _calendar(r.day);
      return d != null && !d.isBefore(start) && d.isBefore(end);
    }

    final selectedRows = rows.where(inPeriod).toList();
    final issues = <String>{};
    final selectedRecordIds = selectedRows.map((r) => r.recordId).toSet();
    void includeQuality(JwHistoryRecord row) {
      selectedRecordIds.add(row.recordId);
      issues.addAll(_recordIssues(row));
    }

    for (final row in selectedRows) {
      includeQuality(row);
    }
    final segments = <JwHealthSleepSegment>[];
    final sleep = rows
        .where((r) => r.type == JwHistoryType.sleep && _time(r) != null)
        .toList();
    // Two events at the same instant cannot both own the following interval.
    final sleepAtTime = <DateTime, JwHistoryRecord>{};
    for (final row in sleep) {
      final time = _time(row)!;
      final previous = sleepAtTime[time];
      if (previous == null || _revisionOrder(row, previous) > 0) {
        sleepAtTime[time] = row;
      }
    }
    final transitions = sleepAtTime.values.toList()..sort(_timeOrder);
    for (var i = 0; i < transitions.length; i++) {
      final row = transitions[i], from = _time(row)!;
      if (i + 1 == transitions.length) {
        if (!from.isBefore(start.subtract(const Duration(days: 1))) &&
            from.isBefore(end)) {
          issues.add('openSleepTransition');
          includeQuality(row);
        }
        continue;
      }
      final next = transitions[i + 1], to = _time(next)!;
      if (!to.isAfter(start) || !from.isBefore(end)) continue;
      // Missing calendar dates provide no trustworthy intervening transitions.
      if (_calendar(next.day)!.difference(_calendar(row.day)!).inDays > 1) {
        issues.add('sleepDateGap');
        includeQuality(row);
        includeQuality(next);
        continue;
      }
      final mode = row.values['mode'];
      if (mode is! int || mode < 0 || mode > 4 || !to.isAfter(from)) continue;
      includeQuality(row);
      includeQuality(next);
      segments.add(JwHealthSleepSegment(
          start: from.isBefore(start) ? start : from,
          end: to.isAfter(end) ? end : to,
          stage: JwSleepStage.values[mode],
          recordId: row.recordId));
    }
    final days = <JwHealthDay>[];
    final activityBins = <JwHealthActivityBin>[];
    final dailySummaries = <JwHealthDailySummary>[];
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final key = jwHealthDayKey(d);
      final daily = selectedRows.where((r) => r.day == key).toList();
      final activity = daily.where((r) => r.type == JwHistoryType.steps);
      final summaries = daily
          .where((r) => r.type == JwHistoryType.metabolism)
          .toList()
        ..sort(_revisionOrder);
      final summary = summaries.isEmpty ? null : summaries.last;
      if (summary != null) {
        dailySummaries.add(_dailySummary(d, summary));
      }
      final timedActivity = activity.where((row) {
        final time = _time(row);
        return time != null &&
            !time.isBefore(d) &&
            time.isBefore(d.add(const Duration(days: 1)));
      }).toList();
      // A daily total never supplies invented timestamps or measured zeros.
      if (timedActivity.isNotEmpty) {
        for (var hour = 0; hour < 24; hour++) {
          final from = d.add(Duration(hours: hour));
          final to = from.add(const Duration(hours: 1));
          final hourly = timedActivity.where((row) {
            final time = _time(row)!;
            return !time.isBefore(from) && time.isBefore(to);
          }).toList();
          double? total(String field, {double factor = 1}) {
            final value = _sum(hourly
                .map((r) => _number(r.values[field], nonnegative: true))
                .whereType<double>());
            return value == null ? null : value * factor;
          }

          activityBins.add(JwHealthActivityBin(
              start: from,
              end: to,
              steps: total('steps')?.toInt(),
              distanceMeters: total('distanceMeters'),
              energyKcal: total('energyCalories', factor: 0.001)));
        }
      }
      double? rawTotal(String field, {double factor = 1}) {
        final total = _sum(activity
            .map((r) => _number(r.values[field], nonnegative: true))
            .whereType<double>());
        return total == null ? null : total * factor;
      }

      final rawSteps = rawTotal('steps');
      final rawSleep = <double>[];
      for (final segment in segments) {
        if (!segment.isSleep) continue;
        final a = segment.start.isAfter(d) ? segment.start : d;
        final endDay = d.add(const Duration(days: 1));
        final b = segment.end.isBefore(endDay) ? segment.end : endDay;
        if (b.isAfter(a)) rawSleep.add(b.difference(a).inSeconds / 60);
      }
      // Explicit valid zero summaries replace, rather than add to, raw totals.
      final summarySteps = _integer(summary?.values['steps']);
      final summaryEnergy =
          _number(summary?.values['energyKilocalories'], nonnegative: true);
      final summarySleep = summary?.validity['sleepAvailable'] == true
          ? _number(summary?.values['sleepMinutes'], nonnegative: true)
          : null;
      days.add(JwHealthDay(
          date: d,
          totals: JwHealthTotals(
              steps: summarySteps ?? rawSteps?.toInt(),
              distanceMeters: rawTotal('distanceMeters'),
              energyKcal:
                  summaryEnergy ?? rawTotal('energyCalories', factor: 0.001),
              sleepMinutes: summarySleep ?? _sum(rawSleep))));
    }
    final metrics = <JwHealthMetric, JwHealthMetricSeries>{};
    for (final metric in JwHealthMetric.values) {
      final samples = <JwHealthSample>[];
      for (final row in selectedRows) {
        final time = _time(row);
        if (time == null) continue;
        double? value, secondary;
        switch (metric) {
          case JwHealthMetric.heartRate:
            if (row.type == JwHistoryType.heartTemperature ||
                row.type == JwHistoryType.bloodPressure) {
              if (row.validity['heartRateRecorded'] != false) {
                value = _number(row.values['heartRateBpm'], positive: true);
              }
            }
          case JwHealthMetric.skinTemperature:
            if (row.type == JwHistoryType.heartTemperature &&
                row.validity['temperatureRecorded'] != false &&
                row.validity['temperatureDisplayUnavailable'] != true) {
              value = _number(row.values['skinTemperatureCelsius']);
            }
          case JwHealthMetric.bloodOxygen:
            if (row.type == JwHistoryType.bloodOxygen) {
              value = _number(row.values['percent'], positive: true);
              if (value != null && value > 100) value = null;
            }
          case JwHealthMetric.hrv:
            if (row.type == JwHistoryType.hrv) {
              value = _number(row.values['sdnnMilliseconds'], positive: true);
            }
          case JwHealthMetric.pressure:
            if (row.type == JwHistoryType.pressure) {
              value = _number(row.values['value'], positive: true);
            }
          case JwHealthMetric.bloodPressure:
            if (row.type == JwHistoryType.bloodPressure) {
              value = _number(row.values['systolicMmHg'], positive: true);
              secondary = _number(row.values['diastolicMmHg'], positive: true);
              if (secondary == null) value = null;
            }
        }
        if (value != null) {
          samples.add(JwHealthSample(
              time: time,
              value: value,
              secondaryValue: secondary,
              recordId: row.recordId));
        }
      }
      metrics[metric] = JwHealthMetricSeries(
          metric: metric,
          supported: _supported(metric, capabilities),
          samples: samples);
    }
    final dates = unique.values
        .map((r) => _calendar(r.day))
        .whereType<DateTime>()
        .toSet()
        .toList()
      ..sort();
    return JwHealthSnapshot(
        deviceKey: deviceKey,
        date: selected,
        start: start,
        endExclusive: end,
        period: period,
        totals: JwHealthTotals(
            steps: _sum(days
                    .map((d) => d.totals.steps?.toDouble())
                    .whereType<double>())
                ?.toInt(),
            distanceMeters: _sum(
                days.map((d) => d.totals.distanceMeters).whereType<double>()),
            energyKcal:
                _sum(days.map((d) => d.totals.energyKcal).whereType<double>()),
            sleepMinutes: _sum(
                days.map((d) => d.totals.sleepMinutes).whereType<double>())),
        days: days,
        activityBins: activityBins,
        dailySummaries: dailySummaries,
        metrics: metrics,
        sleepSegments: segments,
        sportRecords:
            selectedRows.where((r) => r.type == JwHistoryType.exercise),
        coverage: JwHealthCoverage(
            recordCount: selectedRecordIds.length,
            selectedRecordIds: selectedRecordIds,
            daysWithRecords: selectedRows.map((r) => r.day),
            issues: issues),
        availableDates: dates);
  }

  static Set<String> _recordIssues(JwHistoryRecord row) => {
        for (final flag in [
          'hrvPartial',
          'clockJump',
          'heartRateCoarse',
          'lateClose',
          'temperatureDisplayUnavailable'
        ])
          if (row.validity[flag] == true) flag
      };

  static JwHealthDailySummary _dailySummary(
      DateTime date, JwHistoryRecord row) {
    final values = <String, num>{};
    void add(String field, {bool positive = false, bool signed = false}) {
      final value = row.values[field];
      if (_number(value, positive: positive, nonnegative: !signed) != null) {
        values[field] = value as num;
      }
    }

    for (final field in ['dayHeartRateAverageBpm', 'stressAverage']) {
      add(field, positive: true);
    }
    if (row.validity['restFound'] == true) {
      add('restHeartRateBpm', positive: true);
      add('nightHeartRateP10', positive: true);
    }
    if (row.validity['hrvValid'] == true) {
      for (final field in [
        'sdnnMedianMs',
        'sdnnP25Ms',
        'sdnnP75Ms',
        'sdnnCount'
      ]) {
        add(field);
      }
    }
    if (row.validity['spo2Valid'] == true) {
      for (final field in ['spo2MeanPercent', 'spo2MinPercent']) {
        final value = _number(row.values[field], positive: true);
        if (value != null && value <= 100) add(field, positive: true);
      }
      add('spo2Lt90Count');
    }
    if (row.validity['temperatureValid'] == true &&
        row.validity['temperatureDisplayUnavailable'] != true) {
      add('skinTemperatureMeanCelsius', signed: true);
      add('skinTemperatureRangeCelsius');
    }
    if (row.validity['sleepAvailable'] == true) {
      add('sleepMinutes');
      add('deepSleepMinutes');
      final onset = _integer(row.values['sleepOnsetMinute']);
      if (onset != null && onset < 1440) values['sleepOnsetMinute'] = onset;
    }
    final steps = _integer(row.values['steps']);
    if (steps != null) values['steps'] = steps;
    add('energyKilocalories');
    return JwHealthDailySummary(
        date: date,
        recordId: row.recordId,
        values: values,
        issues: _recordIssues(row));
  }

  static int _revisionOrder(JwHistoryRecord a, JwHistoryRecord b) {
    final batch = a.firstSeenBatch.compareTo(b.firstSeenBatch);
    if (batch != 0) return batch;
    final ordinal = a.firstSeenOrdinal.compareTo(b.firstSeenOrdinal);
    return ordinal != 0 ? ordinal : a.recordId.compareTo(b.recordId);
  }

  static int _timeOrder(JwHistoryRecord a, JwHistoryRecord b) {
    final time = (_time(a) ?? DateTime.utc(2000))
        .compareTo(_time(b) ?? DateTime.utc(2000));
    return time != 0 ? time : _revisionOrder(a, b);
  }

  static DateTime? _calendar(String day) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return null;
    final date = DateTime.tryParse('${day}T00:00:00Z');
    return date != null && jwHealthDayKey(date) == day ? date : null;
  }

  static DateTime? _time(JwHistoryRecord row) {
    final local = row.sourceTime['localEpochSeconds'] ??
        row.sourceTime['dayEpochSeconds'];
    if (local is int && local >= 0) {
      return DateTime.utc(2000).add(Duration(seconds: local));
    }
    final day = _calendar(row.day),
        minute = row.sourceTime['minute'],
        second = row.sourceTime['second'] ?? 0;
    if (day == null ||
        minute is! int ||
        minute < 0 ||
        minute >= 1440 ||
        second is! int ||
        second < 0 ||
        second > 59) {
      return null;
    }
    return day.add(Duration(minutes: minute, seconds: second));
  }

  static double? _number(Object? value,
      {bool nonnegative = false, bool positive = false}) {
    if (value is! num ||
        !value.isFinite ||
        nonnegative && value < 0 ||
        positive && value <= 0) {
      return null;
    }
    return value.toDouble();
  }

  static int? _integer(Object? value) {
    final number = _number(value, nonnegative: true);
    return number != null && number == number.roundToDouble()
        ? number.toInt()
        : null;
  }

  static double? _sum(Iterable<double> values) {
    double? total;
    for (final value in values) {
      total = (total ?? 0) + value;
    }
    return total;
  }

  static bool? _supported(JwHealthMetric metric, JwCapabilities? c) {
    if (c == null) return null;
    return switch (metric) {
      JwHealthMetric.heartRate => c.heartRate,
      JwHealthMetric.bloodOxygen => c.bloodOxygen,
      JwHealthMetric.skinTemperature => c.temperature,
      JwHealthMetric.hrv => c.hrv,
      JwHealthMetric.pressure => c.pressureMonitor,
      JwHealthMetric.bloodPressure => c.bloodPressure
    };
  }
}
