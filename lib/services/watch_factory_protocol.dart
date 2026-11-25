import 'dart:convert';
import 'dart:typed_data';

import 'ble_cmd_registry.dart';

/// One response on HoneyProtocol CMD 0x06.
class WatchFactoryResponse {
  const WatchFactoryResponse(this.key, this.value);

  final int key;
  final Uint8List value;
}

/// HoneyProtocol CMD 0x06 factory-test framing.
///
/// The UI only uses the read-only requests in the first iteration. The generic
/// [buildCommand] helper keeps the byte layer ready for motor and write tests.
abstract final class WatchFactoryProtocol {
  static Uint8List buildRead(int requestKey) => buildCommand(requestKey);

  static Uint8List buildCommand(int key, [List<int> value = const []]) {
    if (key < 0 || key > 0xFF) {
      throw ArgumentError.value(key, 'key', 'must fit in one byte');
    }
    if (value.length > 0xFFFF) {
      throw ArgumentError.value(value.length, 'value.length', 'too long');
    }
    return Uint8List.fromList([
      BleCmd.watchFactory,
      0x00,
      key,
      (value.length >> 8) & 0xFF,
      value.length & 0xFF,
      ...value,
    ]);
  }

  static WatchFactoryResponse? parseResponse(Uint8List frame) {
    if (frame.length < 5 ||
        frame[0] != BleCmd.watchFactory ||
        frame[1] != 0x00) {
      return null;
    }
    final valueLength = (frame[3] << 8) | frame[4];
    if (frame.length != 5 + valueLength) return null;
    return WatchFactoryResponse(
      frame[2],
      Uint8List.fromList(frame.sublist(5)),
    );
  }

  static String decodeBatteryMillivolts(Uint8List value) {
    if (value.length != 2) return hex(value);
    final raw = (value[0] << 8) | value[1];
    final signed = raw >= 0x8000 ? raw - 0x10000 : raw;
    return '$signed mV';
  }

  static String decodePatchVersion(Uint8List value) {
    if (value.length != 4) return hex(value);
    return '${value[0]}.${value[1]}.${value[2]}.${value[3]}';
  }

  static String decodeText(Uint8List value) {
    if (value.isEmpty) return '';
    if (value.every((byte) => byte == 0 || (byte >= 0x20 && byte <= 0x7E))) {
      return ascii.decode(value, allowInvalid: true).replaceAll('\x00', '');
    }
    return hex(value);
  }

  static String hex(Uint8List value) =>
      value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}
