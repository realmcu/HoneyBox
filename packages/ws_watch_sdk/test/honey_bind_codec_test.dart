import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/honey/honey_bind.dart';
import 'package:ws_watch_sdk/src/honey/honey_l2.dart';

void main() {
  test('login request matches HoneyProtocol 0x03 example', () {
    const userId = '0123456789abcdef0123456789abcdef';
    final wire = HoneyBindCommand.loginRequest(userId).encode();
    expect(wire.sublist(0, 5), [0x03, 0x00, 0x03, 0x00, 0x20]);
    expect(ascii.decode(wire.sublist(5)), userId);
  });

  test('login reply 00 decodes from spec hex', () {
    final bytes = Uint8List.fromList([0x03, 0x00, 0x04, 0x00, 0x01, 0x00]);
    final messages = HoneyL2Message.decodeAll(bytes);
    expect(messages, hasLength(1));
    expect(messages.single.key, HoneyBindCommand.keyLoginReply);
    expect(HoneyBindCommand.decodeResultByte(messages.single.value), 0);
  });

  test('bind round-trip user id wire', () {
    const id = 'demo-user';
    final encoded = HoneyBindCommand.encodeUserIdWire(id);
    expect(encoded.length, 32);
    expect(HoneyBindCommand.decodeUserIdWire(encoded), id);
  });
}
