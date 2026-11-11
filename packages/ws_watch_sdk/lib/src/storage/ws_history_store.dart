import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../history/ws_history_models.dart';
import 'ws_database.dart';

export '../history/ws_history_models.dart';

/// Type-safe local history store owned by the WS SDK.
final class WSHistoryStore {
  WSHistoryStore._(this._database, this._release);

  final WSDatabase _database;
  final Future<void> Function() _release;
  Future<void>? _closing;

  static final Map<String, _SharedDatabase> _shared = {};

  static Future<WSHistoryStore> open({String? databasePath}) async {
    if (databasePath == 'test') {
      final database = WSDatabase(NativeDatabase.memory());
      return WSHistoryStore._(database, database.close);
    }
    if (databasePath == ':memory:') {
      final database = WSDatabase(NativeDatabase.memory());
      return WSHistoryStore._(database, database.close);
    }

    final directory = databasePath == null
        ? await getApplicationSupportDirectory()
        : File(databasePath).absolute.parent;
    final file = databasePath == null
        ? File('${directory.path}${Platform.pathSeparator}ws_watch.db')
        : File(databasePath).absolute;
    if (file.uri.pathSegments.last.toLowerCase() == 'jw_watch.db') {
      throw ArgumentError.value(
        databasePath,
        'databasePath',
        'WS storage must not open jw_watch.db',
      );
    }
    await file.parent.create(recursive: true);
    final parent = await file.parent.resolveSymbolicLinks();
    final key =
        '$parent${Platform.pathSeparator}${file.uri.pathSegments.last}';
    var shared = _shared[key];
    if (shared == null) {
      shared = _SharedDatabase(WSDatabase(driftDatabase(
        name: 'ws_watch',
        native: DriftNativeOptions(databasePath: () async => key),
      )));
      _shared[key] = shared;
    }
    shared.references++;
    final owned = shared;
    return WSHistoryStore._(owned.database, () async {
      owned.references--;
      if (owned.references == 0) {
        _shared.remove(key);
        await owned.database.close();
      }
    });
  }

  factory WSHistoryStore.forDatabase(WSDatabase database) =>
      WSHistoryStore._(database, database.close);

  Future<void> dispose() => _closing ??= _release();

  Future<void> replaceHeartRates(
    WSHistoryScope scope,
    List<WSHeartRate> rows,
  ) async {
    await _database.transaction(() async {
      await (_database.delete(_database.wsHeartRates)
            ..where((t) => _whereScope(t, scope)))
          .go();
      for (final row in rows) {
        _positive(row.bpm, 'bpm');
        await _database.into(_database.wsHeartRates).insertOnConflictUpdate(
              WsHeartRatesCompanion.insert(
                userId: scope.userId,
                deviceMac: scope.deviceMac,
                time: _heartRateWallTime(row.time),
                bpm: row.bpm,
              ),
            );
      }
    });
  }

