import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import '../../helpers/jw_fixture.dart';

void main() {
  final golden = jwHex('ab00000de856000102003700084dd17dfce34ad83d');
  test('real capability frame requires all fragments and validates ARC', () {
    final d = JwFrameDecoder();
    for (final byte in golden.take(golden.length - 1)) {
      expect(d.add(Uint8List.fromList([byte])), isEmpty);
    }
    final f = d.add(Uint8List.fromList([golden.last])).single;
    expect(f.seq, 1);
    expect(f.ack, isFalse);
    expect(JwCodec.decodeL2(f.payload).fields.single.value,
        jwHex('4dd17dfce34ad83d'));
    expect(JwCodec.crc16Arc(Uint8List.fromList('123456789'.codeUnits)), 0xbb3d);
  });
  test('encodes real query and ACK exactly', () {
    expect(
        JwCodec.encode(
            seq: 1,
            payload: JwCodec.encodeL2(2, [JwField(0x36, Uint8List(0))])),
        jwHex('ab000005ce9900010200360000'));
    expect(JwCodec.encode(seq: 1, payload: Uint8List(0), ack: true),
        jwHex('ab10000000000001'));
    expect(
        JwFrameDecoder().add(jwHex('ab50000000000001')).single.noAck, isTrue);
  });
  test('CRC corruption and noise never hide the next complete frame', () {
    final bad = Uint8List.fromList(golden)..[10] ^= 1;
    final d = JwFrameDecoder();
    final got = d.add(Uint8List.fromList([0, 1, 2, ...bad, ...golden]));
    expect(got.length, 1);
    expect(got.single.seq, 1);
  });
  test('rejects oversized lengths and consumes multiple duplicate frames', () {
    final d = JwFrameDecoder();
    expect(
        d
            .add(Uint8List.fromList(
                [...jwHex('ab00ffff00000001'), ...golden, ...golden]))
            .length,
        2);
    expect(d.add(Uint8List.fromList(List.filled(100000, 0))), isEmpty);
  });
  test('noAck and multiple unknown keys survive framing', () {
    final p = JwCodec.encodeL2(
        6, [JwField(0xfe, jwHex('01')), JwField(0xfa, jwHex('0203'))]);
    final f = JwFrameDecoder()
        .add(JwCodec.encode(seq: 65535, payload: p, noAck: true))
        .single;
    expect(f.noAck, isTrue);
    expect(f.seq, 65535);
    expect(JwCodec.decodeL2(f.payload).fields.map((f) => f.key), [0xfe, 0xfa]);
    expect(JwCodec.decodeL2(JwCodec.encodeL2(2, [])).fields, isEmpty);
  });
  test('enforces frame/value bounds and malformed L2 rejection', () {
    final p = JwCodec.encodeL2(2, [JwField(0x70, Uint8List(231))]);
    expect(JwCodec.encode(seq: 1, payload: p).length, 244);
    expect(() => JwCodec.encodeL2(2, [JwField(0x70, Uint8List(232))]),
        throwsRangeError);
    expect(() => JwCodec.encode(seq: 1, payload: Uint8List(237)),
        throwsRangeError);
    expect(() => JwCodec.encode(seq: 65536, payload: p), throwsRangeError);
    for (final bad in ['02', '020036', '020036000201']) {
      expect(() => JwCodec.decodeL2(jwHex(bad)), throwsFormatException);
    }
  });
  test('clear discards old partial frames and payloads do not alias input', () {
    final d = JwFrameDecoder();
    d.add(golden.sublist(0, 10));
    d.clear();
    expect(d.add(golden).single.seq, 1);
    final source = jwHex('0102');
    final field = JwField(1, source);
    source[0] = 9;
    expect(field.value, [1, 2]);
  });
}
