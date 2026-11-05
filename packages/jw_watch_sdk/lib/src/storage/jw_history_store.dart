import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../history/jw_history_models.dart';
import 'jw_database.dart';

/// Type-safe local history store owned by the JW SDK.
///
/// The store never opens a WS database and does not expose drift tables to SDK
/// callers. Every operation is explicitly scoped by the authenticated user and
/// the watch MAC address.
final class JWHistoryStore {
  JWHistoryStore._(this._database, this._release);

  final JWDatabase _database;
  final Future<void> Function() _release;
  Future<void>? _closing;

  static final Map<String, _SharedDatabase> _shared = {};

  /// Opens the default `jw_watch.db`, or an explicitly supplied JW database.
  static Future<JWHistoryStore> open({String? databasePath}) async {
    final directory = databasePath == null
        ? await getApplicationSupportDirectory()
        : File(databasePath).absolute.parent;
    final file = databasePath == null
        ? File('${directory.path}${Platform.pathSeparator}jw_watch.db')
        : File(databasePath).absolute;
    if (file.uri.pathSegments.last.toLowerCase() == 'ws_watch.db') {
      throw ArgumentError.value(
          databasePath, 'databasePath', 'JW storage must not open ws_watch.db');
    }
    await file.parent.create(recursive: true);
    final parent = await file.parent.resolveSymbolicLinks();
    final key = '$parent${Platform.pathSeparator}${file.uri.pathSegments.last}';
    var shared = _shared[key];
    if (shared == null) {
      shared = _SharedDatabase(JWDatabase(driftDatabase(
          name: 'jw_watch',
          native: DriftNativeOptions(databasePath: () async => key))));
      _shared[key] = shared;
    }
    shared.references++;
    final owned = shared;
    return JWHistoryStore._(owned.database, () async {
      owned.references--;
      if (owned.references == 0) {
        _shared.remove(key);
        await owned.database.close();
      }
    });
  }

  /// Creates a store around a caller-owned executor. Intended for tests and
  /// controlled embedding; [dispose] closes the supplied database.
  factory JWHistoryStore.forDatabase(JWDatabase database) =>
      JWHistoryStore._(database, database.close);

  Future<void> dispose() => _closing ??= _release();

