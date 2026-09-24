import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_health_repository.dart';
import 'package:honeybox/services/watch_model_protocol.dart';

void main() {
  test('requests and returns the canonical app model activity totals',
      () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final sent = <Uint8List>[];
    final repository = WatchHealthModelRepository(
      commandAvailable: () => true,
      sendCommand: (frame) {
        sent.add(frame);
        return 1;
      },
      notifications: notifications.stream,
      clock: () => DateTime(2026, 9, 24, 12),
    );

    final future = repository.sync('watch-01');
    expect(sent, [WatchModelProtocol.buildGetRequest()]);
    notifications.add(_modelFrame(steps: 1234, distance: 800, calories: 123));

    final snapshot = await future;
    expect(snapshot.steps, 1234);
    expect(snapshot.distanceMeters, 800);
    expect(snapshot.caloriesKcal, 12.3);
  });

  test('ignores unrelated frames while waiting for the model', () async {
    final notifications = StreamController<Uint8List>.broadcast();
    addTearDown(notifications.close);
    final repository = WatchHealthModelRepository(
      commandAvailable: () => true,
      sendCommand: (_) => 1,
      notifications: notifications.stream,
      timeout: const Duration(milliseconds: 20),
    );

    final future = repository.sync('watch-01');
    notifications.add(Uint8List.fromList([0x05, 0x10]));
    expect(future, throwsA(isA<TimeoutException>()));
  });

  test('fails without sending when command channel is unavailable', () async {
    final repository = WatchHealthModelRepository(
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

Uint8List _modelFrame({
  required int steps,
  required int distance,
  required int calories,
}) {
  final value = <int>[
    0x02,
    0x04,
    80,
    0,
    0x68,
    0x8B,
    0x3C,
    0x00,
    ..._u32(steps),
    ..._u32(distance),
    ..._u32(calories),
  ];
  return Uint8List.fromList([
    0x12,
    0x00,
    0x02,
    value.length >> 8,
    value.length & 0xFF,
    ...value,
  ]);
}

List<int> _u32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
