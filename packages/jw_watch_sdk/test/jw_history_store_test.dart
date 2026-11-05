import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/storage/jw_database.dart';

void main() {
  final scope =
      JWHistoryScope(userId: 'a' * 32, deviceMac: 'AA:BB:CC:DD:EE:FF');
  final otherScope =
      JWHistoryScope(userId: 'b' * 32, deviceMac: '11:22:33:44:55:66');

  JWHistoryStore memoryStore() =>
      JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));

  test('heart records deduplicate by user, MAC, and time', () async {
    final store = memoryStore();
    final time = DateTime.utc(2026, 11, 5, 8, 30);
    await store
        .writeHeartRates(scope, [JWHeartRate(time: time, heartRate: 72)]);
    await store
        .writeHeartRates(scope, [JWHeartRate(time: time, heartRate: 75)]);
    await store
        .writeHeartRates(otherScope, [JWHeartRate(time: time, heartRate: 80)]);

    final own = await store.queryHeartRates(JWHistoryQuery(scope: scope));
    final other =
        await store.queryHeartRates(JWHistoryQuery(scope: otherScope));
    expect(own.single.heartRate, 75);
    expect(other.single.heartRate, 80);
    await store.dispose();
  });

  test('time range orders, pages, and deletes heart records', () async {
    final store = memoryStore();
    final start = DateTime.utc(2026, 11, 5, 8);
    await store.writeHeartRates(scope, [
      JWHeartRate(time: start, heartRate: 60),
      JWHeartRate(time: start.add(const Duration(minutes: 1)), heartRate: 61),
      JWHeartRate(time: start.add(const Duration(minutes: 2)), heartRate: 62),
    ]);
    final page = await store.queryHeartRates(JWHistoryQuery(
        scope: scope,
        from: start.add(const Duration(milliseconds: 1)),
        limit: 1));
    expect(page.single.heartRate, 61);
    final deleted = await store.deleteHeartRates(JWHistoryQuery(
        scope: scope, to: start.add(const Duration(minutes: 1))));
    expect(deleted, 2);
    expect(
        (await store.queryHeartRates(JWHistoryQuery(scope: scope)))
            .single
            .heartRate,
        62);
    await store.dispose();
  });

  test('incoming decoded field is committed atomically', () async {
    final store = memoryStore();
    final time = DateTime.utc(2026, 11, 5, 10);
    await expectLater(
        store.writeRecords(scope, [
          JWActivity(
              time: time,
              steps: 12,
              distance: 3,
              energy: 4,
              activeTime: 1,
              mode: 0),
          // This makes the field transaction fail after the activity insert
          // would otherwise have been issued.
          JWHeartRate(time: time, heartRate: 0),
        ]),
        throwsArgumentError);
    expect(await store.queryActivities(JWHistoryQuery(scope: scope)), isEmpty);
    await store.dispose();
  });

  test('disk database remains queryable after reopening', () async {
    final root = await Directory.systemTemp.createTemp('jw-history-db-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}${Platform.pathSeparator}jw_watch.db');
    final time = DateTime.utc(2026, 11, 5, 9);
    final first = JWHistoryStore.forDatabase(JWDatabase(NativeDatabase(file)));
    await first
        .writeHeartRates(scope, [JWHeartRate(time: time, heartRate: 71)]);
    await first.dispose();

    final second = JWHistoryStore.forDatabase(JWDatabase(NativeDatabase(file)));
    final records = await second.queryHeartRates(JWHistoryQuery(scope: scope));
    expect(records.single.heartRate, 71);
    expect(records.single.time, time);
    await second.dispose();
  });

  test('schema contains only the final JW health tables', () async {
    final database = JWDatabase(NativeDatabase.memory());
    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
        rows.map((row) => row.read<String>('name')).toSet(),
        containsAll({
          'jw_activity',
          'jw_sleep',
          'jw_heart_rate',
          'jw_blood_pressure',
          'jw_blood_oxygen',
          'jw_hrv',
          'jw_pressure',
          'jw_temperature',
          'jw_blood_glucose',
          'jw_sport',
        }));
    await database.close();
  });

  test('history scope and time query reject ambiguous inputs', () {
    expect(() => JWHistoryScope(userId: ' ', deviceMac: 'AA'),
        throwsArgumentError);
    final valid = JWHistoryScope(userId: 'user', deviceMac: 'AA');
    expect(() => JWHistoryQuery(scope: valid, limit: 0), throwsArgumentError);
    expect(
        () => JWHistoryQuery(
            scope: valid,
            from: DateTime.utc(2026, 11, 6),
            to: DateTime.utc(2026, 11, 5)),
        throwsArgumentError);
  });
}
