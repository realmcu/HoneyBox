import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_health_protocol.dart';

void main() {
  test('builds an activity request carrying the data type', () {
    expect(
      WatchHealthProtocol.buildRequest(),
      Uint8List.fromList([0x05, 0x10, 0x01, 0x00, 0x01, 0x01]),
    );
  });

  test('builds a sleep request', () {
    expect(
      WatchHealthProtocol.buildRequest(dataType: WatchHealthDataType.sleep),
      Uint8List.fromList([0x05, 0x10, 0x01, 0x00, 0x01, 0x02]),
    );
  });

  test('ignores frames that are not SPORT version 1', () {
    // A version 0 device (header byte 0x00) must not be misread as v1.
    final v0Frame = Uint8List.fromList([0x05, 0x00, 0x07, 0x00, 0x00]);
    expect(WatchHealthProtocol.parseFrame(v0Frame), isEmpty);
  });

  test('parses an 18-byte sport bucket record', () {
    // The single-record example from spec section 3.6.
    final value = Uint8List.fromList([
      0x01, // record count
      0x12, 0x34, 0x56, 0x78, // timestamp
      0x11, 0x22, // steps
      0x33, 0x44, // distance
      0x55, 0x66, // calories (0.1 kcal)
      0x77, // heart rate
      0x0F, // bucket minutes
      0x01, // mode = run
      0x01, // flags = HAS_HR
      0x00, 0x00, 0x00, 0x00, // reserved
    ]);

    final event = WatchHealthProtocol.parseFrame(
      _frame([(WatchHealthKey.sportData, value)]),
    ).single as WatchSportData;

    expect(event.items, hasLength(1));
    final item = event.items.single;
    expect(
      item.timestamp,
      DateTime.fromMillisecondsSinceEpoch(0x12345678 * 1000, isUtc: true)
          .toLocal(),
    );
    expect(item.steps, 0x1122);
    expect(item.distanceMeters, 0x3344);
    expect(item.caloriesDeciKcal, 0x5566);
    expect(item.caloriesKcal, 0x5566 / 10);
    expect(item.heartRate, 0x77);
    expect(item.bucketMinutes, 15);
    expect(item.mode, WatchSportMode.run);
    expect(item.hasHeartRate, isTrue);
    expect(item.partialBucket, isFalse);
  });

  test('zeroes heart rate when the HAS_HR flag is clear', () {
    // Spec says the device must send 0, but a bogus bpm must not leak through
    // as if it were valid.
    final value = Uint8List.fromList([
      0x01,
      0x00, 0x00, 0x00, 0x64,
      0x00, 0x10,
      0x00, 0x20,
      0x00, 0x30,
      0x63, // stale bpm with HAS_HR clear
      0x0F,
      0x00,
      0x02, // flags = PARTIAL_BUCKET only
      0x00, 0x00, 0x00, 0x00,
    ]);

    final event = WatchHealthProtocol.parseFrame(
      _frame([(WatchHealthKey.sportData, value)]),
    ).single as WatchSportData;

    expect(event.items.single.hasHeartRate, isFalse);
    expect(event.items.single.heartRate, 0);
    expect(event.items.single.partialBucket, isTrue);
  });

  test('parses a multi-record page', () {
    final value = Uint8List.fromList([
      0x02,
      ..._sportRecord(timestamp: 1000, steps: 100),
      ..._sportRecord(timestamp: 1900, steps: 250),
    ]);

    final event = WatchHealthProtocol.parseFrame(
      _frame([(WatchHealthKey.sportData, value)]),
    ).single as WatchSportData;

    expect(event.items.map((item) => item.steps), [100, 250]);
  });

  test('parses 8-byte sleep state-change records', () {
    // Spec example: DEEP at 0x12345678, BACKFILLED set.
    final value = Uint8List.fromList([
      0x01,
      0x12, 0x34, 0x56, 0x78,
      0x01, // state = DEEP
      0x01, // flags = BACKFILLED
      0x00, 0x00, // reserved
    ]);

    final event = WatchHealthProtocol.parseFrame(
      _frame([(WatchHealthKey.sleepData, value)]),
    ).single as WatchSleepData;

    expect(event.items.single.state, WatchSleepState.deep);
    expect(event.items.single.backfilled, isTrue);
  });

  test('parses markers with their data type', () {
    final events = WatchHealthProtocol.parseFrame(_frame([
      (WatchHealthKey.syncStart, Uint8List.fromList([0x01])),
      (WatchHealthKey.more, Uint8List.fromList([0x01])),
      (WatchHealthKey.syncEnd, Uint8List.fromList([0x01])),
    ]));

    expect(events, [
      const WatchHealthMarkerEvent(
          WatchHealthMarker.syncStart, WatchHealthDataType.activity),
      const WatchHealthMarkerEvent(
          WatchHealthMarker.more, WatchHealthDataType.activity),
      const WatchHealthMarkerEvent(
          WatchHealthMarker.syncEnd, WatchHealthDataType.activity),
    ]);
  });

  test('distinguishes sleep markers from activity markers', () {
    final events = WatchHealthProtocol.parseFrame(_frame([
      (WatchHealthKey.syncStart, Uint8List.fromList([0x02])),
    ]));

    expect(events, [
      const WatchHealthMarkerEvent(
          WatchHealthMarker.syncStart, WatchHealthDataType.sleep),
    ]);
  });

  test('ignores reserved keys without disturbing the session', () {
    // 0x0D used to be per-sample heart rate; it is reserved in version 1.
    final events = WatchHealthProtocol.parseFrame(_frame([
      (WatchHealthKey.syncStart, Uint8List.fromList([0x01])),
      (0x0D, Uint8List.fromList([0x00, 0x8F, 0x10, 72])),
      (WatchHealthKey.syncEnd, Uint8List.fromList([0x01])),
    ]));

    expect(events, [
      const WatchHealthMarkerEvent(
          WatchHealthMarker.syncStart, WatchHealthDataType.activity),
      const WatchHealthMarkerEvent(
          WatchHealthMarker.syncEnd, WatchHealthDataType.activity),
    ]);
  });

  test('rejects a record count that disagrees with the value length', () {
    final shortPage = Uint8List.fromList([
      0x02, // claims two records
      ..._sportRecord(timestamp: 1000, steps: 100),
    ]);

    expect(
      () => WatchHealthProtocol.parseFrame(
        _frame([(WatchHealthKey.sportData, shortPage)]),
      ),
      throwsFormatException,
    );
  });

  test('rejects a sport record count outside 1..8', () {
    final tooMany = Uint8List.fromList([
      0x09,
      for (var i = 0; i < 9; i++) ..._sportRecord(timestamp: 1000, steps: 1),
    ]);

    expect(
      () => WatchHealthProtocol.parseFrame(
        _frame([(WatchHealthKey.sportData, tooMany)]),
      ),
      throwsFormatException,
    );
    expect(
      () => WatchHealthProtocol.parseFrame(
        _frame([
          (WatchHealthKey.sportData, Uint8List.fromList([0x00]))
        ]),
      ),
      throwsFormatException,
    );
  });

  test('rejects a marker without exactly one data type byte', () {
    expect(
      () => WatchHealthProtocol.parseFrame(
        // Empty value: how version 0 sent its markers.
        _frame([(WatchHealthKey.syncStart, Uint8List(0))]),
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

List<int> _sportRecord({required int timestamp, required int steps}) => [
      (timestamp >> 24) & 0xFF,
      (timestamp >> 16) & 0xFF,
      (timestamp >> 8) & 0xFF,
      timestamp & 0xFF,
      (steps >> 8) & 0xFF,
      steps & 0xFF,
      0x00, 0x00, // distance
      0x00, 0x00, // calories
      0x00, // heart rate
      0x0F, // bucket minutes
      0x00, // mode
      0x00, // flags
      0x00, 0x00, 0x00, 0x00, // reserved
    ];
