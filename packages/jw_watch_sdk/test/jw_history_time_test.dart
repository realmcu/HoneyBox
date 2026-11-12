import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/history/jw_history_sync.dart';
import 'package:jw_watch_sdk/src/storage/jw_database.dart';

void main() {
  test('spo2 decode uses device-local wall time', () {
    // User log sample: 35 68 00 F1 0B 63 63 61
    final records = decodeJWHistoryFieldForTest(0x2c, Uint8List.fromList([
      0x35,
      0x68,
      0x00,
      0xf1,
      0x0b,
      0x63,
      0x63,
      0x61,
    ]));
    expect(records.length, 1);
    final row = records.single as JWBloodOxygen;
    expect(row.time.year, 2026);
    expect(row.time.month, 11);
    expect(row.time.day, 8);
    expect(row.time.hour, 4);
    expect(row.time.minute, 1);
    expect(row.time.isUtc, isFalse);
    expect(row.value, 99);
  });

  test('local day query does not pull previous calendar evening', () async {
    final store =
        JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));
    final scope =
        JWHistoryScope(userId: 'u' * 32, deviceMac: 'AA:BB:CC:DD:EE:FF');
    addTearDown(store.dispose);

    await store.writeBloodOxygens(scope, [
      JWBloodOxygen(time: DateTime(2026, 11, 10, 9, 30), value: 98),
      JWBloodOxygen(time: DateTime(2026, 11, 10, 20, 0), value: 97),
      JWBloodOxygen(time: DateTime(2026, 11, 9, 20, 0), value: 96),
    ]);

    final rows = await store.queryBloodOxygens(JWHistoryQuery(
      scope: scope,
      from: DateTime(2026, 11, 10),
      to: DateTime(2026, 11, 10, 23, 59, 59, 999),
    ));
    expect(rows.length, 2);
    expect(rows.map((r) => r.time.hour).toList()..sort(), [9, 20]);
    expect(rows.every((r) => r.time.day == 10), isTrue);
  });
}
