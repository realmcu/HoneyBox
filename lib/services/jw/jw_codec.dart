import 'dart:typed_data';
import 'package:watch_frame_channel/watch_frame_channel.dart';

class JwFrame {
  final int seq;
  final bool ack;
  final bool noAck;
  final bool error;
  final Uint8List payload;
  JwFrame(this.seq, this.ack, this.noAck, Uint8List payload,
      {this.error = false})
      : payload = Uint8List.fromList(payload).asUnmodifiableView();
}

class JwField {
  final int key;
  final Uint8List value;
  JwField(this.key, Uint8List value)
      : value = Uint8List.fromList(value).asUnmodifiableView();
}

class JwMessage {
  final int command;
  final List<JwField> fields;
  JwMessage(this.command, List<JwField> fields)
      : fields = List.unmodifiable(fields);
}

/// JW is deliberately separate from HoneyBox's legacy L1Engine.
abstract final class JwCodec {
  static const maxFrameLength = 244;
  static const maxValueLength = 231;
  static int crc16Arc(Uint8List bytes) => watchCrc16(bytes);

  static void _u8(int n) {
    RangeError.checkValueInInterval(n, 0, 255);
  }

  static Uint8List encode(
      {required int seq,
      required Uint8List payload,
      bool ack = false,
      bool noAck = false}) {
    RangeError.checkValueInInterval(seq, 0, 65535);
    if (payload.length > maxFrameLength - 8) {
      throw RangeError('JW frame length');
    }
    if (ack && payload.isNotEmpty) throw ArgumentError('ACK has no payload');
    return WatchFrame(seq: seq, payload: payload, isAck: ack, noAck: noAck)
        .encode();
  }

  static Uint8List encodeL2(int command, List<JwField> fields) {
    _u8(command);
    final bytes = <int>[command, 0];
    for (final f in fields) {
      _u8(f.key);
      if (f.value.length > maxValueLength) throw RangeError('JW value length');
      bytes.addAll(
          [f.key, f.value.length >> 8, f.value.length & 255, ...f.value]);
    }
    if (bytes.length > maxFrameLength - 8) throw RangeError('JW L2 length');
    return Uint8List.fromList(bytes);
  }

  static JwMessage decodeL2(Uint8List bytes) {
    if (bytes.length < 2 || bytes[1] != 0) {
      throw const FormatException('JW L2 header');
    }
    final fields = <JwField>[];
    var offset = 2;
    while (offset < bytes.length) {
      if (offset + 3 > bytes.length) {
        throw const FormatException('JW key header');
      }
      final key = bytes[offset];
      final n = ((bytes[offset + 1] & 1) << 8) | bytes[offset + 2];
      offset += 3;
      if (n > maxValueLength || offset + n > bytes.length) {
        throw const FormatException('JW key length');
      }
      fields.add(JwField(key, bytes.sublist(offset, offset + n)));
      offset += n;
    }
    return JwMessage(bytes[0], fields);
  }
}

/// Compatibility facade over the common incremental L0/L1 decoder.
class JwFrameDecoder {
  JwFrameDecoder() {
    _assembler = WatchFrameAssembler(
        timeout: null,
        maxPayloadLength: 236,
        profile: WatchFrameProfile.jw,
        onFrame: (f, _) => _frames
            .add(JwFrame(f.seq, f.isAck, f.noAck, f.payload, error: f.isError)),
        onError: (_, __, ___) {});
  }
  late final WatchFrameAssembler _assembler;
  final _frames = <JwFrame>[];
  void clear() {
    _assembler.clear();
    _frames.clear();
  }

  List<JwFrame> add(Uint8List bytes) {
    _assembler.add(bytes);
    final result = List<JwFrame>.of(_frames);
    _frames.clear();
    return result;
  }
}
