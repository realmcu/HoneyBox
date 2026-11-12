import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_health_store.dart';

import '../helpers/watch_health_fixture.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('watch-health-store-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('round-trips a complete snapshot', () async {
    final store = WatchHealthFileStore(root: root);
    final source = watchHealthFixture();

    await store.save('watch-01', source);
    final restored = await store.load('watch-01');

    expect(restored, isNotNull);
    expect(restored!.syncedAt, source.syncedAt);
    expect(restored.steps, source.steps);
    expect(restored.distanceMeters, source.distanceMeters);
    expect(restored.caloriesKcal, source.caloriesKcal);
    expect(restored.latestHeartRate, source.latestHeartRate);
    expect(restored.sportRecords, hasLength(source.sportRecords.length));
    expect(restored.sportRecords.first.timestamp,
        source.sportRecords.first.timestamp);
    expect(restored.sleepRecords, hasLength(source.sleepRecords.length));
  });

  test('keeps device snapshots isolated', () async {
    final store = WatchHealthFileStore(root: root);
    await store.save('watch-01', watchHealthFixture());

    expect(await store.load('watch-02'), isNull);
    expect(await store.load('watch-01'), isNotNull);
  });

  test('ignores a corrupt snapshot instead of breaking startup', () async {
    final store = WatchHealthFileStore(root: root);
    await store.save('watch-01', watchHealthFixture());
    final directory = Directory('${root.path}/watch_health');
    final file =
        (await directory.list().where((entry) => entry is File).toList()).single
            as File;
    await file.writeAsString('{not-json');

    expect(await store.load('watch-01'), isNull);
  });
}
