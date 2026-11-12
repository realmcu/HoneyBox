import 'dart:typed_data';

import 'ws_l2_message.dart';

/// Command `0x02` settings ([WS protocol 0x02-settings.rst]).
abstract final class WSSettingsCommand {
  static const int command = 0x02;
  static const int version = 0;

  static const int opcodeSet = 0x00;
  static const int opcodeRead = 0x01;
  static const int opcodeReadReply = 0x02;

  static const int keyTime = 0x01;
  static const int keyPhoneSystem = 0x02;
  static const int keyLanguage = 0x03;

  static WSL2Message setPhoneSystem(int system) {
    if (system != 1 && system != 2) {
      throw ArgumentError.value(system, 'system', 'expected 1 (iOS) or 2 (Android)');
    }
    return WSL2Message(
      command: command,
      version: version,
      key: keyPhoneSystem,
      value: Uint8List.fromList([opcodeSet, system]),
    );
  }

  static WSL2Message setTimeUnix(int wallSeconds) {
    final data = ByteData(5);
    data.setUint8(0, opcodeSet);
    data.setUint32(1, wallSeconds);
    return WSL2Message(
      command: command,
      version: version,
      key: keyTime,
      value: data.buffer.asUint8List(),
    );
  }

  static WSL2Message readLanguage() => WSL2Message(
        command: command,
        version: version,
        key: keyLanguage,
        value: Uint8List.fromList([opcodeRead]),
      );

  static int decodeLanguageCode(WSL2Message reply) {
    if (reply.command != command ||
        reply.key != keyLanguage ||
        reply.value.length != 2 ||
        reply.value[0] != opcodeReadReply) {
      throw FormatException('unexpected language read reply');
    }
    return reply.value[1];
  }

  static bool isLanguageReadReply(WSL2Message message) =>
      message.command == command &&
      message.key == keyLanguage &&
      message.value.isNotEmpty &&
      message.value[0] == opcodeReadReply;

  static WSL2Message readKey(int key) => WSL2Message(
        command: command,
        version: version,
        key: key,
        value: Uint8List.fromList([opcodeRead]),
      );

  static WSL2Message setKey(int key, Uint8List body) => WSL2Message(
        command: command,
        version: version,
        key: key,
        value: Uint8List.fromList([opcodeSet, ...body]),
      );

  static bool isReadReplyForKey(WSL2Message message, int key) =>
      message.command == command &&
      message.key == key &&
      message.value.isNotEmpty &&
      message.value[0] == opcodeReadReply;
}
