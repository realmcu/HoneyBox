import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/history/jw_history_decoder.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';

Uint8List hexBytes(String value) => Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16)
    ]);

void main() {
  final fixture = jsonDecode(
          File('test/fixtures/jw_history_vectors_v1.json').readAsStringSync())
      as Map<String, dynamic>;
  for (final v in fixture['vectors'] as List) {
    test('firmware vector ${v['name']} preserves literal fields and units', () {
      final record = decodeJwHistoryField(
              'jw:test', v['key'] as int, hexBytes(v['payloadHex'] as String),
              batchId: 'batch1', firstSeenOrdinal: 10)
          .single;
      for (final e in (v['expected'] as Map).entries) {
        expect(record.values[e.key], e.value, reason: '${v['name']}: ${e.key}');
      }
      expect(record.rawHex, v['payloadHex']);
      expect(record.deviceKey, 'jw:test');
    });
  }
  for (final v in fixture['negativeCases'] as List) {
    test('${v['name']} rejects invalid payload without fabricated data', () {
      expect(
          () => decodeJwHistoryField(
              'jw:test', v['key'] as int, hexBytes(v['payloadHex'] as String),
              batchId: 'b', firstSeenOrdinal: 0),
          throwsFormatException);
    });
  }
  test('repeat rounds keep record identity but changed raw keeps revision', () {
    final raw = hexBytes('ea070a04000352fe030937002f00a40103000000');
    final first = decodeJwHistoryField('jw:test', 100, raw,
            batchId: 'b1', firstSeenOrdinal: 0)
        .single;
    final repeat = decodeJwHistoryField('jw:test', 100, raw,
            batchId: 'b2', firstSeenOrdinal: 10)
        .single;
    raw[6] = 83;
    final changed = decodeJwHistoryField('jw:test', 100, raw,
            batchId: 'b2', firstSeenOrdinal: 11)
        .single;
    expect(first.recordId, repeat.recordId);
    expect(first.recordId, isNot(changed.recordId));
    expect(first.sourceIdentity, changed.sourceIdentity);
    expect(first.rawHex, 'ea070a04000352fe030937002f00a40103000000');
    expect(() => first.values['score'] = 0, throwsUnsupportedError);
    expect(first.toJson()['type'], JwHistoryType.readiness.name);
  });
  test('multiple stored slots decode separately with individual headers', () {
    final raw = hexBytes('35440001054600023544000105470001');
    final records = decodeJwHistoryField('jw:test', 3, raw,
        batchId: 'b', firstSeenOrdinal: 4);
    expect(records.map((r) => r.values['minute']), [1350, 1351]);
    expect(records.map((r) => r.firstSeenOrdinal), [4, 5]);
  });
  test('reserved count, zero date and invalid minute are rejected', () {
    for (final h in [
      '3544000205460002',
      '0000000105460002',
      '3544000105a00002'
    ]) {
      expect(
          () => decodeJwHistoryField('jw:test', 3, hexBytes(h),
              batchId: 'b', firstSeenOrdinal: 0),
          throwsFormatException);
    }
  });
  test('stress zero is absent and remains device-calendar epoch', () {
    final record = decodeJwHistoryField(
            'jw:test', 0x5b, hexBytes('a4e3543200000000'),
            batchId: 'b', firstSeenOrdinal: 0)
        .single;
    expect(record.values['value'], isNull);
    expect(record.sourceTimeBasis, 'deviceLocalEpoch2000');
    expect(record.values['localEpochSeconds'], 844424100);
  });
}
