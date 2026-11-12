import 'dart:typed_data';

import 'ws_l2_message.dart';
import 'ws_settings_command.dart';

/// Device info / capability keys on command `0x02` ([WS protocol 0x02-settings.rst]).
abstract final class WSDeviceCommand {
  static const int command = WSSettingsCommand.command;
  static const int version = WSSettingsCommand.version;

  static const int keyDeviceInfo = 0x30;
  static const int keyCapabilities = 0x31;
  static const int capabilitiesBlobLength = 16;

  static WSL2Message readDeviceInfo() => WSL2Message(
        command: command,
        version: version,
        key: keyDeviceInfo,
        value: Uint8List.fromList([WSSettingsCommand.opcodeRead]),
      );

  static WSL2Message readCapabilities() => WSL2Message(
        command: command,
        version: version,
        key: keyCapabilities,
        value: Uint8List.fromList([WSSettingsCommand.opcodeRead]),
      );

  static bool isDeviceInfoReadReply(WSL2Message message) =>
      message.command == command &&
      message.key == keyDeviceInfo &&
      message.value.isNotEmpty &&
      message.value[0] == WSSettingsCommand.opcodeReadReply;

  static bool isCapabilitiesReadReply(WSL2Message message) =>
      message.command == command &&
      message.key == keyCapabilities &&
      message.value.isNotEmpty &&
      message.value[0] == WSSettingsCommand.opcodeReadReply;

  /// Minimal stub fields after opcode byte (model 2B + trailing serial if present).
  static ({int modelId, String serialNumber}) decodeDeviceInfoStub(
    WSL2Message reply,
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

  static Uint8List decodeCapabilitiesBlob(WSL2Message reply) {
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
