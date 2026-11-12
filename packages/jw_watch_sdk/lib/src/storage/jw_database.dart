import 'package:drift/drift.dart';

part 'jw_database.g.dart';

abstract class JWHistoryTable extends Table {
  TextColumn get userId => text()();
  TextColumn get deviceMac => text()();
  IntColumn get time => integer()();

  @override
  Set<Column> get primaryKey => {userId, deviceMac, time};
}

@DataClassName('JWActivityRow')
class JWActivities extends JWHistoryTable {
  @override
  String get tableName => 'jw_activity';
  IntColumn get steps => integer()();
  IntColumn get distance => integer()();
  IntColumn get energy => integer()();
  IntColumn get activeTime => integer()();
  IntColumn get mode => integer()();
}

@DataClassName('JWSleepRow')
class JWSleeps extends JWHistoryTable {
  @override
  String get tableName => 'jw_sleep';
  IntColumn get mode => integer()();
}

@DataClassName('JWHeartRateRow')
class JWHeartRates extends JWHistoryTable {
  @override
  String get tableName => 'jw_heart_rate';
  IntColumn get heartRate => integer()();
}

@DataClassName('JWBloodPressureRow')
class JWBloodPressures extends JWHistoryTable {
  @override
  String get tableName => 'jw_blood_pressure';
  IntColumn get systolic => integer()();
  IntColumn get diastolic => integer()();
}

@DataClassName('JWBloodOxygenRow')
class JWBloodOxygens extends JWHistoryTable {
  @override
  String get tableName => 'jw_blood_oxygen';
  IntColumn get value => integer()();
  IntColumn get high => integer().nullable()();
  IntColumn get low => integer().nullable()();
}

@DataClassName('JWHrvRow')
class JWHrvs extends JWHistoryTable {
  @override
  String get tableName => 'jw_hrv';
  IntColumn get sdnn => integer()();
}

@DataClassName('JWPressureRow')
class JWPressures extends JWHistoryTable {
  @override
  String get tableName => 'jw_pressure';
  IntColumn get value => integer()();
}

@DataClassName('JWTemperatureRow')
class JWTemperatures extends JWHistoryTable {
  @override
  String get tableName => 'jw_temperature';
  RealColumn get skinTemperature => real()();
  IntColumn get heatStress => integer()();
  BoolColumn get worn => boolean()();
  BoolColumn get compensated => boolean()();
}

@DataClassName('JWBloodGlucoseRow')
class JWBloodGlucoses extends JWHistoryTable {
  @override
  String get tableName => 'jw_blood_glucose';
  IntColumn get value => integer()();
}

@DataClassName('JWSportRow')
class JWSports extends JWHistoryTable {
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
  JWActivities,
  JWSleeps,
  JWHeartRates,
  JWBloodPressures,
  JWBloodOxygens,
  JWHrvs,
  JWPressures,
  JWTemperatures,
  JWBloodGlucoses,
  JWSports,
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
        },
      );
}

/// Drift lower-cases only the first letter of `JW*` table classes (`jW*`).
/// These aliases keep call sites as `jw*` table getters (file-style prefix).
extension JWDatabaseHistoryTables on JWDatabase {
  $JWActivitiesTable get jwActivities => jWActivities;
  $JWSleepsTable get jwSleeps => jWSleeps;
  $JWHeartRatesTable get jwHeartRates => jWHeartRates;
  $JWBloodPressuresTable get jwBloodPressures => jWBloodPressures;
  $JWBloodOxygensTable get jwBloodOxygens => jWBloodOxygens;
  $JWHrvsTable get jwHrvs => jWHrvs;
  $JWPressuresTable get jwPressures => jWPressures;
  $JWTemperaturesTable get jwTemperatures => jWTemperatures;
  $JWBloodGlucosesTable get jwBloodGlucoses => jWBloodGlucoses;
  $JWSportsTable get jwSports => jWSports;
}
