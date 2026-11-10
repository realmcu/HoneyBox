import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/settings/jw_address_book_codec.dart';

void main() {
  test('address book phase packet matches Android layout', () {
    expect(
      encodeAddressBookPhase(status: 0, size: 3),
      [0, 0, 3],
    );
    expect(
      encodeAddressBookPhase(status: 1, size: 10),
      [1, 0, 10],
    );
    expect(encodeAddressBookPhase(status: 0, size: 0), [0, 0, 0]);
  });

  test('address book entry encodes UTF-8 name and phone', () {
    final bytes = encodeAddressBookEntry(
      const JWAddressBookEntry(name: '张三', phone: '13800138000'),
    );
    expect(bytes[0], 0x02);
    final nameLen = bytes[1];
    final name = utf8.decode(bytes.sublist(2, 2 + nameLen));
    expect(name, '张三');
    final phoneLen = bytes[2 + nameLen];
    final phone = utf8.decode(bytes.sublist(2 + nameLen + 1, bytes.length));
    expect(phone, '13800138000');
  });

  test('entry ack requires status byte 0x02', () {
    expect(decodeAddressBookEntryAck(Uint8List.fromList([0x02])), isTrue);
    expect(decodeAddressBookEntryAck(Uint8List.fromList([0x01])), isFalse);
    expect(decodeAddressBookEntryAck(Uint8List(0)), isFalse);
  });
}
