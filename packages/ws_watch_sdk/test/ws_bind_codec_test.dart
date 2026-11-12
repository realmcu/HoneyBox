import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/wire/ws_bind_command.dart';
import 'package:ws_watch_sdk/src/wire/ws_l2_message.dart';

void main() {
  test('login request matches WS protocol 0x03 example', () {
    const userId = '0123456789abcdef0123456789abcdef';
    final wire = WSBindCommand.loginRequest(userId).encode();
    expect(wire.sublist(0, 5), [0x03, 0x00, 0x03, 0x00, 0x20]);
    expect(ascii.decode(wire.sublist(5)), userId);
  });

  test('login reply 00 decodes from spec hex', () {
    final bytes = Uint8List.fromList([0x03, 0x00, 0x04, 0x00, 0x01, 0x00]);
    final messages = WSL2Message.decodeAll(bytes);
    expect(messages, hasLength(1));
    expect(messages.single.key, WSBindCommand.keyLoginReply);
    expect(WSBindCommand.decodeResultByte(messages.single.value), 0);
  });

  test('bind round-trip user id wire', () {
    const id = 'demo-user';
    final encoded = WSBindCommand.encodeUserIdWire(id);
    expect(encoded.length, 32);
    expect(WSBindCommand.decodeUserIdWire(encoded), id);
  });
}
