import 'dart:typed_data';

import 'ws_data_command.dart';
import 'ws_l2_message.dart';
import '../today/ws_today_models.dart';

/// Today segment on command `0x05` ([WS protocol 0x05-data.rst] keys `0x60`/`0x61`).
abstract final class WSTodayCodec {
  static const int keyQuery = 0x60;
  static const int keyTodayPayload = 0x61;
  static const int payloadLength = 23;

  static WSL2Message query() => WSL2Message(
        command: WSDataCommand.command,
        version: WSDataCommand.version,
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
      dataTime: data.getUint32(0, Endian.little),
      steps: data.getUint32(4, Endian.little),
      distanceMeters: data.getUint32(8, Endian.little),
      caloriesTenthKcal: data.getUint32(12, Endian.little),
      activeMinutes: data.getUint16(16, Endian.little),
      recentHeartRateBpm: value[18],
      recentHeartRateTime: data.getUint32(19, Endian.little),
    );
  }
}
