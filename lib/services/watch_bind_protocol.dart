import 'dart:math';
import 'dart:typed_data';

enum WatchBindResult { success, failed }

class WatchBindProtocol {
  WatchBindProtocol._();

  static const int command = 0x03;
  static const int bindRequestKey = 0x01;
  static const int bindResponseKey = 0x02;
  static const int userIdLength = 32;

  static final Uint8List processUserId = generateUserId();

  static Uint8List generateUserId() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(userIdLength, (_) => random.nextInt(256)),
    );
  }

  static Uint8List buildRequest(Uint8List userId) {
    if (userId.length != userIdLength) {
      throw ArgumentError.value(
        userId.length,
        'userId.length',
        'Watch bind user ID must be exactly $userIdLength bytes',
      );
    }

    final frame = Uint8List(5 + userIdLength);
    frame[0] = command;
    frame[1] = 0x00;
    frame[2] = bindRequestKey;
    frame[3] = 0x00;
    frame[4] = userIdLength;
    frame.setRange(5, frame.length, userId);
    return frame;
  }

  static WatchBindResult? parseResponse(Uint8List frame) {
    if (frame.length != 6 ||
        frame[0] != command ||
        frame[1] != 0x00 ||
        frame[2] != bindResponseKey ||
        frame[3] != 0x00 ||
        frame[4] != 0x01) {
      return null;
    }
    return frame[5] == 0x00 ? WatchBindResult.success : WatchBindResult.failed;
  }

  static String toHex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
