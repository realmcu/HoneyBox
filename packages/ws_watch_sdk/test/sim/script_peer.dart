import 'dart:typed_data';
import 'package:ws_watch_sdk/src/link/frame.dart';
import 'package:ws_watch_sdk/src/link/frame_assembler.dart';
import 'package:ws_watch_sdk/src/protocol/address.dart';
import 'package:ws_watch_sdk/src/protocol/message.dart';
import 'test_transport.dart';

class ScriptPeer {
  ScriptPeer(this.transport) {
    assembler = WSFrameAssembler(
        timeout: const Duration(seconds: 1),
        maxPayloadLength: 65535,
        onFrame: (frame, _) {
          if (!frame.isAck) {
            commands.add(frame);
            onData?.call(frame);
          }
        },
        onError: (_, __, ___) => throw StateError('bad host frame'));
    transport.onWrite = (bytes) async {
      assembler.add(bytes);
    };
  }
  final TestTransport transport;
  late final WSFrameAssembler assembler;
  final commands = <WSFrame>[];
  void Function(WSFrame)? onData;
  int sequence = 200;
  void ack(WSFrame f) =>
      transport.receive(WSFrame(seq: f.seq, isAck: true).encode());
  void language(int opcode, List<int> data, {int version = 0}) => payload(
      WSMessage(
              WSProtocolAddress(
                  cmd: 2,
                  version: version,
                  key: 3,
                  settingOpcode: opcode,
                  direction: WSWireDirection.deviceToPhone),
              data)
          .encode());
  void payload(Uint8List data) =>
      transport.receive(WSFrame(seq: sequence++, payload: data).encode());
  void dispose() => assembler.dispose();
}
