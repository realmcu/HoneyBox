import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/connection/user_id.dart';
import 'package:ws_watch_sdk/src/protocol/cmd_03_bind.dart';
import 'package:ws_watch_sdk/src/protocol/core_registry.dart';
import 'package:ws_watch_sdk/src/protocol/message.dart';

// Expected bytes from HoneyProtocol 0x02-settings and 0x03-bind.
void main() {
  test('authentication fields are exactly 32 bytes, no settings opcode', () {
    final id = WSUserId('abc');
    expect(
        WSMessage(WSBindProtocol.login.request.address, id.encode()).encode(),
        [3, 0, 3, 0, 32, 97, 98, 99, ...List.filled(29, 0)]);
    final bind = WSBindProtocol.bind(const Duration(seconds: 60));
    expect(bind.request.maxRetries, 0);
    expect(bind.replyTimeout, const Duration(seconds: 60));
    expect(
        WSMessage(WSBindProtocol.unbind.request.address,
                WSBindProtocol.unbind.encodeData(null))
            .encode(),
        [3, 0, 5, 0, 1, 0]);
    expect(WSBindProtocol.unbind.maxRetries, 0);
  });
  test('initialization vectors and wall clock preserve calendar fields', () {
    final p = WSInitializationProtocol.system;
    expect(WSMessage(p.request.address, p.encodeData(2)).encode(),
        [2, 0, 2, 0, 2, 0, 2]);
    expect(() => p.encodeData(0), throwsArgumentError);
    final time = WSInitializationProtocol.time;
    expect(
        WSMessage(time.request.address,
                time.encodeData(DateTime(1970, 1, 2, 3, 4, 5)))
            .encode(),
        [2, 0, 1, 0, 5, 0, 0, 1, 0x7c, 0xa5]); // 97445 wall-clock seconds.
    expect(
        WSMessage(WSInitializationProtocol.capabilityRequest.address,
                Uint8List(0))
            .encode(),
        [2, 0, 0x31, 0, 1, 1]);
    expect(
        WSMessage(WSInitializationProtocol.infoRequest.address, Uint8List(0))
            .encode(),
        [2, 0, 0x30, 0, 1, 1]);
    expect(() => time.encodeData(DateTime(1969)), throwsRangeError);
  });
}
