import 'dart:typed_data';

import 'ws_l2_message.dart';

/// Command `0x04` notifications ([WS protocol 0x04-notification.rst]).
abstract final class WSControlCommand {
  static const int command = 0x04;
  static const int version = 0;

  static const int keyBatteryQuery = 0x50;
  static const int keyBatteryReply = 0x51;

  static WSL2Message batteryQuery() => WSL2Message(
        command: command,
        version: version,
        key: keyBatteryQuery,
        value: Uint8List(0),
      );

  static int decodeBatteryPercent(WSL2Message reply) {
    if (reply.command != command ||
        reply.key != keyBatteryReply ||
        reply.value.length < 1) {
      throw FormatException('unexpected battery reply');
    }
    final percent = reply.value[0];
    if (percent < 0 || percent > 100) {
      throw FormatException('battery percent out of range: $percent');
    }
    return percent;
  }
}
