import 'dart:typed_data';

import 'ble_cmd_registry.dart';

/// Health data protocol (CMD 0x05, L2 version 1).
///
/// The wire authority is HoneyProtocol `docs/protocol/0x05-data.rst`.
abstract class WatchHealthKey {
  static const int requestAll = 0x00;

  static const int activityData = 0x21;
  static const int sleepData = 0x22;
  static const int heartRateData = 0x23;
  static const int bloodPressureData = 0x24;
  static const int bloodOxygenData = 0x25;
  static const int hrvData = 0x26;
  static const int stressData = 0x27;
  static const int temperatureData = 0x28;
  static const int bloodGlucoseData = 0x29;
  static const int sportSummaryData = 0x2A;

  static const int syncStart = 0x40;
  static const int syncEnd = 0x41;
  static const int syncAck = 0x42;

  static const int todayRequest = 0x60;
  static const int todayData = 0x61;
}

/// L2 header byte 1 for CMD 0x05: Version=1 in [7:4], Reserve=0.
const int _healthVersion = 0x10;

const int _sportRecordSize = 18;
const int _sleepRecordSize = 8;

abstract class WatchSleepState {
  static const int off = 0x00;
  static const int deep = 0x01;
  static const int light = 0x02;
  static const int wake = 0x03;
  static const int rem = 0x04;
}

abstract class WatchSportMode {
  static const int walk = 0x00;
  static const int run = 0x01;
  static const int invalid = 0x02;
}

class WatchSportItem {
  const WatchSportItem({
    required this.timestamp,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesDeciKcal,
    required this.heartRate,
    required this.bucketMinutes,
    required this.mode,
    required this.hasHeartRate,
    required this.partialBucket,
  });

  final DateTime timestamp;
  final int steps;
  final int distanceMeters;
  final int caloriesDeciKcal;
  final int heartRate;
  final int bucketMinutes;
  final int mode;
  final bool hasHeartRate;
  final bool partialBucket;

  double get caloriesKcal => caloriesDeciKcal / 10;
}

class WatchSportData {
  const WatchSportData(this.items);

  final List<WatchSportItem> items;
}

class WatchSleepItem {
  const WatchSleepItem({
    required this.timestamp,
    required this.state,
    required this.backfilled,
  });

  final DateTime timestamp;
  final int state;
  final bool backfilled;
}

class WatchSleepData {
  const WatchSleepData(this.items);

  final List<WatchSleepItem> items;
}

/// Device-reported snapshot counts from sync-start key 0x40.
class WatchHealthSyncStart {
  const WatchHealthSyncStart(this.counts);

  /// Data type sync key (0x01..0x0A) to record count.
  final Map<int, int> counts;
}

/// Completion marker from sync-end key 0x41.
class WatchHealthSyncEnd {
  const WatchHealthSyncEnd({required this.result, required this.actualCount});

  final int result;
  final int actualCount;

  bool get success => result == 0x00;
}

/// Today's aggregate from key 0x61.
class WatchHealthTodayData {
  const WatchHealthTodayData({
    required this.timestamp,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesDeciKcal,
    required this.activeMinutes,
    required this.latestHeartRate,
    required this.latestHeartRateAt,
  });

  final DateTime timestamp;
  final int steps;
  final int distanceMeters;
  final int caloriesDeciKcal;
  final int activeMinutes;
  final int? latestHeartRate;
  final DateTime? latestHeartRateAt;
}

class WatchHealthProtocol {
  WatchHealthProtocol._();

  static Uint8List buildRequestAll() => Uint8List.fromList([
        BleCmd.watchHealth,
        _healthVersion,
        WatchHealthKey.requestAll,
        0x00,
        0x00,
      ]);

  static Uint8List buildSyncAck() => Uint8List.fromList([
        BleCmd.watchHealth,
        _healthVersion,
        WatchHealthKey.syncAck,
        0x00,
        0x00,
      ]);

  static Uint8List buildTodayRequest() => Uint8List.fromList([
        BleCmd.watchHealth,
        _healthVersion,
        WatchHealthKey.todayRequest,
        0x00,
        0x00,
      ]);

