import 'dart:typed_data';
import '../connection/user_id.dart';
import 'address.dart';
import 'protocol.dart';

abstract final class WSBindProtocol {
  static WSProtocolEntry entry(int key, String name,
          {bool reply = false, int? retries}) =>
      WSProtocolEntry(
          address: WSProtocolAddress(
              cmd: 3,
              version: 0,
              key: key,
              direction: reply
                  ? WSWireDirection.deviceToPhone
                  : WSWireDirection.phoneToDevice),
          name: name,
          specRef: '0x03-bind#0x${key.toRadixString(16)}',
          isReply: reply,
          maxRetries: retries);
  static final loginRequest = entry(3, 'login');
  static final loginReply = entry(4, 'loginReply', reply: true);
  static final bindRequest = entry(1, 'bind', retries: 0);
  static final bindReply = entry(2, 'bindReply', reply: true);
  static final unbindEntry = entry(5, 'unbind', retries: 0);
  static int decodeResult(Uint8List data) {
    if (data.length != 1) {
      throw const FormatException('authentication result requires one byte');
    }
    return data[0];
  }

  static final login = WSQuery<WSUserId, int>(
      request: loginRequest,
      reply: loginReply,
      encodeData: (id) => id.encode(),
      decodeData: decodeResult);
  static WSQuery<WSUserId, int> bind(Duration timeout) => WSQuery(
      request: bindRequest,
      reply: bindReply,
      encodeData: (id) => id.encode(),
      decodeData: decodeResult,
      replyTimeout: timeout);
  static final unbind = WSCommand<void>(
      request: unbindEntry,
      encodeData: (_) => Uint8List.fromList([0]),
      maxRetries: 0);
  static List<WSProtocolEntry> get entries =>
      [loginRequest, loginReply, bindRequest, bindReply, unbindEntry];
}
