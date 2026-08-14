import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_health_protocol.dart';
import 'package:honeybox/services/watch_health_repository.dart';

void main() {
  test('requests and aggregates health frames until sync end', () async {
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
      clock: () => DateTime(2026, 7, 30, 12),
    );

    final future = repository.sync('watch-01');
    expect(sent, [WatchHealthProtocol.buildRequest()]);

    notifications.add(_frame([
      (WatchHealthKey.syncStart, _dataType()),
      (WatchHealthKey.sportData, _sportPage(steps: 600)),
      (WatchHealthKey.more, _dataType()),
    ]));
    await Future<void>.delayed(Duration.zero);
    // The follow-up request must repeat the session's data type.
    expect(sent, hasLength(2));
    expect(sent.last, WatchHealthProtocol.buildRequest());

    notifications.add(_frame([
      (WatchHealthKey.sportData, _sportPage(steps: 250)),
      (WatchHealthKey.syncEnd, _dataType()),
    ]));
    final snapshot = await future;

    expect(snapshot.sportRecords.map((record) => record.steps), [600, 250]);
    expect(snapshot.syncedAt, DateTime(2026, 7, 30, 12));
  });

  test('completes with no records when the device history is empty', () async {
    // Spec: an empty DB goes straight from syncStart to syncEnd, with no
    // count=0 data page in between.
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final repository = WatchHealthBleRepository(
      commandAvailable: () => true,
      sendCommand: (_) => 1,
      notifications: notifications.stream,
      clock: () => DateTime(2026, 7, 30, 12),
    );

    final future = repository.sync('watch-01');
    notifications.add(_frame([
      (WatchHealthKey.syncStart, _dataType()),
      (WatchHealthKey.syncEnd, _dataType()),
    ]));

    final snapshot = await future;
    expect(snapshot.sportRecords, isEmpty);
    expect(snapshot.sleepRecords, isEmpty);
  });

  test('ignores markers belonging to another data type', () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final repository = WatchHealthBleRepository(
      commandAvailable: () => true,
      sendCommand: (_) => 1,
      notifications: notifications.stream,
      timeout: const Duration(milliseconds: 20),
    );

    final future = repository.sync('watch-01');
    // A sleep-typed syncEnd must not finish our activity session.
    notifications.add(_frame([
      (WatchHealthKey.syncStart, _dataType(WatchHealthDataType.activity)),
      (WatchHealthKey.syncEnd, _dataType(WatchHealthDataType.sleep)),
    ]));

    expect(future, throwsA(isA<TimeoutException>()));
  });

  test('ignores version 0 frames entirely', () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final repository = WatchHealthBleRepository(
      commandAvailable: () => true,
      sendCommand: (_) => 1,
      notifications: notifications.stream,
      timeout: const Duration(milliseconds: 20),
    );

    final future = repository.sync('watch-01');
    // Header byte 0x00 = deprecated version 0. Dropped, so the sync times out
    // rather than half-parsing a foreign dialect.
    notifications.add(Uint8List.fromList([0x05, 0x00, 0x07, 0x00, 0x00]));

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

  test('times out when watch does not finish synchronization', () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final repository = WatchHealthBleRepository(
      commandAvailable: () => true,
      sendCommand: (_) => 1,
      notifications: notifications.stream,
      timeout: const Duration(milliseconds: 20),
    );

    final future = repository.sync('watch-01');
    notifications.add(_frame([
      (WatchHealthKey.syncStart, _dataType()),
    ]));

    expect(future, throwsA(isA<TimeoutException>()));
  });

  test('fails the transaction when a health frame is malformed', () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final repository = WatchHealthBleRepository(
      commandAvailable: () => true,
      sendCommand: (_) => 1,
      notifications: notifications.stream,
    );

    final future = repository.sync('watch-01');
    // Record count claims one 18-byte record but only one byte follows.
    notifications.add(Uint8List.fromList([
      0x05,
      0x10,
      WatchHealthKey.sportData,
      0x00,
      0x02,
      0x01,
      0x00,
    ]));

    expect(future, throwsFormatException);
  });
}

Uint8List _frame(List<(int, Uint8List)> entries) {
  final bytes = <int>[0x05, 0x10];
  for (final (key, value) in entries) {
    bytes.addAll([key, value.length >> 8, value.length & 0xFF, ...value]);
  }
  return Uint8List.fromList(bytes);
}

Uint8List _dataType([int type = WatchHealthDataType.activity]) =>
    Uint8List.fromList([type]);

/// A one-record activity page.
Uint8List _sportPage({required int steps}) => Uint8List.fromList([
      0x01, // record count
      0x00, 0x00, 0x03, 0xE8, // timestamp
      (steps >> 8) & 0xFF, steps & 0xFF,
      0x00, 0x00, // distance
      0x00, 0x00, // calories
      0x00, // heart rate
      0x0F, // bucket minutes
      0x00, // mode
      0x00, // flags
      0x00, 0x00, 0x00, 0x00, // reserved
    ]);
