import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/link/frame.dart';
import 'package:ws_watch_sdk/src/protocol/cmd_02_settings.dart';
import 'package:ws_watch_sdk/src/protocol/message.dart';
import 'package:ws_watch_sdk/src/protocol/protocol.dart';
import 'package:ws_watch_sdk/src/protocol/registry.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

Uint8List hex(String value) => Uint8List.fromList(value
    .split(' ')
    .where((e) => e.isNotEmpty)
    .map((e) => int.parse(e, radix: 16))
    .toList());
WSProtocolAddress address(
        {int key = 3,
        int? opcode = 1,
        int cmd = 2,
        int version = 0,
        WSWireDirection direction = WSWireDirection.phoneToDevice}) =>
    WSProtocolAddress(
        cmd: cmd,
        version: version,
        key: key,
        settingOpcode: opcode,
        direction: direction);

void main() {
  final vectors =
      jsonDecode(File('test/vectors/honey_protocol.json').readAsStringSync())
          as List;
  for (final vector in vectors.cast<Map<String, dynamic>>()) {
    test('HoneyProtocol vector: ${vector['name']}', () {
      final bytes = hex(vector['hex'] as String);
      final direction = vector['direction'] == 'tx'
          ? WSWireDirection.phoneToDevice
          : WSWireDirection.deviceToPhone;
      final message = WSMessage.decode(bytes, direction).single;
      expect(message.address.cmd, vector['cmd']);
      expect(message.address.version, vector['version']);
      expect(message.address.key, vector['key']);
      expect(message.address.settingOpcode, vector['opcode']);
      expect(message.data, hex(vector['data'] as String));
      expect(message.encode(), bytes);
    });
  }
  test('CRC-16/ARC canonical independent check vector', () {
    expect(wsCrc16(ascii.encode('123456789')), 0xbb3d);
    expect(wsCrc16([]), 0);
  });
  test('L1 independent frame fixture and ACK flags', () {
    final bytes = hex('AB 00 00 06 F6 C1 00 01 02 00 03 00 01 01');
    expect(WSFrame.decode(bytes).payload, hex('02 00 03 00 01 01'));
    expect(WSFrame(seq: 1, payload: hex('02 00 03 00 01 01')).encode(), bytes);
    expect(
        WSFrame(seq: 1, isAck: true).encode(), hex('AB 10 00 00 00 00 00 01'));
    expect(WSFrame(seq: 1, isAck: true, isError: true).encode(),
        hex('AB 30 00 00 00 00 00 01'));
  });
  test(
      'registry allows four operations on one key but rejects exact duplicates',
      () {
    final registry = WSSettingsProtocol.registry();
    expect(registry.listByCommandKey(2, 3), hasLength(4));
    expect(
        () => WSProtocolRegistry([
              WSSettingsProtocol.getLanguageEntry,
              WSSettingsProtocol.getLanguageEntry
            ]),
        throwsStateError);
    expect(
        registry.lookup(
            address(opcode: 2, direction: WSWireDirection.deviceToPhone)),
        same(WSSettingsProtocol.languageReply));
  });
  test('range tombstone prevents reusing another opcode or version', () {
    expect(
        () => WSProtocolRegistry([WSSettingsProtocol.getLanguageEntry],
            blockedKeys: {(2, 3)}),
        throwsStateError);
  });
  test('unimplemented raw allowed; dropped and reserved rejected', () {
    for (final status in [
      WSProtocolStatus.unimplemented,
      WSProtocolStatus.dropped,
      WSProtocolStatus.reserved
    ]) {
      final a = address();
      final registry = WSProtocolRegistry([
        WSProtocolEntry(
            address: a, name: 'test', specRef: 'test', status: status)
      ]);
      if (status == WSProtocolStatus.unimplemented) {
        expect(() => registry.checkSend(a, raw: true), returnsNormally);
        expect(() => registry.checkSend(a), throwsArgumentError);
      } else {
        expect(() => registry.checkSend(a, raw: true),
            throwsA(isA<WSDroppedProtocolException>()));
      }
    }
  });
  test('settings require opcode; other commands prohibit it; bounds checked',
      () {
    expect(() => WSMessage(address(opcode: null), []).encode(),
        throwsArgumentError);
    expect(() => WSMessage(address(cmd: 3), []).encode(), throwsArgumentError);
    expect(
        () => WSMessage(address(version: 16), []).encode(), throwsRangeError);
    expect(() => WSMessage(address(), List.filled(65530, 0)).encode(),
        throwsArgumentError);
  });
  test('multiple keys and malformed TLV boundary', () {
    final messages = WSMessage.decode(
            hex('02 00 03 00 02 02 01 03 00 02 03 00'),
            WSWireDirection.deviceToPhone)
        .toList();
    expect(messages, hasLength(2));
    expect(messages.last.address.settingOpcode, 3);
    for (final input in [
      '02',
      '02 01',
      '02 00 03 00',
      '02 00 03 00 00',
      '02 00 03 00 02 02'
    ]) {
      expect(
          () => WSMessage.decode(hex(input), WSWireDirection.deviceToPhone)
              .toList(),
          throwsA(isA<WSProtocolDecodeException>()));
    }
  });
  test('protocol/debug DTOs snapshot mutable bytes', () {
    final bytes = Uint8List.fromList([1]);
    final request =
        WSRawRequest(cmd: 2, version: 0, key: 3, settingOpcode: 0, data: bytes);
    final message = WSMessage(address(opcode: 0), bytes);
    bytes[0] = 8;
    expect(request.data.single, 1);
    expect(message.data.single, 1);
    expect(() => request.data[0] = 2, throwsUnsupportedError);
  });
  test('L2 can fill the exact 65535B L1 payload limit', () {
    final message =
        WSMessage(address(cmd: 5, version: 1, opcode: null), Uint8List(65530));
    final encoded = message.encode();
    expect(encoded, hasLength(65535));
    expect(WSMessage.decode(encoded, WSWireDirection.phoneToDevice).single.data,
        hasLength(65530));
  });
}
