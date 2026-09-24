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

class WatchModelProtocol {
  WatchModelProtocol._();

  static Uint8List buildGetRequest() => Uint8List.fromList([
        BleCmd.watchModel,
        0x00,
        BleCmdWatchModelKey.get,
        0x00,
        0x00,
      ]);

  static WatchModelSnapshot? parseSnapshot(Uint8List frame) {
    if (frame.length < 9 ||
        frame[0] != BleCmd.watchModel ||
        frame[1] != 0x00 ||
        frame[2] != BleCmdWatchModelKey.snapshot) {
      return null;
    }
    final valueLength = (frame[3] << 8) | frame[4];
    if (valueLength < 4 || frame.length != 5 + valueLength) {
      return null;
    }
    final schema = frame[5];
    if (schema != 1 && schema != 2) return null;
    final flags = frame[6];
    final versionLength = frame[8];
    final fixedLength = schema == 1 ? 4 : 20;
    if (fixedLength + versionLength != valueLength) return null;

    final wallClockSeconds = schema == 2 ? _readU32(frame, 9) : 0;
    final versionOffset = schema == 2 ? 25 : 9;

    return WatchModelSnapshot(
      batteryPercent: frame[7] > 100 ? 100 : frame[7],
      batteryValid: (flags & 0x01) != 0,
      charging: (flags & 0x02) != 0,
      firmwareVersion:
          utf8.decode(frame.sublist(versionOffset), allowMalformed: true),
      wallClock: schema == 2 && (flags & 0x04) != 0
          ? DateTime.fromMillisecondsSinceEpoch(
              wallClockSeconds * 1000,
              isUtc: true,
            )
          : null,
      steps: schema == 2 ? _readU32(frame, 13) : 0,
      distanceMeters: schema == 2 ? _readU32(frame, 17) : 0,
      caloriesDeciKcal: schema == 2 ? _readU32(frame, 21) : 0,
    );
  }

  static int _readU32(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
