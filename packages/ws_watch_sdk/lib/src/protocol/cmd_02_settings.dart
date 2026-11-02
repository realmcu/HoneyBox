import 'dart:typed_data';

import 'address.dart';
import 'protocol.dart';
import 'registry.dart';

abstract final class WSSettingsProtocol {
  static WSProtocolEntry entry(
          int key, int opcode, String name) =>
      WSProtocolEntry(
          address: WSProtocolAddress(
              cmd: 2,
              version: 0,
              key: key,
              settingOpcode: opcode,
              direction: opcode < 2
                  ? WSWireDirection.phoneToDevice
                  : WSWireDirection.deviceToPhone),
          name: name,
          specRef: '0x02-settings#0x${key.toRadixString(16)}-op$opcode',
          isReply: opcode == 2);
  static final setLanguageEntry = entry(3, 0, 'setLanguage');
  static final getLanguageEntry = entry(3, 1, 'getLanguage');
  static final languageReply = entry(3, 2, 'languageReply');
  static final languageNotify = entry(3, 3, 'languageNotify');
  static final setLanguage = WSCommand<int>(
      request: setLanguageEntry,
      encodeData: (v) {
        RangeError.checkValueInInterval(v, 0, 255, 'language');
        return Uint8List.fromList([v]);
      });
  static int decodeLanguage(Uint8List data) {
    if (data.length != 1) {
      throw const FormatException('language requires one byte');
    }
    return data[0]; // Unknown language codes survive decoding.
  }

  static final getLanguage = WSQuery<void, int>(
      request: getLanguageEntry,
      reply: languageReply,
      encodeData: (_) => Uint8List(0),
      decodeData: decodeLanguage);
  static WSProtocolRegistry registry() => WSProtocolRegistry([
        setLanguageEntry,
        getLanguageEntry,
        languageReply,
        languageNotify
      ], reports: [
        WSReport<int>(entry: languageNotify, decodeData: decodeLanguage)
      ]);
}
