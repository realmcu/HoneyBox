import 'dart:convert';
import 'dart:typed_data';

import 'ble_cmd_registry.dart';

class WatchModelSnapshot {
  const WatchModelSnapshot({
    required this.batteryPercent,
    required this.batteryValid,
    required this.charging,
    required this.firmwareVersion,
    this.wallClock,
    this.steps = 0,
    this.distanceMeters = 0,
    this.caloriesDeciKcal = 0,
  });

  final int batteryPercent;
  final bool batteryValid;
  final bool charging;
  final String firmwareVersion;
  final DateTime? wallClock;
  final int steps;
  final int distanceMeters;
  final int caloriesDeciKcal;
}

/// CMD 0x02 settings, key 0x30 device information.
///
/// Battery/activity are not part of this command; they are intentionally left
/// unavailable instead of being invented. The wire authority is HoneyProtocol
/// `docs/protocol/0x02-settings.rst`.
class WatchModelProtocol {
  WatchModelProtocol._();

  static Uint8List buildGetRequest() => Uint8List.fromList([
        BleCmd.watchSettings,
        0x00,
        BleCmdWatchModelKey.get,
        0x00,
        0x01,
        0x01,
      ]);

  static WatchModelSnapshot? parseSnapshot(Uint8List frame) {
    if (frame.length < 6 ||
        frame[0] != BleCmd.watchSettings ||
        frame[1] != 0x00 ||
        frame[2] != BleCmdWatchModelKey.snapshot) {
      return null;
    }
    final valueLength = (frame[3] << 8) | frame[4];
    if (frame.length != 5 + valueLength || valueLength < 18) {
      return null;
    }
    if (frame[5] != 0x02) return null;

    final major = frame[8];
    final minor = frame[9];
    final revision = frame[10];
    return WatchModelSnapshot(
      batteryPercent: 0,
      batteryValid: false,
      charging: false,
      firmwareVersion: '$major.$minor.$revision',
    );
  }

  static String decodeSerial(Uint8List frame) {
    if (frame.length < 23) return '';
    final serialLength = frame[22];
    if (serialLength > 32 || frame.length < 23 + serialLength) return '';
    return utf8.decode(
      frame.sublist(23, 23 + serialLength),
      allowMalformed: true,
    );
  }
}
