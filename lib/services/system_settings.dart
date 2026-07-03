import 'package:flutter/services.dart';

/// Thin bridge to a few Android system settings screens that the Flutter
/// plugins don't expose directly.
class SystemSettings {
  static const _channel = MethodChannel('ebadge/system');

  /// Open the OS location-services (GPS) settings screen so the user can turn
  /// location on — BLE scanning on Android requires it. `permission_handler`
  /// only opens the app's own settings, not this system toggle.
  static Future<void> openLocationSettings() =>
      _channel.invokeMethod('openLocationSettings');
}
