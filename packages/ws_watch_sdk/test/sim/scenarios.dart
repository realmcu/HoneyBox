import 'dart:math';
import 'dart:typed_data';
import 'package:ws_watch_sdk/src/link/frame.dart';
import 'package:ws_watch_sdk/src/link/frame_assembler.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_session.dart';

/// Device-side wire fault injection. These controls are never exported by SDK.
class SimFaultScript {
  SimFaultScript(this.transport) {
    _assembler = WSFrameAssembler(
        timeout: const Duration(seconds: 1),
        maxPayloadLength: 65535,
        onFrame: (frame, raw) {
          if (frame.isAck && dropAcks > 0) {
            dropAcks--;
            return;
          }
          if (frame.isAck && errorAcks > 0) {
            errorAcks--;
            raw = WSFrame(seq: frame.seq, isAck: true, isError: true).encode();
          }
          if (disconnectOnFrame) {
            transport.disconnect();
            return;
          }
          for (var offset = 0;
              offset < raw.length;
              offset += transport.maxWriteLength) {
            transport.deliver(Uint8List.fromList(raw.sublist(
                offset, min(offset + transport.maxWriteLength, raw.length))));
          }
        },
        onError: (_, __, ___) => throw StateError('invalid device frame'));
    transport.interceptWrite = (chunk) async {
      _assembler.add(chunk);
    };
  }
  final SimWatchSession transport;
  late final WSFrameAssembler _assembler;
  int dropAcks = 0, errorAcks = 0;
  bool disconnectOnFrame = false;
  void dispose() {
    transport.interceptWrite = null;
    _assembler.dispose();
  }
}
