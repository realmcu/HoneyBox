import 'dart:typed_data';

import '../errors.dart';
import 'address.dart';

class WSMessage {
  WSMessage(this.address, List<int> data)
      : data = Uint8List.fromList(data).asUnmodifiableView();
  final WSProtocolAddress address;
  final Uint8List data;

  Uint8List encode() {
    address.validate();
    final value = [
      if (address.settingOpcode != null) address.settingOpcode!,
      ...data
    ];
    if (value.length > 65530) {
      throw ArgumentError('L2 payload exceeds L1 limit');
    }
    return Uint8List.fromList([
      address.cmd,
      address.version << 4,
      address.key,
      value.length >> 8,
      value.length & 255,
      ...value
    ]);
  }

  /// Lazy iteration preserves earlier valid keys when a later TLV is truncated.
  static Iterable<WSMessage> decode(
      Uint8List bytes, WSWireDirection direction) sync* {
    if (bytes.length < 2 || bytes[1] & 15 != 0) {
      throw WSProtocolDecodeException(0, 0, bytes, 'invalid L2 header');
    }
    final cmd = bytes[0], version = bytes[1] >> 4;
    var offset = 2;
    while (offset < bytes.length) {
      if (bytes.length - offset < 3) {
        throw WSProtocolDecodeException(cmd, 0, bytes, 'truncated TLV header');
      }
      final key = bytes[offset],
          length = (bytes[offset + 1] << 8) | bytes[offset + 2];
      offset += 3;
      if (offset + length > bytes.length || (cmd == 2 && length == 0)) {
        throw WSProtocolDecodeException(cmd, key, bytes, 'invalid TLV length');
      }
      final opcode = cmd == 2 ? bytes[offset] : null;
      yield WSMessage(
          WSProtocolAddress(
              cmd: cmd,
              version: version,
              key: key,
              settingOpcode: opcode,
              direction: direction),
          bytes.sublist(offset + (cmd == 2 ? 1 : 0), offset + length));
      offset += length;
    }
  }
}
