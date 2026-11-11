import 'dart:typed_data';

import 'honey_l2.dart';

/// Command `0x04` notifications ([HoneyProtocol 0x04-notification.rst]).
abstract final class HoneyControlCommand {
  static const int command = 0x04;
  static const int version = 0;

  static const int keyBatteryQuery = 0x50;
  static const int keyBatteryReply = 0x51;

  static HoneyL2Message batteryQuery() => HoneyL2Message(
        command: command,
        version: version,
        key: keyBatteryQuery,
        value: Uint8List(0),
      );

  static int decodeBatteryPercent(HoneyL2Message reply) {
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
