import 'package:drift/drift.dart';

part 'jw_database.g.dart';

abstract class JWHistoryTable extends Table {
  TextColumn get userId => text()();
  TextColumn get deviceMac => text()();
  IntColumn get time => integer()();

  @override
  Set<Column> get primaryKey => {userId, deviceMac, time};
}

class JwActivities extends JWHistoryTable {
  @override
  String get tableName => 'jw_activity';
  IntColumn get steps => integer()();
  IntColumn get distance => integer()();
  IntColumn get energy => integer()();
  IntColumn get activeTime => integer()();
  IntColumn get mode => integer()();
}

class JwSleeps extends JWHistoryTable {
  @override
  String get tableName => 'jw_sleep';
  IntColumn get mode => integer()();
}

class JwHeartRates extends JWHistoryTable {
  @override
  String get tableName => 'jw_heart_rate';
  IntColumn get heartRate => integer()();
}

class JwBloodPressures extends JWHistoryTable {
  @override
  String get tableName => 'jw_blood_pressure';
  IntColumn get systolic => integer()();
  IntColumn get diastolic => integer()();
}

class JwBloodOxygens extends JWHistoryTable {
  @override
  String get tableName => 'jw_blood_oxygen';
  IntColumn get value => integer()();
  IntColumn get high => integer().nullable()();
  IntColumn get low => integer().nullable()();
}

class JwHrvs extends JWHistoryTable {
  @override
  String get tableName => 'jw_hrv';
  IntColumn get sdnn => integer()();
}

class JwPressures extends JWHistoryTable {
  @override
  String get tableName => 'jw_pressure';
  IntColumn get value => integer()();
}

class JwTemperatures extends JWHistoryTable {
  @override
  String get tableName => 'jw_temperature';
  RealColumn get skinTemperature => real()();
  IntColumn get heatStress => integer()();
  BoolColumn get worn => boolean()();
  BoolColumn get compensated => boolean()();
}

class JwBloodGlucoses extends JWHistoryTable {
  @override
  String get tableName => 'jw_blood_glucose';
  IntColumn get value => integer()();
}

class JwSports extends JWHistoryTable {
  @override
  String get tableName => 'jw_sport';
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
  JwActivities,
  JwSleeps,
  JwHeartRates,
  JwBloodPressures,
  JwBloodOxygens,
  JwHrvs,
  JwPressures,
  JwTemperatures,
  JwBloodGlucoses,
  JwSports,
])
class JWDatabase extends _$JWDatabase {
  JWDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  /// Schema ownership stays entirely within the JW SDK.  Keeping creation and
  /// upgrades here makes a future JW migration explicit, instead of letting a
  /// generated default accidentally touch a database with a different schema.
  @override
  MigrationStrategy get migration => MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) async {
        // Version 1 is the initial JW-only schema. Add ordered JW migrations
        // here whenever [schemaVersion] advances; WS has a separate database.
      });
}
