import 'dart:typed_data';

import 'ble_cmd_registry.dart';

/// SPORT/health protocol (CMD 0x05) **version 1**.
///
/// Wire format authority: `BLE_PROTOCOL_SPEC.html` section 3.6 in the firmware
/// repo. Device-side implementation: `app/app_protocol/hmi_l2_cmd_sport.c`.
///
/// Migrated from the deprecated version 0 dialect. What changed:
///   - L2 header byte 1 is `0x10` (Version=1, Reserve=0), not `0x00`.
///   - SPORT_REQ carries a 1-byte Data type; it used to be empty.
///   - syncStart / more / syncEnd carry that same Data type byte; they used to
///     be required to be empty.
///   - Sport records are 18 flat big-endian bytes keyed by wall clock seconds,
///     replacing 8-byte bitfields keyed by "packed date + 15-minute slot".
///   - Per-sample heart rate (key 0x0D) is gone. Version 1 only carries a
///     per-bucket AVERAGE bpm inside the sport record, valid when
///     `flags.hasHeartRate` is set. Key 0x0D is reserved and must not be sent.
///   - Sleep (key 0x03) is specified as 8-byte state-change records but the
///     device has no sleep storage yet, so it never sends them. Decoding is
///     implemented per spec so a future firmware needs no app change.
abstract class WatchHealthKey {
  static const int requestData = BleCmdWatchHealthKey.requestData;
  static const int sportData = BleCmdWatchHealthKey.sportData;
  static const int sleepData = BleCmdWatchHealthKey.sleepData;
  static const int more = BleCmdWatchHealthKey.more;
  static const int syncStart = BleCmdWatchHealthKey.syncStart;
  static const int syncEnd = BleCmdWatchHealthKey.syncEnd;
}

/// Data type selecting which history stream a session syncs (spec 3.6, 0x01).
abstract class WatchHealthDataType {
  static const int activity = 0x01;
  static const int sleep = 0x02;
}

/// L2 header byte 1 for SPORT version 1: Version=1 in [7:4], Reserve=0.
const int _sportVersion = 0x10;

/// Fixed wire size of one sport bucket record.
const int _sportRecordSize = 18;

/// Fixed wire size of one sleep state-change record.
const int _sleepRecordSize = 8;

/// A sync marker plus the Data type it applies to. Version 0 markers were
/// bare; version 1 tags them, and the spec requires the type to match the
/// session, so the type has to survive parsing.
class WatchHealthMarkerEvent {
  const WatchHealthMarkerEvent(this.marker, this.dataType);

  final WatchHealthMarker marker;
  final int dataType;

  @override
  bool operator ==(Object other) =>
      other is WatchHealthMarkerEvent &&
      other.marker == marker &&
      other.dataType == dataType;

  @override
  int get hashCode => Object.hash(marker, dataType);

  @override
  String toString() => 'WatchHealthMarkerEvent($marker, dataType: $dataType)';
}

enum WatchHealthMarker { syncStart, more, syncEnd }

/// Sleep stage values (spec 3.6 key 0x03 State table).
abstract class WatchSleepState {
  static const int off = 0x00;
  static const int deep = 0x01;
  static const int light = 0x02;
  static const int wake = 0x03;
  static const int rem = 0x04;
}

/// Walking / running classification of a bucket (spec: Mode).
abstract class WatchSportMode {
  static const int walk = 0x00;
  static const int run = 0x01;
  static const int invalid = 0x02;
}

/// One 15-minute activity bucket.
///
/// [timestamp] is the natural-quarter bucket start, matching the FlashDB record
/// exactly. The statistical window is `[timestamp, timestamp + bucketMinutes)`.
/// Both complete and partial buckets align to wall-clock 00/15/30/45 boundaries;
/// use the timestamp directly for date/hour grouping without shifting it.
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

  /// Calories in 0.1 kcal units, as sent on the wire.
  final int caloriesDeciKcal;

  /// Average bpm across the bucket. Meaningful only when [hasHeartRate];
  /// the device sends 0 otherwise. This is NOT a live sample.
  final int heartRate;

  /// Configured bucket width, fixed at 15 in version 1.
  final int bucketMinutes;

  /// See [WatchSportMode].
  final int mode;

  final bool hasHeartRate;

  /// Set when the device flushed early (shutdown, unbind, low battery, forced
  /// debug flush). [bucketMinutes] stays 15 regardless -- it describes the
  /// logical interval, not how long this record actually sampled. The actual
  /// sampling start/end cannot be derived from the wire record.
  final bool partialBucket;

  double get caloriesKcal => caloriesDeciKcal / 10;
}

class WatchSportData {
  const WatchSportData(this.items);

  final List<WatchSportItem> items;
}

