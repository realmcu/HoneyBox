import 'package:drift/drift.dart';

part 'ws_database.g.dart';

abstract class WSHistoryTable extends Table {
  TextColumn get userId => text()();
  TextColumn get deviceMac => text()();
  IntColumn get time => integer()();

  @override
  Set<Column> get primaryKey => {userId, deviceMac, time};
}

class WsActivities extends WSHistoryTable {
  @override
  String get tableName => 'ws_activity';
  IntColumn get steps => integer()();
  IntColumn get distance => integer()();
  IntColumn get energy => integer()();
  IntColumn get activeTime => integer()();
  IntColumn get mode => integer()();
}

class WsSleeps extends WSHistoryTable {
  @override
  String get tableName => 'ws_sleep';
  IntColumn get mode => integer()();
}

class WsHeartRates extends WSHistoryTable {
  @override
  String get tableName => 'ws_heart_rate';
  IntColumn get bpm => integer()();
}

class WsBloodPressures extends WSHistoryTable {
  @override
  String get tableName => 'ws_blood_pressure';
  IntColumn get systolic => integer()();
  IntColumn get diastolic => integer()();
}

class WsBloodOxygens extends WSHistoryTable {
  @override
  String get tableName => 'ws_blood_oxygen';
  IntColumn get value => integer()();
  IntColumn get high => integer().nullable()();
  IntColumn get low => integer().nullable()();
}

class WsHrvs extends WSHistoryTable {
  @override
  String get tableName => 'ws_hrv';
  IntColumn get sdnn => integer()();
}

class WsPressures extends WSHistoryTable {
  @override
  String get tableName => 'ws_pressure';
  IntColumn get value => integer()();
}

class WsTemperatures extends WSHistoryTable {
  @override
  String get tableName => 'ws_temperature';
  RealColumn get skinTemperature => real()();
  IntColumn get heatStress => integer()();
  BoolColumn get worn => boolean()();
  BoolColumn get compensated => boolean()();
}

class WsBloodGlucoses extends WSHistoryTable {
  @override
  String get tableName => 'ws_blood_glucose';
  IntColumn get value => integer()();
}

class WsSports extends WSHistoryTable {
  @override
  String get tableName => 'ws_sport';
  IntColumn get mode => integer()();
  IntColumn get duration => integer()();
  IntColumn get pauseCount => integer()();
  IntColumn get pauseDuration => integer()();
  IntColumn get steps => integer()();
  IntColumn get distance => integer()();
  IntColumn get energy => integer()();
  IntColumn get heartRateMax => integer().nullable()();
  IntColumn get heartRateAverage => integer().nullable()();
  IntColumn get heartRateMin => integer().nullable()();
}

@DriftDatabase(tables: [
  WsActivities,
  WsSleeps,
  WsHeartRates,
  WsBloodPressures,
  WsBloodOxygens,
  WsHrvs,
  WsPressures,
  WsTemperatures,
  WsBloodGlucoses,
  WsSports,
])
class WSDatabase extends _$WSDatabase {
  WSDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          // Version 1 is the initial WS-only schema.
        },
      );
}
