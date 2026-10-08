import 'dart:async';
import 'dart:typed_data';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_transport.dart';
import 'jw_fixture.dart';

class FakeJwTransport implements JwTransport {
  @override
  final int mtu;
  final rx = StreamController<Uint8List>.broadcast(sync: true);
  final down = StreamController<void>.broadcast(sync: true);
  final writes = <Uint8List>[];
  final readValues = <String, Uint8List>{};
  bool failSubscribe = false;
  bool failWrite = false;
  bool failRead = false;
  bool subscribed = false;
  bool connected = true;
  Completer<void>? subscribeGate;
  void Function(Uint8List)? onWrite;
  int _seq = 0;
  FakeJwTransport({this.mtu = 247});
  @override
  Stream<Uint8List> get notifications => rx.stream;
  @override
  Stream<void> get disconnected => down.stream;
  @override
  Future<void> subscribe() async {
    if (subscribeGate != null) await subscribeGate!.future;
    if (failSubscribe) throw StateError('CCCD failed');
    if (!connected) throw StateError('link closed');
    subscribed = true;
  }

  @override
  Future<void> write(Uint8List frame, {required bool withResponse}) async {
    if (!connected || !subscribed || failWrite) {
      throw StateError('write failed');
    }
    if (!withResponse) throw StateError('response required');
    writes.add(Uint8List.fromList(frame));
    onWrite?.call(frame);
  }

  @override
  Future<Uint8List?> read(String uuid) async {
    if (failRead) throw StateError('GATT read failed');
    return readValues[uuid];
  }

  @override
  Future<void> disconnect() async {
    if (connected) emitDisconnect();
  }

  void emitDisconnect() {
    connected = false;
    subscribed = false;
    down.add(null);
  }

  void emitHex(String hex) => rx.add(jwHex(hex));
  void emitMessage(int command, int key, Uint8List value,
          {bool noAck = false}) =>
      rx.add(JwCodec.encode(
          seq: ++_seq,
          payload: JwCodec.encodeL2(command, [JwField(key, value)]),
          noAck: noAck));
  void emitAck(int seq) =>
      rx.add(JwCodec.encode(seq: seq, payload: Uint8List(0), ack: true));
  List<JwFrame> get sent =>
      writes.map((w) => JwFrameDecoder().add(w).single).toList();
  Future<void> dispose() async {
    await rx.close();
    await down.close();
  }
}
