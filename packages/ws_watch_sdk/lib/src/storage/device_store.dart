import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../connection/user_id.dart';
import 'history_store.dart';
import '../db/database.dart';
import '../model/device_info.dart';
import '../capability/capabilities.dart';

abstract interface class WSDeviceStore {
  Future<String> defaultUserId(String deviceId);
  Future<void> rememberUserId(String deviceId, String userId);
  Future<void> saveReady(String deviceId, String userId, WSDeviceInfo info,
      WSCapabilities capabilities);
  Future<void> close();
}

/// Connections are shared by normalized absolute path, with explicit ownership.
class WSDriftDeviceStore with WSDriftHistoryStore implements WSDeviceStore {
  WSDriftDeviceStore(this.database, {Future<void> Function()? release})
      : _release = release;
  @override
  final WSDatabase database;
  final Future<void> Function()? _release;
  Future<void>? _closing;
  static final Map<String, _SharedDatabase> _shared = {};

  static Future<WSDriftDeviceStore> open(String? databasePath) async {
    final path = databasePath ??
        '${(await getApplicationSupportDirectory()).path}/ws_watch.db';
    final file = File(path).absolute;
    await file.parent.create(recursive: true);
    // Resolve symlinks in the parent; the database file may not exist yet.
    final key =
        '${await file.parent.resolveSymbolicLinks()}/${file.uri.pathSegments.last}';
    var entry = _shared[key];
    if (entry == null) {
      final db = WSDatabase(driftDatabase(
          name: 'ws_watch',
          native: DriftNativeOptions(databasePath: () async => key)));
      entry = _SharedDatabase(db);
      _shared[key] = entry;
    }
    entry.references++;
    final owned = entry;
    return WSDriftDeviceStore(owned.database, release: () async {
      owned.references--;
      if (owned.references == 0) {
        _shared.remove(key);
        await owned.database.close();
      }
    });
  }

  @override
  Future<String> defaultUserId(String deviceId) =>
      database.transaction(() async {
        final row = await (database.select(database.devices)
              ..where((t) => t.deviceId.equals(deviceId)))
            .getSingleOrNull();
        if (row != null) return row.userId;
        final id = WSUserId.random().value;
        await database
            .into(database.devices)
            .insert(DevicesCompanion.insert(deviceId: deviceId, userId: id));
        return id;
      });
  @override
  Future<void> rememberUserId(String deviceId, String userId) async {
    await database.into(database.devices).insertOnConflictUpdate(
        DevicesCompanion.insert(deviceId: deviceId, userId: userId));
  }

  @override
  Future<void> saveReady(String deviceId, String userId, WSDeviceInfo info,
      WSCapabilities capabilities) async {
    await database.into(database.devices).insertOnConflictUpdate(
        DevicesCompanion.insert(
            deviceId: deviceId,
            userId: userId,
            name: const Value(''),
            btMac: Value(info.btMac),
            firmwareVersion: Value(info.firmwareVersion),
            deviceInfoRaw: Value(info.raw),
            capabilitiesRaw: Value(capabilities.raw),
            chipType: Value(info.chipType),
            lastConnectedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  @override
  Future<void> close() => _closing ??= (_release?.call() ?? database.close());
}

class _SharedDatabase {
  _SharedDatabase(this.database);
  final WSDatabase database;
  int references = 0;
}
