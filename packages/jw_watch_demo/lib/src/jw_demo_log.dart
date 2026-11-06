import 'dart:developer' as developer;

/// Demo-only diagnostics. Filter logcat with tag [logName].
abstract final class JwDemoLog {
  static bool enabled = !_release;

  static const bool _release =
      bool.fromEnvironment('dart.vm.product', defaultValue: false);

  static const String logName = 'JwWatchDemo';

  static void info(String message) {
    if (!enabled) return;
    developer.log(message, name: logName);
  }
}
