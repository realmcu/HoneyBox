import 'dart:convert';
import 'dart:typed_data';

import 'honey_l2.dart';

/// Command 0x03 — bind / login ([HoneyProtocol 0x03-bind.rst](../../../../../../HoneyProtocol/docs/protocol/0x03-bind.rst)).
abstract final class HoneyBindCommand {
  static const int command = 0x03;
  static const int version = 0;

  static const int keyBindRequest = 0x01;
  static const int keyBindReply = 0x02;
  static const int keyLoginRequest = 0x03;
  static const int keyLoginReply = 0x04;
  static const int keyUnbind = 0x05;

  /// 32-byte user id: ASCII, NUL-padded (spec allows 32 hex digit string from SDK).
  static Uint8List encodeUserIdWire(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    final units = ascii.encode(trimmed);
    if (units.length > 32) {
      throw ArgumentError.value(userId, 'userId', 'must fit in 32 ASCII bytes');
    }
    final wire = Uint8List(32);
    wire.setRange(0, units.length, units);
    return wire;
  }

  static String decodeUserIdWire(Uint8List wire) {
    if (wire.length != 32) {
      throw FormatException('user id wire must be 32 bytes');
    }
    var end = wire.length;
    while (end > 0 && wire[end - 1] == 0) {
      end--;
    }
    return ascii.decode(wire.sublist(0, end), allowInvalid: false);
  }

  static HoneyL2Message loginRequest(String userId) => HoneyL2Message(
        command: command,
        version: version,
        key: keyLoginRequest,
        value: encodeUserIdWire(userId),
      );

  static HoneyL2Message bindRequest(String userId) => HoneyL2Message(
        command: command,
        version: version,
        key: keyBindRequest,
        value: encodeUserIdWire(userId),
      );

  static HoneyL2Message unbindRequest() => HoneyL2Message(
        command: command,
        version: version,
        key: keyUnbind,
        value: Uint8List.fromList([0]),
      );

  /// Result byte: `00` success, `01` timeout / id mismatch, `02` user rejected (bind).
  static int decodeResultByte(Uint8List value) {
    if (value.length != 1) {
      throw FormatException('bind/login result must be 1 byte');
    }
    return value[0];
  }

  static bool isLoginSuccess(int code) => code == 0;
  static bool isBindSuccess(int code) => code == 0;
}