  Future<void> writeActivities(
    WSHistoryScope scope,
    Iterable<WSActivity> records,
  ) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.wsActivities).insertOnConflictUpdate(
                WsActivitiesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  steps: row.steps,
                  distance: row.distance,
                  energy: row.energy,
                  activeTime: row.activeTime,
                  mode: row.mode,
                ),
              );
        }
      });

  Future<void> writeSleeps(WSHistoryScope scope, Iterable<WSSleep> records) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.wsSleeps).insertOnConflictUpdate(
                WsSleepsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  mode: row.mode,
                ),
              );
        }
      });

  Future<void> writeHeartRates(
    WSHistoryScope scope,
    Iterable<WSHeartRate> records,
  ) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.bpm, 'bpm');
          await _database.into(_database.wsHeartRates).insertOnConflictUpdate(
                WsHeartRatesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _heartRateWallTime(row.time),
                  bpm: row.bpm,
                ),
              );
        }
      });

  Future<void> writeBloodPressures(
    WSHistoryScope scope,
    Iterable<WSBloodPressure> records,
  ) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.systolic, 'systolic');
          _positive(row.diastolic, 'diastolic');
          await _database
              .into(_database.wsBloodPressures)
              .insertOnConflictUpdate(
                WsBloodPressuresCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  systolic: row.systolic,
                  diastolic: row.diastolic,
                ),
              );
        }
      });

  Future<void> writeBloodOxygens(
    WSHistoryScope scope,
    Iterable<WSBloodOxygen> records,
  ) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.value, 'blood oxygen');
          await _database.into(_database.wsBloodOxygens).insertOnConflictUpdate(
                WsBloodOxygensCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  value: row.value,
                  high: Value(row.high),
                  low: Value(row.low),
                ),
              );
        }
      });

  Future<void> writeHrvs(WSHistoryScope scope, Iterable<WSHrv> records) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.sdnn, 'sdnn');
          await _database.into(_database.wsHrvs).insertOnConflictUpdate(
                WsHrvsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  sdnn: row.sdnn,
                ),
              );
        }
      });

  Future<void> writePressures(
    WSHistoryScope scope,
    Iterable<WSPressure> records,
  ) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.value, 'pressure');
          await _database.into(_database.wsPressures).insertOnConflictUpdate(
                WsPressuresCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  value: row.value,
                ),
              );
        }
      });

  Future<void> writeTemperatures(
    WSHistoryScope scope,
    Iterable<WSTemperature> records,
  ) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.wsTemperatures).insertOnConflictUpdate(
                WsTemperaturesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  skinTemperature: row.skinTemperature,
                  heatStress: row.heatStress,
                  worn: row.worn,
                  compensated: row.compensated,
                ),
              );
        }
      });

  Future<void> writeBloodGlucoses(
    WSHistoryScope scope,
    Iterable<WSBloodGlucose> records,
  ) =>
      _database.transaction(() async {
        for (final row in records) {
          _positive(row.value, 'blood glucose');
          await _database
              .into(_database.wsBloodGlucoses)
              .insertOnConflictUpdate(
                WsBloodGlucosesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  value: row.value,
                ),
              );
        }
      });

  Future<void> writeSports(WSHistoryScope scope, Iterable<WSSport> records) =>
      _database.transaction(() async {
        for (final row in records) {
          await _database.into(_database.wsSports).insertOnConflictUpdate(
                WsSportsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  mode: row.mode,
                  duration: row.duration,
                  pauseCount: row.pauseCount,
                  pauseDuration: row.pauseDuration,
                  steps: row.steps,
                  distance: row.distance,
                  energy: row.energy,
                  heartRateMax: Value(row.heartRateMax),
                  heartRateAverage: Value(row.heartRateAverage),
                  heartRateMin: Value(row.heartRateMin),
                ),
              );
        }
      });

  Future<void> writeRecords(
    WSHistoryScope scope,
    Iterable<WSHistoryRecord> records,
  ) async {
    final activities = <WSActivity>[];
    final sleeps = <WSSleep>[];
    final pressures = <WSBloodPressure>[];
    final oxygens = <WSBloodOxygen>[];
    final hrvs = <WSHrv>[];
    final stress = <WSPressure>[];
    final temperatures = <WSTemperature>[];
    final glucoses = <WSBloodGlucose>[];
    final sports = <WSSport>[];
    for (final record in records) {
      switch (record) {
        case WSActivity():
          activities.add(record);
        case WSSleep():
          sleeps.add(record);
        case WSBloodPressure():
          pressures.add(record);
        case WSBloodOxygen():
          oxygens.add(record);
        case WSHrv():
          hrvs.add(record);
        case WSPressure():
          stress.add(record);
        case WSTemperature():
          temperatures.add(record);
        case WSSport():
          sports.add(record);
        case WSBloodGlucose():
          glucoses.add(record);
      }
    }
    for (final row in pressures) {
      _positive(row.systolic, 'systolic');
      _positive(row.diastolic, 'diastolic');
    }
    for (final row in oxygens) {
      _positive(row.value, 'blood oxygen');
    }
    for (final row in hrvs) {
      _positive(row.sdnn, 'sdnn');
    }
    for (final row in stress) {
      _positive(row.value, 'pressure');
    }
    for (final row in glucoses) {
      _positive(row.value, 'blood glucose');
    }
    await _database.transaction(() async {
      await _database.batch((batch) {
        if (activities.isNotEmpty) {
          batch.insertAll(
            _database.wsActivities,
            [
              for (final row in activities)
                WsActivitiesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  steps: row.steps,
                  distance: row.distance,
                  energy: row.energy,
                  activeTime: row.activeTime,
                  mode: row.mode,
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (sleeps.isNotEmpty) {
          batch.insertAll(
            _database.wsSleeps,
            [
              for (final row in sleeps)
                WsSleepsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  mode: row.mode,
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (pressures.isNotEmpty) {
          batch.insertAll(
            _database.wsBloodPressures,
            [
              for (final row in pressures)
                WsBloodPressuresCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  systolic: row.systolic,
                  diastolic: row.diastolic,
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (oxygens.isNotEmpty) {
          batch.insertAll(
            _database.wsBloodOxygens,
            [
              for (final row in oxygens)
                WsBloodOxygensCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  value: row.value,
                  high: Value(row.high),
                  low: Value(row.low),
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (hrvs.isNotEmpty) {
          batch.insertAll(
            _database.wsHrvs,
            [
              for (final row in hrvs)
                WsHrvsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  sdnn: row.sdnn,
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (stress.isNotEmpty) {
          batch.insertAll(
            _database.wsPressures,
            [
              for (final row in stress)
                WsPressuresCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  value: row.value,
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (temperatures.isNotEmpty) {
          batch.insertAll(
            _database.wsTemperatures,
            [
              for (final row in temperatures)
                WsTemperaturesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  skinTemperature: row.skinTemperature,
                  heatStress: row.heatStress,
                  worn: row.worn,
                  compensated: row.compensated,
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (glucoses.isNotEmpty) {
          batch.insertAll(
            _database.wsBloodGlucoses,
            [
              for (final row in glucoses)
                WsBloodGlucosesCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  value: row.value,
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
        if (sports.isNotEmpty) {
          batch.insertAll(
            _database.wsSports,
            [
              for (final row in sports)
                WsSportsCompanion.insert(
                  userId: scope.userId,
                  deviceMac: scope.deviceMac,
                  time: _wallTime(row.time),
                  mode: row.mode,
                  duration: row.duration,
                  pauseCount: row.pauseCount,
                  pauseDuration: row.pauseDuration,
                  steps: row.steps,
                  distance: row.distance,
                  energy: row.energy,
                  heartRateMax: Value(row.heartRateMax),
                  heartRateAverage: Value(row.heartRateAverage),
                  heartRateMin: Value(row.heartRateMin),
                ),
            ],
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  Future<List<WSActivity>> queryActivities(WSHistoryQuery query) async {
    final rows = await _ordered(
      _database.select(_database.wsActivities),
      query,
      (t) => _where(t, query),
      (t) => t.time,
    );
    return rows
        .map(
          (r) => WSActivity(
            time: _date(r.time),
            steps: r.steps,
            distance: r.distance,
            energy: r.energy,
            activeTime: r.activeTime,
            mode: r.mode,
          ),
        )
        .toList(growable: false);
  }

  Future<List<WSSleep>> querySleeps(WSHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.wsSleeps), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => WSSleep(time: _date(r.time), mode: r.mode))
        .toList(growable: false);
  }

  Future<List<WSHeartRate>> queryHeartRates(WSHistoryQuery query) async {
    final rows = await _ordered(
      _database.select(_database.wsHeartRates),
      query,
      (t) => _where(t, query),
      (t) => t.time,
    );
    return rows
        .map((r) => WSHeartRate(time: _heartRateWireTime(r.time), bpm: r.bpm))
        .toList(growable: false);
  }

  Future<List<WSBloodPressure>> queryBloodPressures(
    WSHistoryQuery query,
  ) async {
    final rows = await _ordered(
      _database.select(_database.wsBloodPressures),
      query,
      (t) => _where(t, query),
      (t) => t.time,
    );
    return rows
        .map(
          (r) => WSBloodPressure(
            time: _date(r.time),
            systolic: r.systolic,
            diastolic: r.diastolic,
          ),
        )
        .toList(growable: false);
  }

  Future<List<WSBloodOxygen>> queryBloodOxygens(WSHistoryQuery query) async {
    final rows = await _ordered(
      _database.select(_database.wsBloodOxygens),
      query,
      (t) => _where(t, query),
      (t) => t.time,
    );
    return rows
        .map(
          (r) => WSBloodOxygen(
            time: _date(r.time),
            value: r.value,
            high: r.high,
            low: r.low,
          ),
        )
        .toList(growable: false);
  }

  Future<List<WSHrv>> queryHrvs(WSHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.wsHrvs), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => WSHrv(time: _date(r.time), sdnn: r.sdnn))
        .toList(growable: false);
  }

  Future<List<WSPressure>> queryPressures(WSHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.wsPressures), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map((r) => WSPressure(time: _date(r.time), value: r.value))
        .toList(growable: false);
  }

  Future<List<WSTemperature>> queryTemperatures(WSHistoryQuery query) async {
    final rows = await _ordered(
      _database.select(_database.wsTemperatures),
      query,
      (t) => _where(t, query),
      (t) => t.time,
    );
    return rows
        .map(
          (r) => WSTemperature(
            time: _date(r.time),
            skinTemperature: r.skinTemperature,
            heatStress: r.heatStress,
            worn: r.worn,
            compensated: r.compensated,
          ),
        )
        .toList(growable: false);
  }

  Future<List<WSBloodGlucose>> queryBloodGlucoses(WSHistoryQuery query) async {
    final rows = await _ordered(
      _database.select(_database.wsBloodGlucoses),
      query,
      (t) => _where(t, query),
      (t) => t.time,
    );
    return rows
        .map((r) => WSBloodGlucose(time: _date(r.time), value: r.value))
        .toList(growable: false);
  }

  Future<List<WSSport>> querySports(WSHistoryQuery query) async {
    final rows = await _ordered(_database.select(_database.wsSports), query,
        (t) => _where(t, query), (t) => t.time);
    return rows
        .map(
          (r) => WSSport(
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
            heartRateMin: r.heartRateMin,
          ),
        )
        .toList(growable: false);
  }

  Future<int> deleteHeartRates(WSHistoryQuery q) =>
      (_database.delete(_database.wsHeartRates)..where((t) => _where(t, q)))
          .go();

  Future<int> deleteActivities(WSHistoryQuery q) =>
      (_database.delete(_database.wsActivities)..where((t) => _where(t, q)))
          .go();

  Future<int> deleteSleeps(WSHistoryQuery q) =>
      (_database.delete(_database.wsSleeps)..where((t) => _where(t, q))).go();

  Future<int> deleteBloodPressures(WSHistoryQuery q) =>
      (_database.delete(_database.wsBloodPressures)..where((t) => _where(t, q)))
          .go();

  Future<int> deleteBloodOxygens(WSHistoryQuery q) =>
      (_database.delete(_database.wsBloodOxygens)..where((t) => _where(t, q)))
          .go();

  Future<int> deleteHrvs(WSHistoryQuery q) =>
      (_database.delete(_database.wsHrvs)..where((t) => _where(t, q))).go();

  Future<int> deletePressures(WSHistoryQuery q) =>
      (_database.delete(_database.wsPressures)..where((t) => _where(t, q)))
          .go();

  Future<int> deleteTemperatures(WSHistoryQuery q) =>
      (_database.delete(_database.wsTemperatures)..where((t) => _where(t, q)))
          .go();

  Future<int> deleteBloodGlucoses(WSHistoryQuery q) =>
      (_database.delete(_database.wsBloodGlucoses)..where((t) => _where(t, q)))
          .go();

  Future<int> deleteSports(WSHistoryQuery q) =>
      (_database.delete(_database.wsSports)..where((t) => _where(t, q))).go();

  Future<List<D>> _ordered<T extends WSHistoryTable, D extends DataClass>(
    SimpleSelectStatement<T, D> select,
    WSHistoryQuery query,
    Expression<bool> Function(T table) filter,
    GeneratedColumn<int> Function(T table) time,
  ) async {
    select
      ..where(filter)
      ..orderBy([
        (t) => OrderingTerm(
              expression: time(t),
              mode: query.descending ? OrderingMode.desc : OrderingMode.asc,
            ),
      ])
      ..limit(query.limit);
    return select.get();
  }

  Expression<bool> _where(WSHistoryTable table, WSHistoryQuery query) {
    var predicate = _whereScope(table, query.scope);
    if (query.from case final from?) {
      predicate &= table.time.isBiggerOrEqualValue(from);
    }
    if (query.to case final to?) {
      predicate &= table.time.isSmallerOrEqualValue(to);
    }
    return predicate;
  }

  Expression<bool> _whereScope(
    WSHistoryTable table,
    WSHistoryScope scope,
  ) =>
      table.userId.equals(scope.userId) &
      table.deviceMac.equals(scope.deviceMac);

  static int _wallTime(DateTime value) => value.millisecondsSinceEpoch;
  static DateTime _date(int value) => DateTime.fromMillisecondsSinceEpoch(value);

  /// Wire / codec use epoch **seconds**; all history tables store **milliseconds**.
  static int _heartRateWallTime(int wireSeconds) => wireSeconds * 1000;

  static int _heartRateWireTime(int stored) {
    if (stored >= 1000000000000) return stored ~/ 1000;
    if (stored >= 1000000000) return stored;
    return stored ~/ 1000;
  }
  static void _positive(int value, String name) {
    if (value <= 0) throw ArgumentError.value(value, name, 'must be positive');
  }
}

final class _SharedDatabase {
  _SharedDatabase(this.database);

  final WSDatabase database;
  int references = 0;
}
