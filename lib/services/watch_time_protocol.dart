import 'dart:typed_data';

import 'ble_cmd_registry.dart';

/// Watch time sync (CMD 0x02) frame builder.
///
/// Value is 4 bytes big-endian wall clock seconds (1970 epoch).
/// The caller passes the user's local DateTime; this class folds it with
/// UTC rules via DateTime.utc() — the strict inverse of gmtime_r on firmware.
class WatchTimeProtocol {
  WatchTimeProtocol._();

  static const int minimumYear = 1970;
  static const int maximumYear = 2106;

  static Uint8List buildSetTime(DateTime localTime) {
    if (localTime.year < minimumYear || localTime.year > maximumYear) {
      throw ArgumentError.value(
        localTime.year,
        'localTime.year',
        'Watch time year must be between $minimumYear and $maximumYear',
      );
    }

    // Fold the local calendar fields with UTC rules.
    // DateTime.utc(...) treats the supplied fields as UTC, matching
    // exactly how gmtime_r unfolds the scalar on the firmware side.
    // DO NOT use DateTime(localTime.year, ...) — that applies the device
    // timezone a second time.
    final seconds = DateTime.utc(
      localTime.year,
      localTime.month,
      localTime.day,
      localTime.hour,
      localTime.minute,
      localTime.second,
    ).millisecondsSinceEpoch ~/ 1000;

    return Uint8List.fromList([
      BleCmd.watchTime,
      0x00,
      BleCmdWatchTimeKey.setTime,
      0x00,
      0x04,
      (seconds >> 24) & 0xFF,
      (seconds >> 16) & 0xFF,
      (seconds >> 8) & 0xFF,
      seconds & 0xFF,
    ]);
  }
}
