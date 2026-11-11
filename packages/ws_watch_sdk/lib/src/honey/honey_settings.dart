import 'dart:typed_data';

import 'honey_l2.dart';

/// Command `0x02` settings ([HoneyProtocol 0x02-settings.rst]).
abstract final class HoneySettingsCommand {
  static const int command = 0x02;
  static const int version = 0;

  static const int opcodeSet = 0x00;
  static const int opcodeRead = 0x01;
  static const int opcodeReadReply = 0x02;

  static const int keyTime = 0x01;
  static const int keyPhoneSystem = 0x02;
  static const int keyLanguage = 0x03;

  static HoneyL2Message setPhoneSystem(int system) {
    if (system != 1 && system != 2) {
      throw ArgumentError.value(system, 'system', 'expected 1 (iOS) or 2 (Android)');
    }
    return HoneyL2Message(
      command: command,
      version: version,
      key: keyPhoneSystem,
      value: Uint8List.fromList([opcodeSet, system]),
    );
  }

  static HoneyL2Message setTimeUnix(int wallSeconds) {
    final data = ByteData(5);
    data.setUint8(0, opcodeSet);
    data.setUint32(1, wallSeconds);
    return HoneyL2Message(
      command: command,
      version: version,
      key: keyTime,
      value: data.buffer.asUint8List(),
    );
  }

  static HoneyL2Message readLanguage() => HoneyL2Message(
        command: command,
        version: version,
        key: keyLanguage,
        value: Uint8List.fromList([opcodeRead]),
      );

  static int decodeLanguageCode(HoneyL2Message reply) {
    if (reply.command != command ||
        reply.key != keyLanguage ||
        reply.value.length != 2 ||
        reply.value[0] != opcodeReadReply) {
      throw FormatException('unexpected language read reply');
    }
    return reply.value[1];
  }

  static bool isLanguageReadReply(HoneyL2Message message) =>
      message.command == command &&
      message.key == keyLanguage &&
      message.value.isNotEmpty &&
      message.value[0] == opcodeReadReply;
}