  Future<void> writeActivities(
          JWHistoryScope scope, Iterable<JWActivity> records) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.jwActivities).insertOnConflictUpdate(
              JwActivitiesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  steps: row.steps,
                  distance: row.distance,
                  energy: row.energy,
                  activeTime: row.activeTime,
                  mode: row.mode));
        }
      });

  Future<void> writeSleeps(JWHistoryScope scope, Iterable<JWSleep> records) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.jwSleeps).insertOnConflictUpdate(
              JwSleepsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  mode: row.mode));
        }
      });

  Future<void> writeHeartRates(
          JWHistoryScope scope, Iterable<JWHeartRate> records) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.heartRate, 'heartRate');
          await _database.into(_database.jwHeartRates).insertOnConflictUpdate(
              JwHeartRatesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  heartRate: row.heartRate));
        }
      });

  Future<void> writeBloodPressures(
          JWHistoryScope scope, Iterable<JWBloodPressure> records) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.systolic, 'systolic');
          _positive(row.diastolic, 'diastolic');
          await _database
              .into(_database.jwBloodPressures)
              .insertOnConflictUpdate(JwBloodPressuresCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  systolic: row.systolic,
                  diastolic: row.diastolic));
        }
      });

  Future<void> writeBloodOxygens(
          JWHistoryScope scope, Iterable<JWBloodOxygen> records) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.value, 'blood oxygen');
          await _database.into(_database.jwBloodOxygens).insertOnConflictUpdate(
              JwBloodOxygensCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  value: row.value,
                  high: Value(row.high),
                  low: Value(row.low)));
        }
      });

  Future<void> writeHrvs(JWHistoryScope scope, Iterable<JWHrv> records) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.sdnn, 'sdnn');
          await _database.into(_database.jwHrvs).insertOnConflictUpdate(
              JwHrvsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  sdnn: row.sdnn));
        }
      });

  Future<void> writePressures(
          JWHistoryScope scope, Iterable<JWPressure> records) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.value, 'pressure');
          await _database.into(_database.jwPressures).insertOnConflictUpdate(
              JwPressuresCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  value: row.value));
        }
      });

  Future<void> writeTemperatures(
          JWHistoryScope scope, Iterable<JWTemperature> records) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.jwTemperatures).insertOnConflictUpdate(
              JwTemperaturesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  skinTemperature: row.skinTemperature,
                  heatStress: row.heatStress,
                  worn: row.worn,
                  compensated: row.compensated));
        }
      });

  Future<void> writeBloodGlucoses(
          JWHistoryScope scope, Iterable<JWBloodGlucose> records) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.value, 'blood glucose');
          await _database
              .into(_database.jwBloodGlucoses)
              .insertOnConflictUpdate(JwBloodGlucosesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  value: row.value));
        }
      });

  Future<void> writeSports(JWHistoryScope scope, Iterable<JWSport> records) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.jwSports).insertOnConflictUpdate(
              JwSportsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _time(row.time),
                  mode: row.mode,
                  duration: row.duration,
                  pauseCount: row.pauseCount,
                  pauseDuration: row.pauseDuration,
                  steps: row.steps,
                  distance: row.distance,
                  energy: row.energy,
                  heartRateMax: Value(row.heartRateMax),
                  heartRateAverage: Value(row.heartRateAverage),
                  heartRateMin: Value(row.heartRateMin)));
        }
      });

  Future<List<JWActivity>> queryActivities(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwActivities), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWActivity(
            time: _date(r.time),
            steps: r.steps,
            distance: r.distance,
            energy: r.energy,
            activeTime: r.activeTime,
            mode: r.mode))
        .toList(growable: false);
  }

  Future<List<JWSleep>> querySleeps(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwSleeps), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWSleep(time: _date(r.time), mode: r.mode))
        .toList(growable: false);
  }

  Future<List<JWHeartRate>> queryHeartRates(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwHeartRates), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWHeartRate(time: _date(r.time), heartRate: r.heartRate))
        .toList(growable: false);
  }

  Future<List<JWBloodPressure>> queryBloodPressures(
      JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwBloodPressures),
        query, (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWBloodPressure(
            time: _date(r.time), systolic: r.systolic, diastolic: r.diastolic))
        .toList(growable: false);
  }

  Future<List<JWBloodOxygen>> queryBloodOxygens(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwBloodOxygens),
        query, (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWBloodOxygen(
            time: _date(r.time), value: r.value, high: r.high, low: r.low))
        .toList(growable: false);
  }

  Future<List<JWHrv>> queryHrvs(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwHrvs), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWHrv(time: _date(r.time), sdnn: r.sdnn))
        .toList(growable: false);
  }

  Future<List<JWPressure>> queryPressures(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwPressures), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWPressure(time: _date(r.time), value: r.value))
        .toList(growable: false);
  }

  Future<List<JWTemperature>> queryTemperatures(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwTemperatures),
        query, (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWTemperature(
            time: _date(r.time),
            skinTemperature: r.skinTemperature,
            heatStress: r.heatStress,
            worn: r.worn,
            compensated: r.compensated))
        .toList(growable: false);
  }

  Future<List<JWBloodGlucose>> queryBloodGlucoses(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwBloodGlucoses),
        query, (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWBloodGlucose(time: _date(r.time), value: r.value))
        .toList(growable: false);
  }

  Future<List<JWSport>> querySports(JWHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.jwSports), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => JWSport(
            time: _date(r.time),
            mode: r.mode,
            duration: r.duration,
            pauseCount: r.pauseCount,
            pauseDuration: r.pauseDuration,
            steps: r.steps,
            distance: r.distance,
            energy: r.energy,
            heartRateMax: r.heartRateMax,
            heartRateAverage: r.heartRateAverage,
            heartRateMin: r.heartRateMin))
        .toList(growable: false);
  }

  Future<int> deleteHeartRates(JWHistoryQuery q) =>
      (_database.delete(_database.jwHeartRates)..where((t) => _where(t, q)))
          .go();
  Future<int> deleteActivities(JWHistoryQuery q) =>
      (_database.delete(_database.jwActivities)..where((t) => _where(t, q)))
          .go();
  Future<int> deleteSleeps(JWHistoryQuery q) =>
      (_database.delete(_database.jwSleeps)..where((t) => _where(t, q))).go();
  Future<int> deleteBloodPressures(JWHistoryQuery q) =>
      (_database.delete(_database.jwBloodPressures)..where((t) => _where(t, q)))
          .go();
  Future<int> deleteBloodOxygens(JWHistoryQuery q) =>
      (_database.delete(_database.jwBloodOxygens)..where((t) => _where(t, q)))
          .go();
  Future<int> deleteHrvs(JWHistoryQuery q) =>
      (_database.delete(_database.jwHrvs)..where((t) => _where(t, q))).go();
  Future<int> deletePressures(JWHistoryQuery q) =>
      (_database.delete(_database.jwPressures)..where((t) => _where(t, q)))
          .go();
  Future<int> deleteTemperatures(JWHistoryQuery q) =>
      (_database.delete(_database.jwTemperatures)..where((t) => _where(t, q)))
          .go();
  Future<int> deleteBloodGlucoses(JWHistoryQuery q) =>
      (_database.delete(_database.jwBloodGlucoses)..where((t) => _where(t, q)))
          .go();
  Future<int> deleteSports(JWHistoryQuery q) =>
      (_database.delete(_database.jwSports)..where((t) => _where(t, q))).go();

  Future<List<D>> _ordered<T extends JWHistoryTable, D extends DataClass>(
      SimpleSelectStatement<T, D> select,
      JWHistoryQuery query,
      Expression<bool> Function(T table) filter,
      GeneratedColumn<int> Function(T table) time) async {
    select
      ..where(filter)
      ..orderBy([
        (t) => OrderingTerm(
            expression: time(t),
            mode: query.descending ? OrderingMode.desc : OrderingMode.asc)
      ])
      ..limit(query.limit);
    return select.get();
  }

  Expression<bool> _where(JWHistoryTable table, JWHistoryQuery query) {
    var predicate = table.userId.equals(query.scope.userId) &
        table.deviceMac.equals(query.scope.deviceMac);
    if (query.from case final from?) {
      predicate &= table.time.isBiggerOrEqualValue(_time(from));
    }
    if (query.to case final to?) {
      predicate &= table.time.isSmallerOrEqualValue(_time(to));
    }
    return predicate;
  }

  static int _time(DateTime value) => value.toUtc().millisecondsSinceEpoch;
  static DateTime _date(int value) =>
      DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  static void _positive(int value, String name) {
    if (value <= 0) throw ArgumentError.value(value, name, 'must be positive');
  }
}

final class _SharedDatabase {
  _SharedDatabase(this.database);
  final JWDatabase database;
  int references = 0;
}
