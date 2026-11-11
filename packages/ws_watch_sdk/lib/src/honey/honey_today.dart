import 'dart:typed_data';

import 'honey_data.dart';
import 'honey_l2.dart';
import '../today/ws_today_models.dart';

/// Today segment on command `0x05` ([HoneyProtocol 0x05-data.rst] keys `0x60`/`0x61`).
abstract final class HoneyTodayCommand {
  static const int keyQuery = 0x60;
  static const int keyTodayPayload = 0x61;
  static const int payloadLength = 23;

  static HoneyL2Message query() => HoneyL2Message(
        command: HoneyDataCommand.command,
        version: HoneyDataCommand.version,
        key: keyQuery,
        value: Uint8List(0),
      );

  static WSTodaySnapshot decodePayload(Uint8List value) {
    if (value.length != payloadLength) {
      throw FormatException(
        'today payload must be $payloadLength bytes, got ${value.length}',
      );
    }
    final data = ByteData.sublistView(value);
    return WSTodaySnapshot(
      dataTime: data.getUint32(0),
      steps: data.getUint32(4),
      distanceMeters: data.getUint32(8),
      caloriesTenthKcal: data.getUint32(12),
      activeMinutes: data.getUint16(16),
      recentHeartRateBpm: value[18],
      recentHeartRateTime: data.getUint32(19),
    );
  }
}
