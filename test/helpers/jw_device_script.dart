import 'dart:convert';
import 'dart:typed_data';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'fake_jw_transport.dart';
import 'jw_fixture.dart';

void installJwDeviceScript(FakeJwTransport t,
    {int loginResult = 0,
    int bindResult = 0,
    int language = 0,
    int? readbackLanguage,
    String functions = '4dd17dfce34ad83d',
    bool earlySample = false}) {
  for (final pair in {
    '2a00': 'S200',
    '2a25': 'TEST-SERIAL',
    '2a26': 'T005',
    '2a27': 'H001'
  }.entries) {
    t.readValues[pair.key] = Uint8List.fromList(utf8.encode(pair.value));
  }
  t.readValues['2a19'] = Uint8List.fromList([70]);
  t.onWrite = (bytes) {
    final frame = JwFrameDecoder().add(bytes).single;
    if (frame.ack) return;
    final m = JwCodec.decodeL2(frame.payload);
    final f = m.fields.single;
    t.emitAck(frame.seq);
    if (m.command == 2 && f.key == 0x36) {
      t.emitMessage(2, 0x37, jwHex(functions));
    } else if (m.command == 6 && f.key == 0x3d) {
      t.emitMessage(6, 0x3e, jwHex('03'));
    } else if (m.command == 2 && f.key == 0x4f) {
      t.emitMessage(
          2, 0x50, Uint8List.fromList([readbackLanguage ?? language]));
    } else if (m.command == 2 && f.key == 0x4e) {
      language = f.value.single;
    } else if (m.command == 3 && f.key == 3) {
      t.emitMessage(3, 4, Uint8List.fromList([loginResult]));
    } else if (m.command == 3 && f.key == 1) {
      t.emitMessage(3, 2, Uint8List.fromList([bindResult]));
    } else if (m.command == 5 && f.key == 0x19) {
      if (earlySample && f.value.single == 1) {
        t.emitMessage(5, 0x0f, jwHex('3543000104881e48'));
      }
      t.emitMessage(5, 0x1a, f.value);
    }
  };
}
