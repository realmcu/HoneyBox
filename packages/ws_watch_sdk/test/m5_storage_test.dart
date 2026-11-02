import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';
import 'package:ws_watch_sdk/src/storage/history_store.dart';
import 'package:ws_watch_sdk/src/model/history.dart';

void main() {
  test('schema 1 upgrades, retains identity/info, and creates indexes',
      () async {
    final snapshot = jsonDecode(
        await File('test/drift_schemas/drift_schema_v1.json')
            .readAsString()) as Map;
    final sql = snapshot['fixed_sql'][0]['sql'][0]['sql'] as String;
    final db = WSDatabase(NativeDatabase.memory(setup: (db) {
      db.execute(sql);
      db.execute(
          "INSERT INTO devices (device_id,user_id,firmware_version,device_info_raw) VALUES ('d','old-user','1.2',X'010203')");
      db.execute('PRAGMA user_version=1');
    }));
    final store = WSDriftDeviceStore(db);
    try {
      expect(await store.defaultUserId('d'), 'old-user');
      final row = await db.select(db.devices).getSingle();
      expect(row.firmwareVersion, '1.2');
      expect(row.deviceInfoRaw, [1, 2, 3]);
      expect(await store.querySteps(WSRecordQuery(deviceId: 'd')), isEmpty);
      expect(await store.queryHeartRate(WSRecordQuery(deviceId: 'd')), isEmpty);
      expect(await store.querySyncLogs('d', null, 20), isEmpty);
      final indexes = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();
      expect(
          indexes.map((r) => r.read<String>('name')),
          containsAll([
            'step_device_time',
            'heart_device_time',
            'sync_device_started'
          ]));
      expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          2);
    } finally {
      await store.close();
    }
  });
  test('durable dedup, latest valid values, scope/time filtering and deletion',
      () async {
    final dir = await Directory.systemTemp.createTemp('ws-m5-');
    final file = File('${dir.path}/records.db');
    WSDriftDeviceStore open() =>
        WSDriftDeviceStore(WSDatabase(NativeDatabase(file)));
    var store = open();
    final t = WSWallClock(year: 2026, month: 10, day: 12, hour: 8, minute: 30);
    WSHistoryScope scope(String d, String u) => WSHistoryScope(
        deviceId: d, userId: u, syncedAt: DateTime(2026), tzOffsetMinutes: 480);
    WSStepSample sample({int? steps = 1200, int mode = 0}) => WSStepSample(
        recordTime: t,
        raw: [mode],
        steps: steps,
        mode: mode,
        bucketMinutes: 15,
        averageHeartRate: null,
        flags: 0,
        caloriesDeciKcal: 456,
        distanceMeters: 850);
    try {
      final first = await store.writeHistory(scope('d', 'u'), [sample()]);
      expect(first.inserted, 1);
      final repeat = await store
          .writeHistory(scope('d', 'u'), [sample(steps: null, mode: 254)]);
      expect(repeat.duplicates, 1);
      await store.writeHistory(scope('other', 'u'), [sample()]);
      await store.writeHistory(scope('d', 'v'), [sample(steps: 300)]);
      await store.writeHistory(scope('d', 'u'), [
        WSHeartRateSample(recordTime: t, raw: [72], bpm: 72)
      ]);
      await store.writeHistory(scope('d', 'u'), [
        WSHeartRateSample(recordTime: t, raw: [255], bpm: null)
      ]);
      await store.close();
      store = open();
      final q = WSRecordQuery(
          deviceId: 'd',
          userId: 'u',
          from: t,
          to: WSWallClock.fromSeconds(t.seconds + 1));
      final row = (await store.querySteps(q)).single;
      expect(row.steps, 1200);
      expect(row.mode, 254);
      expect(row.raw, [254]);
      expect(row.tzOffsetMinutes, 480);
      expect((await store.queryHeartRate(q)).single.bpm, 72);
      expect(
          await store.querySteps(WSRecordQuery(deviceId: 'd')), hasLength(2));
      expect(
          await store.querySteps(WSRecordQuery(deviceId: 'd', to: t)), isEmpty);
      expect(await store.deleteSteps(q), 1);
      expect(
          (await store.querySteps(WSRecordQuery(deviceId: 'd'))).single.userId,
          'v');
      expect(await store.querySteps(WSRecordQuery(deviceId: 'other')),
          hasLength(1));
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });
}
