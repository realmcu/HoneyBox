import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_health_protocol.dart';

void main() {
  test('builds the golden-protocol history and today requests', () {
    expect(
      WatchHealthProtocol.buildRequestAll(),
      Uint8List.fromList([0x05, 0x10, 0x00, 0x00, 0x00]),
    );
    expect(
      WatchHealthProtocol.buildSyncAck(),
      Uint8List.fromList([0x05, 0x10, 0x42, 0x00, 0x00]),
    );
    expect(
      WatchHealthProtocol.buildTodayRequest(),
      Uint8List.fromList([0x05, 0x10, 0x60, 0x00, 0x00]),
    );
  });

  test('parses sync-start counts and sync-end result', () {
    final events = WatchHealthProtocol.parseFrame(_frame([
      (WatchHealthKey.syncStart, Uint8List.fromList([0x01, 0x02, 0x58])),
      (
        WatchHealthKey.syncEnd,
        Uint8List.fromList([0x00, 0x00, 0x00, 0x02, 0x58])
      ),
    ]));

    expect((events[0] as WatchHealthSyncStart).counts, {0x01: 600});
    final end = events[1] as WatchHealthSyncEnd;
    expect(end.success, isTrue);
    expect(end.actualCount, 600);
  });

  test('parses an 18-byte activity page using item_len + count', () {
    final value = Uint8List.fromList([
      0x12,
      0x00,
      0x02,
      ..._sportRecord(timestamp: 1000, steps: 100, heartRate: 70),
      ..._sportRecord(timestamp: 1900, steps: 250, heartRate: 80),
    ]);
    final event = WatchHealthProtocol.parseFrame(
      _frame([(WatchHealthKey.activityData, value)]),
    ).single as WatchSportData;

    expect(event.items.map((item) => item.steps), [100, 250]);
    expect(event.items.map((item) => item.heartRate), [70, 80]);
    expect(event.items.first.hasHeartRate, isTrue);
    expect(
      event.items.first.timestamp,
      DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
    );
  });

  test('parses an 8-byte sleep page', () {
    final value = Uint8List.fromList([
      0x08,
      0x00,
      0x01,
      0x00,
      0x00,
      0x03,
      0xE8,
      0x01,
      0x01,
      0x00,
      0x00,
    ]);
    final event = WatchHealthProtocol.parseFrame(
      _frame([(WatchHealthKey.sleepData, value)]),
    ).single as WatchSleepData;

    expect(event.items.single.state, WatchSleepState.deep);
    expect(event.items.single.backfilled, isTrue);
  });

  test('parses the 23-byte today aggregate', () {
    final value = Uint8List.fromList([
      ..._u32(1700000000),
      ..._u32(1234),
      ..._u32(800),
      ..._u32(123),
      0x00,
      0x2A,
      72,
      ..._u32(1699999999),
    ]);
    final event = WatchHealthProtocol.parseFrame(
      _frame([(WatchHealthKey.todayData, value)]),
    ).single as WatchHealthTodayData;

    expect(event.steps, 1234);
    expect(event.distanceMeters, 800);
    expect(event.caloriesDeciKcal, 123);
    expect(event.activeMinutes, 42);
    expect(event.latestHeartRate, 72);
  });

  test('rejects a page whose count disagrees with item_len', () {
    final value = Uint8List.fromList([0x12, 0x00, 0x02, 1, 2, 3]);
    expect(
      () => WatchHealthProtocol.parseFrame(
        _frame([(WatchHealthKey.activityData, value)]),
      ),
      throwsFormatException,
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

List<int> _sportRecord({
  required int timestamp,
  required int steps,
  required int heartRate,
}) =>
    [
      ..._u32(timestamp),
      steps >> 8,
      steps & 0xFF,
      0x00,
      0x00,
      0x00,
      0x00,
      heartRate,
      0x0F,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
    ];

List<int> _u32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
