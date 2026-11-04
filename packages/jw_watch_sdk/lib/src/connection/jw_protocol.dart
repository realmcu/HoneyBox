import 'dart:typed_data';

final class JWProtocolRequest {
  const JWProtocolRequest({
    required this.command,
    required this.key,
    required this.responseKey,
    this.responseCommand,
    this.value,
  });

  final int command;
  final int key;
  final int? responseKey;
  final int? responseCommand;
  final Uint8List? value;
}

abstract final class JWProtocolCommands {
  static JWProtocolRequest functions() =>
      const JWProtocolRequest(command: 2, key: 0x36, responseKey: 0x37);
  static JWProtocolRequest factorySwitch() =>
      const JWProtocolRequest(command: 6, key: 0x3d, responseKey: 0x3e);
  static JWProtocolRequest login(Uint8List identity) =>
      JWProtocolRequest(command: 3, key: 3, responseKey: 4, value: identity);
  static JWProtocolRequest bind(Uint8List identity) =>
      JWProtocolRequest(command: 3, key: 1, responseKey: 2, value: identity);
  static JWProtocolRequest unbind() =>
      const JWProtocolRequest(command: 3, key: 5, responseKey: null);
}

Uint8List encodeJWRequest(JWProtocolRequest request) {
  final value = request.value ?? Uint8List(0);
  if (value.length > 231) throw ArgumentError('JW value exceeds L2 limit');
  return Uint8List.fromList([
    request.command,
    0,
    request.key,
    value.length >> 8,
    value.length & 0xff,
    ...value,
  ]);
}

final class JWProtocolMessage {
  const JWProtocolMessage(this.command, this.key, this.value);
  final int command;
  final int key;
  final Uint8List value;
}

List<JWProtocolMessage> decodeJWMessages(Uint8List bytes) {
  if (bytes.length < 2 || bytes[1] != 0) {
    throw const FormatException('Invalid JW L2 header');
  }
  final result = <JWProtocolMessage>[];
  var offset = 2;
  while (offset < bytes.length) {
    if (offset + 3 > bytes.length) {
      throw const FormatException('Invalid JW L2 field header');
    }
    final key = bytes[offset];
    final length = ((bytes[offset + 1] & 1) << 8) | bytes[offset + 2];
    offset += 3;
    if (length > 231 || offset + length > bytes.length) {
      throw const FormatException('Invalid JW L2 field length');
    }
    result.add(JWProtocolMessage(bytes[0], key,
        Uint8List.fromList(bytes.sublist(offset, offset + length))));
    offset += length;
  }
  return result;
}
