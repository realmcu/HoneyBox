import 'dart:typed_data';

import 'honey_l2.dart';

/// Command `0x11` spot measure ([HoneyProtocol 0x11-measurement.rst]).
abstract final class HoneyMeasureCommand {
  static const int command = 0x11;
  static const int version = 0;

  static const int keyStartHeartRate = 0x03;
  static const int keyStartHeartRateReply = 0x04;
  static const int keyStopHeartRate = 0x05;

  static HoneyL2Message startHeartRate() => HoneyL2Message(
        command: command,
        version: version,
        key: keyStartHeartRate,
        value: Uint8List(0),
      );

  static HoneyL2Message stopHeartRate() => HoneyL2Message(
        command: command,
        version: version,
        key: keyStopHeartRate,
        value: Uint8List(0),
      );

  static bool isStartHeartRateSuccess(HoneyL2Message reply) =>
      reply.command == command &&
      reply.key == keyStartHeartRateReply &&
      reply.value.length == 1 &&
      reply.value[0] == 0x00;
}
