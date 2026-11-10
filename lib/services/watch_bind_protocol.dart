import 'dart:math';
import 'dart:typed_data';

import 'ble_cmd_registry.dart';

enum WatchBindResult { success, failed }

class WatchBindProtocol {
  WatchBindProtocol._();

  // CMD / key 值集中在 `ble_cmd_registry.dart`:CMD 字节走 [BleCmd.watchBind],
  // 子命令 key 走 [BleCmdWatchBindKey]。
  static const int userIdLength = 32;

  static Uint8List generateUserId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return Uint8List.fromList(hex.codeUnits);
  }

  static Uint8List buildLoginRequest(Uint8List userId) =>
      _buildUserIdRequest(BleCmdWatchBindKey.loginRequest, userId);

  static Uint8List buildRequest(Uint8List userId) =>
      _buildUserIdRequest(BleCmdWatchBindKey.bindRequest, userId);

  static Uint8List _buildUserIdRequest(int key, Uint8List userId) {
    if (userId.length != userIdLength) {
      throw ArgumentError.value(
        userId.length,
        'userId.length',
        'Watch bind user ID must be exactly $userIdLength bytes',
      );
    }

    final frame = Uint8List(5 + userIdLength);
    frame[0] = BleCmd.watchBind;
    frame[1] = 0x00;
    frame[2] = key;
    frame[3] = 0x00;
    frame[4] = userIdLength;
    frame.setRange(5, frame.length, userId);
    return frame;
  }

  static WatchBindResult? parseLoginResponse(Uint8List frame) =>
      _parseStatusResponse(frame, BleCmdWatchBindKey.loginResponse);

  static WatchBindResult? parseResponse(Uint8List frame) =>
      _parseStatusResponse(frame, BleCmdWatchBindKey.bindResponse);

  static WatchBindResult? _parseStatusResponse(Uint8List frame, int key) {
    if (frame.length != 6 ||
        frame[0] != BleCmd.watchBind ||
        frame[1] != 0x00 ||
        frame[2] != key ||
        frame[3] != 0x00 ||
        frame[4] != 0x01) {
      return null;
    }
    return frame[5] == 0x00 ? WatchBindResult.success : WatchBindResult.failed;
  }

  static String toHex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
