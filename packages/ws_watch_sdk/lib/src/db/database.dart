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

@DriftDatabase(tables: [Devices])
class WSDatabase extends _$WSDatabase {
  WSDatabase(super.executor);
  @override
  int get schemaVersion => 1;
}