/// One sleep state transition: the wearer entered [state] at [timestamp], and
/// stays there until the next record's timestamp.
class WatchSleepItem {
  const WatchSleepItem({
    required this.timestamp,
    required this.state,
    required this.backfilled,
  });

  final DateTime timestamp;

  /// See [WatchSleepState].
  final int state;

  /// The algorithm backdated this state to before the moment it was confirmed.
  /// [timestamp] is already the final effective time either way -- do not
  /// subtract a confirmation delay.
  final bool backfilled;
}

class WatchSleepData {
  const WatchSleepData(this.items);

  final List<WatchSleepItem> items;
}

class WatchHealthProtocol {
  WatchHealthProtocol._();

  /// Build a SPORT_REQ for the given Data type. The first request opens a
  /// session at the oldest record; after a `more` marker, the next request
  /// must repeat the same [dataType] to advance the cursor.
  static Uint8List buildRequest({
    int dataType = WatchHealthDataType.activity,
  }) =>
      Uint8List.fromList([
        BleCmd.watchHealth,
        _sportVersion,
        WatchHealthKey.requestData,
        0x00,
        0x01,
        dataType,
      ]);

  static List<Object> parseFrame(Uint8List frame) {
    if (frame.length < 2 ||
        frame[0] != BleCmd.watchHealth ||
        frame[1] != _sportVersion) {
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
        WatchHealthKey.sportData => _parseSport(value),
        WatchHealthKey.sleepData => _parseSleep(value),
        WatchHealthKey.syncStart => _parseMarker(
            value,
            WatchHealthMarker.syncStart,
          ),
        WatchHealthKey.more => _parseMarker(value, WatchHealthMarker.more),
        WatchHealthKey.syncEnd => _parseMarker(
            value,
            WatchHealthMarker.syncEnd,
          ),
        // Unknown or reserved keys are ignored without disturbing the session
        // (spec 3.6 "异常与兼容处理").
        _ => null,
      };
      if (event != null) events.add(event);
    }
    return events;
  }

  static WatchSportData _parseSport(Uint8List value) {
    if (value.isEmpty) {
      throw const FormatException('Sport page is empty');
    }
    final count = value[0];
    // Spec: count is 1..8 and the length must match exactly. A page that fails
    // either check must be dropped whole rather than partially ingested.
    if (count < 1 || count > 8) {
      throw FormatException('Sport record count out of range: $count');
    }
    if (value.length != 1 + count * _sportRecordSize) {
      throw const FormatException('Sport item count does not match length');
    }

    final items = <WatchSportItem>[];
    for (var i = 0; i < count; i++) {
      final base = 1 + i * _sportRecordSize;
      final flags = value[base + 13];
      final hasHeartRate = (flags & 0x01) != 0;
      items.add(WatchSportItem(
        timestamp: _readTimestamp(value, base),
        steps: _readU16(value, base + 4),
        distanceMeters: _readU16(value, base + 6),
        caloriesDeciKcal: _readU16(value, base + 8),
        // Spec: heart rate is only valid under the HAS_HR flag, and the device
        // must send 0 otherwise. Normalise so callers can't read a stale bpm.
        heartRate: hasHeartRate ? value[base + 10] : 0,
        bucketMinutes: value[base + 11],
        mode: value[base + 12],
        hasHeartRate: hasHeartRate,
        partialBucket: (flags & 0x02) != 0,
      ));
      // Offset 14..17 is Reserved -- carried through by the device, not
      // interpreted here.
    }
    return WatchSportData(List.unmodifiable(items));
  }

  static WatchSleepData _parseSleep(Uint8List value) {
    if (value.isEmpty) {
      throw const FormatException('Sleep page is empty');
    }
    final count = value[0];
    if (count < 1 || count > 18) {
      throw FormatException('Sleep record count out of range: $count');
    }
    if (value.length != 1 + count * _sleepRecordSize) {
      throw const FormatException('Sleep item count does not match length');
    }

    final items = <WatchSleepItem>[];
    for (var i = 0; i < count; i++) {
      final base = 1 + i * _sleepRecordSize;
      items.add(WatchSleepItem(
        timestamp: _readTimestamp(value, base),
        state: value[base + 4],
        backfilled: (value[base + 5] & 0x01) != 0,
      ));
      // Offset 6..7 is Reserved.
    }
    return WatchSleepData(List.unmodifiable(items));
  }

  /// syncStart / more / syncEnd each carry exactly one Data type byte.
  static Object _parseMarker(Uint8List value, WatchHealthMarker marker) {
    if (value.length != 1) {
      throw const FormatException(
          'Health marker must carry one data type byte');
    }
    return WatchHealthMarkerEvent(marker, value[0]);
  }

  /// Wall clock seconds, big-endian (1970 epoch, value = what the watch shows).
  static DateTime _readTimestamp(Uint8List bytes, int offset) {
    final seconds = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static int _readU16(Uint8List bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];
}
