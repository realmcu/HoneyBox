import 'dart:typed_data';
import 'package:watch_frame_channel/watch_frame_channel.dart';
import '../model/frame.dart';
import 'frame.dart';

class WSFrameAssembler extends WatchFrameAssembler {
  WSFrameAssembler(
      {required super.timeout,
      required super.maxPayloadLength,
      required void Function(WSFrame frame, Uint8List raw) onFrame,
      required void Function(WSFrameKind kind, Uint8List raw, int? seq)
          onError})
      : super(
            onFrame: (f, raw) => onFrame(
                WSFrame(
                    seq: f.seq,
                    payload: f.payload,
                    isAck: f.isAck,
                    isError: f.isError),
                raw),
            onError: (kind, raw, seq) =>
                onError(WSFrameKind.values[kind.index], raw, seq));
}
