import 'dart:developer' as developer;

/// Demo-only diagnostics. Filter logcat with tag [logName] or [syncLogName].
abstract final class WsDemoLog {
  static bool enabled = !_release;

  static const bool _release =
      bool.fromEnvironment('dart.vm.product', defaultValue: false);

  static const String logName = 'WsWatchDemo';

  /// Health history sync UI (`WsHistorySyncRunController`).
  static const String syncLogName = 'WsDemoSync';

  static void info(String message) {
    if (!enabled) return;
    _emit(logName, message);
  }

  static void sync(String message) {
    if (!enabled) return;
    _emit(syncLogName, message);
  }

  static void _emit(String name, String message) {
    developer.log('${_timestamp()} $message', name: name);
  }

  static String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
