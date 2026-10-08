import 'dart:typed_data';

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
  static int crc16Arc(Uint8List bytes) {
    var crc = 0;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xa001 : crc >> 1;
      }
    }
    return crc & 0xffff;
  }

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
    final crc = crc16Arc(payload);
    return Uint8List.fromList([
      0xab,
      (ack ? 0x10 : 0) | (noAck ? 0x40 : 0),
      payload.length >> 8,
      payload.length & 255,
      crc >> 8,
      crc & 255,
      seq >> 8,
      seq & 255,
      ...payload
    ]);
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

/// Keeps at most one firmware-sized residual frame, even for huge noisy input.
class JwFrameDecoder {
  final _buffer = <int>[];
  void clear() => _buffer.clear();
  List<JwFrame> add(Uint8List bytes) {
    final frames = <JwFrame>[];
    for (final byte in bytes) {
      _buffer.add(byte);
      while (_buffer.isNotEmpty) {
        if (_buffer[0] != 0xab) {
          _buffer.removeAt(0);
          continue;
        }
        if (_buffer.length < 8) break;
        final n = (_buffer[2] << 8) | _buffer[3];
        final ack = (_buffer[1] & 0x10) != 0;
        final crc = (_buffer[4] << 8) | _buffer[5];
        if (n > JwCodec.maxFrameLength - 8 || (ack && (n != 0 || crc != 0))) {
          _buffer.removeAt(0);
          continue;
        }
        if (_buffer.length < 8 + n) break;
        final payload = Uint8List.fromList(_buffer.sublist(8, 8 + n));
        if (JwCodec.crc16Arc(payload) != crc) {
          _buffer.removeAt(0);
          continue;
        }
        frames.add(JwFrame((_buffer[6] << 8) | _buffer[7], ack,
            (_buffer[1] & 0x40) != 0, payload,
            error: (_buffer[1] & 0x20) != 0));
        _buffer.removeRange(0, 8 + n);
      }
    }
    return frames;
  }
}
