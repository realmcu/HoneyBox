import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';

Uint8List hexBytes(String text) => Uint8List.fromList([
      for (var i = 0; i < text.length; i += 2)
        int.parse(text.substring(i, i + 2), radix: 16),
    ]);

void main() {
  final fixture = jsonDecode(
      File('test/fixtures/jw_configuration_vectors_v1.json')
          .readAsStringSync()) as Map<String, dynamic>;
  final domains = fixture['domains'] as List<dynamic>;

  test('configuration fixture covers exactly eight unique firmware domains',
      () {
    expect(fixture['kind'], 'offline_configuration_contracts_not_board_data');
    expect(domains.map((e) => e['domain']).toSet(), {
      'hourSystem',
      'distanceUnit',
      'screenLightTime',
      'screenBrightness',
      'heartRateAuto',
      'bloodOxygenAuto',
      'bloodPressureAuto',
      'temperatureConfig',
    });
    expect(domains, hasLength(8));
    expect(fixture['boundaries'], hasLength(16));
    expect(fixture['rejectedReadValues'], hasLength(12));
  });

  for (final domain in domains) {
    for (final packet in domain['packets'] as List<dynamic>) {
      final label = '${domain['domain']}.${packet['role']}';
      final l2 = hexBytes(packet['l2'] as String);
      final l1 = hexBytes(packet['l1'] as String);
      final seq = packet['seq'] as int;
      test('$label external L1/L2 golden bytes and fragmentation', () {
        final message = JwCodec.decodeL2(l2);
        expect(message.command, packet['command']);
        expect(message.fields, hasLength(1));
        expect(message.fields.single.key, packet['key']);
        expect(
            message.fields.single.value, hexBytes(packet['value'] as String));
        expect(JwCodec.encodeL2(message.command, message.fields), l2);
        expect(JwCodec.encode(seq: seq, payload: l2), l1);
        for (var split = 1; split < l1.length; split++) {
          final decoder = JwFrameDecoder();
          expect(decoder.add(Uint8List.sublistView(l1, 0, split)), isEmpty);
          final frames = decoder.add(Uint8List.sublistView(l1, split));
          expect(frames, hasLength(1));
          expect(frames.single.seq, seq);
          expect(frames.single.payload, l2);
        }
        final decoder = JwFrameDecoder();
        final frames = [
          for (final byte in l1) ...decoder.add(Uint8List.fromList([byte]))
        ];
        expect(frames, hasLength(1));
        expect(frames.single.payload, l2);
      });
      test('$label corrupted CRC rejected then clean frame recovered', () {
        final corrupted = Uint8List.fromList(l1)..[4] ^= 0x80;
        final decoder = JwFrameDecoder();
        expect(decoder.add(corrupted), isEmpty);
        final recovered = decoder.add(l1);
        expect(recovered, hasLength(1));
        expect(recovered.single.seq, seq);
        expect(recovered.single.payload, l2);
      });
    }
  }
}