  static List<Object> parseFrame(Uint8List frame) {
    if (frame.length < 2 ||
        frame[0] != BleCmd.watchHealth ||
        frame[1] != _healthVersion) {
      return const [];
    }

    final events = <Object>[];
    var offset = 2;
    while (offset < frame.length) {
      if (offset + 3 > frame.length) {
        throw const FormatException('Incomplete health key header');
      }
      final key = frame[offset];
      final valueLength = _readU16(frame, offset + 1);
      offset += 3;
      if (offset + valueLength > frame.length) {
        throw const FormatException('Health key value exceeds frame');
      }
      final value = Uint8List.sublistView(frame, offset, offset + valueLength);
      offset += valueLength;

      final event = switch (key) {
        WatchHealthKey.activityData => _parseSport(value),
        WatchHealthKey.sleepData => _parseSleep(value),
        WatchHealthKey.syncStart => _parseSyncStart(value),
        WatchHealthKey.syncEnd => _parseSyncEnd(value),
        WatchHealthKey.todayData => _parseToday(value),
        _ => null,
      };
      if (event != null) events.add(event);
    }
    return events;
  }

  static WatchSportData _parseSport(Uint8List value) {
    final offsets = _recordOffsets(value, _sportRecordSize);
    final items = <WatchSportItem>[];
    for (final base in offsets) {
      final flags = value[base + 13];
      final hasHeartRate = (flags & 0x01) != 0;
      items.add(WatchSportItem(
        timestamp: _readTimestamp(value, base),
        steps: _readU16(value, base + 4),
        distanceMeters: _readU16(value, base + 6),
        caloriesDeciKcal: _readU16(value, base + 8),
        heartRate: hasHeartRate ? value[base + 10] : 0,
        bucketMinutes: value[base + 11],
        mode: value[base + 12],
        hasHeartRate: hasHeartRate,
        partialBucket: (flags & 0x02) != 0,
      ));
    }
    return WatchSportData(List.unmodifiable(items));
  }

  static WatchSleepData _parseSleep(Uint8List value) {
    final offsets = _recordOffsets(value, _sleepRecordSize);
    final items = <WatchSleepItem>[];
    for (final base in offsets) {
      items.add(WatchSleepItem(
        timestamp: _readTimestamp(value, base),
        state: value[base + 4],
        backfilled: (value[base + 5] & 0x01) != 0,
      ));
    }
    return WatchSleepData(List.unmodifiable(items));
  }

  static List<int> _recordOffsets(Uint8List value, int minimumItemLength) {
    if (value.length < 3) {
      throw const FormatException('Health record page is incomplete');
    }
    final itemLength = value[0];
    final count = _readU16(value, 1);
    if (itemLength < minimumItemLength) {
      throw FormatException('Health item length is too small: $itemLength');
    }
    if (value.length != 3 + itemLength * count) {
      throw const FormatException('Health record count does not match length');
    }
    return List<int>.generate(
      count,
      (index) => 3 + index * itemLength,
      growable: false,
    );
  }

  static WatchHealthSyncStart _parseSyncStart(Uint8List value) {
    if (value.isEmpty) return const WatchHealthSyncStart({});
    if (value.length % 3 != 0) {
      throw const FormatException('Invalid health sync-start length');
    }
    final counts = <int, int>{};
    for (var offset = 0; offset < value.length; offset += 3) {
      counts[value[offset]] = _readU16(value, offset + 1);
    }
    return WatchHealthSyncStart(Map.unmodifiable(counts));
  }

  static WatchHealthSyncEnd _parseSyncEnd(Uint8List value) {
    if (value.length != 5) {
      throw const FormatException('Invalid health sync-end length');
    }
    return WatchHealthSyncEnd(
      result: value[0],
      actualCount: _readU32(value, 1),
    );
  }

  static WatchHealthTodayData _parseToday(Uint8List value) {
    if (value.length != 23) {
      throw const FormatException('Invalid today-data length');
    }
    final latestHr = value[18];
    final latestHrSeconds = _readU32(value, 19);
    return WatchHealthTodayData(
      timestamp: _readTimestamp(value, 0),
      steps: _readU32(value, 4),
      distanceMeters: _readU32(value, 8),
      caloriesDeciKcal: _readU32(value, 12),
      activeMinutes: _readU16(value, 16),
      latestHeartRate: latestHr == 0xFF ? null : latestHr,
      latestHeartRateAt:
          latestHrSeconds == 0xFFFFFFFF ? null : _timestamp(latestHrSeconds),
    );
  }

  static DateTime _readTimestamp(Uint8List bytes, int offset) =>
      _timestamp(_readU32(bytes, offset));

  static DateTime _timestamp(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );

  static int _readU16(Uint8List bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];

  static int _readU32(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
