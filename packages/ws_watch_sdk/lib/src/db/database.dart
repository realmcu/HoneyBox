import 'package:drift/drift.dart';
part 'database.g.dart';

class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get btMac => text().nullable()();
  TextColumn get firmwareVersion => text().nullable()();
  BlobColumn get deviceInfoRaw => blob().nullable()();
  BlobColumn get capabilitiesRaw => blob().nullable()();
  IntColumn get chipType => integer().nullable()();
  IntColumn get lastConnectedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {deviceId};
}

@TableIndex(name: 'step_device_time', columns: {#deviceId, #recordTime})
class StepRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  IntColumn get recordTime => integer()();
  IntColumn get mode => integer()();
  IntColumn get steps => integer().nullable()();
  IntColumn get bucketMinutes => integer()();
  IntColumn get averageHeartRate => integer().nullable()();
  IntColumn get flags => integer()();
  IntColumn get caloriesDeciKcal => integer().nullable()();
  IntColumn get distanceMeters => integer().nullable()();
  IntColumn get tzOffsetMinutes => integer()();
  IntColumn get syncedAt => integer()();
  BlobColumn get raw => blob()();
  @override
  List<Set<Column>> get uniqueKeys => [
        {deviceId, userId, recordTime}
      ];
}

@TableIndex(name: 'heart_device_time', columns: {#deviceId, #recordTime})
class HeartRateRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  IntColumn get recordTime => integer()();
  IntColumn get bpm => integer().nullable()();
  IntColumn get sourceKey => integer()();
  IntColumn get tzOffsetMinutes => integer()();
  IntColumn get syncedAt => integer()();
  BlobColumn get raw => blob()();
  @override
  List<Set<Column>> get uniqueKeys => [
        {deviceId, userId, recordTime}
      ];
}

@TableIndex(name: 'sync_device_started', columns: {#deviceId, #startedAt})
class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  TextColumn get syncId => text().unique()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer()();
  TextColumn get announcedJson => text()();
  TextColumn get receivedJson => text()();
  IntColumn get deviceResultCode => integer().nullable()();
  TextColumn get confirmation => text()();
  TextColumn get result => text()();
  TextColumn get reason => text().nullable()();
}

@DriftDatabase(tables: [Devices, StepRecords, HeartRateRecords, SyncLogs])
class WSDatabase extends _$WSDatabase {
  WSDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(stepRecords);
          await m.createTable(heartRateRecords);
          await m.createTable(syncLogs);
          for (final entity in allSchemaEntities.whereType<Index>()) {
            await m.createIndex(entity);
          }
        }
      });
}
