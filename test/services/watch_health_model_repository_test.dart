import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_health_protocol.dart';
import 'package:honeybox/services/watch_health_repository.dart';

void main() {
  test('runs history sync, acknowledges it, then reads today data', () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final sent = <Uint8List>[];
    final repository = WatchHealthBleRepository(
      commandAvailable: () => true,
      sendCommand: (frame) {
        sent.add(frame);
        return sent.length;
      },
      notifications: notifications.stream,
      clock: () => DateTime(2026, 11, 10, 16),
    );

    final future = repository.sync('watch-01');
    expect(sent, [WatchHealthProtocol.buildRequestAll()]);

    notifications.add(_frame([
      (WatchHealthKey.syncStart, Uint8List.fromList([0x01, 0x00, 0x01])),
    ]));
    notifications.add(_frame([
      (WatchHealthKey.activityData, _sportPage()),
    ]));
    notifications.add(_frame([
      (WatchHealthKey.syncEnd, Uint8List.fromList([0, 0, 0, 0, 1])),
    ]));

    await Future<void>.delayed(Duration.zero);
    expect(sent, [
      WatchHealthProtocol.buildRequestAll(),
      WatchHealthProtocol.buildSyncAck(),
      WatchHealthProtocol.buildTodayRequest(),
    ]);

    notifications.add(_frame([
      (WatchHealthKey.todayData, _today()),
    ]));

    final snapshot = await future;
    expect(snapshot.sportRecords, hasLength(1));
    expect(snapshot.sportRecords.single.steps, 100);
    expect(snapshot.steps, 1234);
    expect(snapshot.distanceMeters, 800);
    expect(snapshot.caloriesKcal, 12.3);
    expect(snapshot.latestHeartRate, 72);
  });

  test('ignores unrelated frames while waiting for 0x05 data', () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final repository = WatchHealthBleRepository(
      commandAvailable: () => true,
      sendCommand: (_) => 1,
      notifications: notifications.stream,
      timeout: const Duration(milliseconds: 20),
    );

    final future = repository.sync('watch-01');
    notifications.add(Uint8List.fromList([0x12, 0x00, 0x02, 0x00, 0x01, 1]));
    expect(future, throwsA(isA<TimeoutException>()));
  });

  test('fails without sending when command channel is unavailable', () async {
    final repository = WatchHealthBleRepository(
      commandAvailable: () => false,
      sendCommand: (_) => null,
      notifications: const Stream.empty(),
    );

    expect(
      () => repository.sync('watch-01'),
      throwsA(isA<WatchHealthSyncException>()),
    );
  });
}

Uint8List _frame(List<(int, Uint8List)> entries) {
  final bytes = <int>[0x05, 0x10];
  for (final (key, value) in entries) {
    bytes.addAll([key, value.length >> 8, value.length & 0xFF, ...value]);
  }
  return Uint8List.fromList(bytes);
}

Uint8List _sportPage() => Uint8List.fromList([
      18,
      0,
      1,
      ..._u32(1700000000),
      0,
      100,
      0,
      20,
      0,
      30,
      70,
      15,
      0,
      1,
      0,
      0,
      0,
      0,
    ]);

Uint8List _today() => Uint8List.fromList([
      ..._u32(1700000000),
      ..._u32(1234),
      ..._u32(800),
      ..._u32(123),
      0,
      42,
      72,
      ..._u32(1699999999),
    ]);

List<int> _u32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
