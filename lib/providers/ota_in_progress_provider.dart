import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suppresses normal Watch reconnect/scan handling while an OTA transport owns
/// BLE.
final otaInProgressProvider = StateProvider<bool>((ref) => false);
