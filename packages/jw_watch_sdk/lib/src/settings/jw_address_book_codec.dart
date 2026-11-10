import 'dart:convert';
import 'dart:typed_data';

import 'jw_address_book_models.dart';

/// Mirrors `FunctionPacketHelper.prepareSetAddressBookStartOrEndPacket`.
Uint8List encodeAddressBookPhase({required int status, required int size}) {
  final keyValue = Uint8List(3)
    ..[0] = status
    ..[1] = (size >> 8) & 0xff
    ..[2] = size & 0xff;
  return keyValue;
}

/// Mirrors `FunctionPacketHelper.prepareSetAddressPacket`.
Uint8List encodeAddressBookEntry(JWAddressBookEntry entry) {
  final name = entry.name.trim();
  final phone = entry.phone.trim();
  final nameData = name.isEmpty ? Uint8List(0) : Uint8List.fromList(utf8.encode(name));
  final phoneData =
      phone.isEmpty ? Uint8List(0) : Uint8List.fromList(utf8.encode(phone));
  final total = 2 + nameData.length + 1 + phoneData.length;
  if (total > 231) {
    throw ArgumentError('JW address book entry exceeds SETTINGS payload limit');
  }
  final keyValue = Uint8List(total)
    ..[0] = 0x02
    ..[1] = nameData.length
    ..setRange(2, 2 + nameData.length, nameData)
    ..[2 + nameData.length] = phoneData.length
    ..setRange(2 + nameData.length + 1, total, phoneData);
  return keyValue;
}

bool decodeAddressBookEntryAck(Uint8List value) =>
    value.isNotEmpty && value[0] == 0x02;
