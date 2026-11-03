import 'dart:typed_data';
import 'package:watch_frame_channel/watch_frame_channel.dart';

int wsCrc16(List<int> bytes) => watchCrc16(bytes);

class WSFrame extends WatchFrame {
  WSFrame({required super.seq, super.payload, super.isAck, super.isError});
  static bool validHeader(List<int> bytes, int maxPayloadLength) =>
      WatchFrame.validHeader(bytes, maxPayloadLength);
  static WSFrame decode(Uint8List bytes) {
    final frame = WatchFrame.decode(bytes);
    return WSFrame(
        seq: frame.seq,
        payload: frame.payload,
        isAck: frame.isAck,
        isError: frame.isError);
  }
}
