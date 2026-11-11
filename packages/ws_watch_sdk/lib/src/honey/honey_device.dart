import 'dart:typed_data';

import 'honey_l2.dart';
import 'honey_settings.dart';

/// Device info / capability keys on command `0x02` ([HoneyProtocol 0x02-settings.rst]).
abstract final class HoneyDeviceCommand {
  static const int command = HoneySettingsCommand.command;
  static const int version = HoneySettingsCommand.version;

  static const int keyDeviceInfo = 0x30;
  static const int keyCapabilities = 0x31;
  static const int capabilitiesBlobLength = 16;

  static HoneyL2Message readDeviceInfo() => HoneyL2Message(
        command: command,
        version: version,
        key: keyDeviceInfo,
        value: Uint8List.fromList([HoneySettingsCommand.opcodeRead]),
      );

  static HoneyL2Message readCapabilities() => HoneyL2Message(
        command: command,
        version: version,
        key: keyCapabilities,
        value: Uint8List.fromList([HoneySettingsCommand.opcodeRead]),
      );

  static bool isDeviceInfoReadReply(HoneyL2Message message) =>
      message.command == command &&
      message.key == keyDeviceInfo &&
      message.value.isNotEmpty &&
      message.value[0] == HoneySettingsCommand.opcodeReadReply;

  static bool isCapabilitiesReadReply(HoneyL2Message message) =>
      message.command == command &&
      message.key == keyCapabilities &&
      message.value.isNotEmpty &&
      message.value[0] == HoneySettingsCommand.opcodeReadReply;

  /// Minimal stub fields after opcode byte (model 2B + trailing serial if present).
  static ({int modelId, String serialNumber}) decodeDeviceInfoStub(
    HoneyL2Message reply,
  ) {
    if (!isDeviceInfoReadReply(reply) || reply.value.length < 3) {
      throw FormatException('unexpected device info reply');
    }
    final modelId = (reply.value[1] << 8) | reply.value[2];
    var serial = '';
    if (reply.value.length > 17) {
      final len = reply.value[16];
      final start = 17;
      final end = (start + len).clamp(start, reply.value.length);
      serial = String.fromCharCodes(reply.value.sublist(start, end));
    }
    return (modelId: modelId, serialNumber: serial);
  }

  static Uint8List decodeCapabilitiesBlob(HoneyL2Message reply) {
    if (!isCapabilitiesReadReply(reply)) {
      throw FormatException('unexpected capabilities reply');
    }
    if (reply.value.length != 1 + capabilitiesBlobLength) {
      throw FormatException(
        'capabilities blob must be $capabilitiesBlobLength bytes',
      );
    }
    return Uint8List.sublistView(reply.value, 1);
  }
}
