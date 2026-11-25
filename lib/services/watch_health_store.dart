import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../pages/watch/health/watch_health_data.dart';

/// Durable storage used by CMD 0x05 before the phone sends key 0x42.
abstract interface class WatchHealthStore {
  Future<WatchHealthSnapshot?> load(String deviceId);

  Future<void> save(String deviceId, WatchHealthSnapshot snapshot);
}

/// In-memory implementation for tests and isolated protocol probes.
class WatchHealthMemoryStore implements WatchHealthStore {
  final Map<String, WatchHealthSnapshot> _snapshots = {};

  @override
  Future<WatchHealthSnapshot?> load(String deviceId) async =>
      _snapshots[deviceId];

  @override
  Future<void> save(String deviceId, WatchHealthSnapshot snapshot) async {
    _snapshots[deviceId] = snapshot;
  }
}

/// File-backed store under application support.
///
/// Each device gets its own file. The device id is hashed so MAC addresses and
/// other provider-specific identities never become path components.
class WatchHealthFileStore implements WatchHealthStore {
  WatchHealthFileStore({Directory? root}) : _root = root;

  static const int _schemaVersion = 1;

  final Directory? _root;

  @override
  Future<WatchHealthSnapshot?> load(String deviceId) async {
    final file = await _fileFor(deviceId);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != _schemaVersion ||
          decoded['deviceId'] != deviceId) {
        return null;
      }
      return _snapshotFromJson(decoded);
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(String deviceId, WatchHealthSnapshot snapshot) async {
    final file = await _fileFor(deviceId);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(_snapshotToJson(deviceId, snapshot)),
      flush: true,
    );
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      // Windows does not replace an existing destination with rename().
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    }
  }

  Future<File> _fileFor(String deviceId) async {
    final root = _root ?? await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/watch_health');
    await directory.create(recursive: true);
    final key = sha256.convert(utf8.encode(deviceId)).toString();
    return File('${directory.path}/$key.json');
  }

  Map<String, Object?> _snapshotToJson(
    String deviceId,
    WatchHealthSnapshot snapshot,
  ) {
    return {
      'schema': _schemaVersion,
      'deviceId': deviceId,
      'syncedAt': snapshot.syncedAt.toIso8601String(),
      'today': {
        'steps': snapshot.todaySteps,
        'distanceMeters': snapshot.todayDistanceMeters,
        'caloriesDeciKcal': snapshot.todayCaloriesDeciKcal,
        'latestHeartRate': snapshot.latestTodayHeartRate,
      },
      'sport': snapshot.sportRecords
          .map((record) => {
                'timestamp': record.timestamp.toIso8601String(),
                'mode': record.mode,
                'steps': record.steps,
                'distanceMeters': record.distanceMeters,
                'caloriesDeciKcal': record.caloriesDeciKcal,
                'heartRate': record.heartRate,
                'hasHeartRate': record.hasHeartRate,
                'partialBucket': record.partialBucket,
              })
          .toList(growable: false),
      'sleep': snapshot.sleepRecords
          .map((record) => {
                'timestamp': record.timestamp.toIso8601String(),
                'state': record.state,
                'backfilled': record.backfilled,
              })
          .toList(growable: false),
    };
  }

  WatchHealthSnapshot _snapshotFromJson(Map<String, dynamic> json) {
    final today = json['today'];
    final sport = json['sport'];
    final sleep = json['sleep'];
    if (today is! Map<String, dynamic> ||
        sport is! List<dynamic> ||
        sleep is! List<dynamic>) {
      throw const FormatException('Incomplete watch health snapshot');
    }

    return WatchHealthSnapshot.fromRecords(
      syncedAt: DateTime.parse(json['syncedAt'] as String),
      sportRecords: sport.map((value) {
        final record = value as Map<String, dynamic>;
        return WatchSportRecord(
          timestamp: DateTime.parse(record['timestamp'] as String),
          mode: record['mode'] as int,
          steps: record['steps'] as int,
          distanceMeters: record['distanceMeters'] as int,
          caloriesDeciKcal: record['caloriesDeciKcal'] as int,
          heartRate: record['heartRate'] as int,
          hasHeartRate: record['hasHeartRate'] as bool,
          partialBucket: record['partialBucket'] as bool,
        );
      }).toList(growable: false),
      sleepRecords: sleep.map((value) {
        final record = value as Map<String, dynamic>;
        return WatchSleepRecord(
          timestamp: DateTime.parse(record['timestamp'] as String),
          state: record['state'] as int,
          backfilled: record['backfilled'] as bool,
        );
      }).toList(growable: false),
      todaySteps: today['steps'] as int?,
      todayDistanceMeters: today['distanceMeters'] as int?,
      todayCaloriesDeciKcal: today['caloriesDeciKcal'] as int?,
      latestTodayHeartRate: today['latestHeartRate'] as int?,
    );
  }
}
