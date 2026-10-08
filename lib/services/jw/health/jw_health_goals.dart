import 'dart:convert';
import 'dart:io';

class JwHealthGoals {
  final int? steps, sleepMinutes;
  final double? energyKcal;
  const JwHealthGoals({this.steps, this.sleepMinutes, this.energyKcal});
  void validate() {
    if (steps != null && steps! <= 0 ||
        sleepMinutes != null && sleepMinutes! <= 0 ||
        energyKcal != null && (!energyKcal!.isFinite || energyKcal! <= 0)) {
      throw ArgumentError('Targets must be positive finite values');
    }
  }

  Map<String, Object?> toJson() =>
      {'steps': steps, 'sleepMinutes': sleepMinutes, 'energyKcal': energyKcal};
  factory JwHealthGoals.fromJson(Map<String, Object?> json) {
    try {
      final goals = JwHealthGoals(
          steps: json['steps'] as int?,
          sleepMinutes: json['sleepMinutes'] as int?,
          energyKcal: (json['energyKcal'] as num?)?.toDouble());
      goals.validate();
      return goals;
    } catch (_) {
      throw const FormatException('Invalid stored health targets');
    }
  }
}

/// App-local per-device targets; this store has no BLE command dependency.
class JwHealthGoalStore {
  final File file;
  static final _tails = <String, Future<void>>{};
  JwHealthGoalStore(this.file);
  String get _key {
    final path = file.absolute.uri.normalizePath().toString();
    return Platform.isWindows ? path.toLowerCase() : path;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final key = _key;
    final result = (_tails[key] ?? Future<void>.value()).then((_) => action());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _tails[key] = tail;
    tail.whenComplete(() {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    return result;
  }

  void _validateDevice(String deviceKey) {
    if (deviceKey.trim().isEmpty) {
      throw ArgumentError('Device identity is required');
    }
  }

  Future<Map<String, JwHealthGoals>> _readAll() async {
    if (!await file.exists()) return {};
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['version'] != 1 || json['devices'] is! Map) {
        throw const FormatException('Health targets schema');
      }
      final result = <String, JwHealthGoals>{};
      for (final entry in (json['devices'] as Map).entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException('Health targets device schema');
        }
        _validateDevice(entry.key as String);
        result[entry.key as String] = JwHealthGoals.fromJson(
            Map<String, Object?>.from(entry.value as Map));
      }
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Health targets schema');
    }
  }

  Future<JwHealthGoals> read(String deviceKey) => _serial(() async {
        _validateDevice(deviceKey);
        return (await _readAll())[deviceKey] ?? const JwHealthGoals();
      });
  Future<void> write(String deviceKey, JwHealthGoals goals) =>
      _serial(() async {
        _validateDevice(deviceKey);
        goals.validate();
        final all = await _readAll();
        all[deviceKey] = goals;
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
            jsonEncode({
              'version': 1,
              'devices': {
                for (final entry in all.entries) entry.key: entry.value.toJson()
              }
            }),
            flush: true);
        await temporary.rename(file.path);
      });
}
