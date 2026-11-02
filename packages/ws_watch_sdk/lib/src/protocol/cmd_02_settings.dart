import 'dart:typed_data';

import '../model/display_format.dart';
import '../model/wall_clock.dart';
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
  static final setDisplayEntry = entry(4, 0, 'setDisplayFormat');
  static final getDisplayEntry = entry(4, 1, 'getDisplayFormat');
  static final displayReply = entry(4, 2, 'displayFormatReply');
  static final displayNotify = entry(4, 3, 'displayFormatNotify');
  static final timeEntry = entry(1, 0, 'setTime');
  static final timeNotify = entry(1, 3, 'timeNotify');
  static final setTime =
      WSCommand<WSWallClock>(request: timeEntry, encodeData: (v) => v.encode());
  static final setDisplayFormat = WSCommand<WSDisplayFormat>(
      request: setDisplayEntry, encodeData: (v) => v.raw);
  static final getDisplayFormat = WSQuery<void, WSDisplayFormat>(
      request: getDisplayEntry,
      reply: displayReply,
      encodeData: (_) => Uint8List(0),
      decodeData: WSDisplayFormat.fromBytes);
  static final m4Entries = [
    setDisplayEntry,
    getDisplayEntry,
    displayReply,
    displayNotify,
    timeNotify
  ];
  static final m4Reports = <WSReport<Object>>[
    WSReport<WSDisplayFormat>(
        entry: displayNotify, decodeData: WSDisplayFormat.fromBytes),
    WSReport<WSWallClock>(entry: timeNotify, decodeData: WSWallClock.fromBytes),
  ];

  static WSProtocolRegistry registry() => WSProtocolRegistry([
        setLanguageEntry,
        getLanguageEntry,
        languageReply,
        languageNotify
      ], reports: [
        WSReport<int>(entry: languageNotify, decodeData: decodeLanguage)
      ]);
}
