import 'dart:typed_data';
import 'jw_history_models.dart';

const _layouts = <int, (JwHistoryType, int)>{
  2: (JwHistoryType.steps, 12),
  3: (JwHistoryType.sleep, 8),
  0x1b: (JwHistoryType.heartTemperature, 12),
  0x29: (JwHistoryType.heartTemperature, 12),
  0x13: (JwHistoryType.bloodPressure, 12),
  0x16: (JwHistoryType.exercise, 32),
  0x2c: (JwHistoryType.bloodOxygen, 8),
  0x3c: (JwHistoryType.hrv, 8),
  0x5b: (JwHistoryType.pressure, 8),
  0x60: (JwHistoryType.metabolism, 48),
  0x64: (JwHistoryType.readiness, 20),
};

/// Decodes the flat stored-record layouts emitted by the pinned S200 firmware.
/// Control markers are handled by the coordinator, never converted to records.
List<JwHistoryRecord> decodeJwHistoryField(
    String deviceKey, int key, Uint8List value,
    {required String batchId, required int firstSeenOrdinal}) {
  final layout = _layouts[key];
  if (layout == null || value.isEmpty || value.length % layout.$2 != 0) {
    throw FormatException('JW history key/record length: $key');
  }
  final records = <JwHistoryRecord>[];
  for (var offset = 0; offset < value.length; offset += layout.$2) {
    final raw = Uint8List.fromList(value.sublist(offset, offset + layout.$2));
    final b = ByteData.sublistView(raw);
    final values = <String, Object?>{};
    final validity = <String, bool>{};
    var version = 1;
    var basis = 'deviceLocalCalendar';
    var sourceTime = <String, Object?>{};
    late String day;
    String? identity;
    var minute = 0, second = 0;
    if ([2, 3, 0x1b, 0x29, 0x13, 0x16].contains(key)) {
      final dateWord = b.getUint16(0);
      day = _date(
          2000 + ((dateWord >> 9) & 63), (dateWord >> 5) & 15, dateWord & 31);
      if (b.getUint16(2) != 1) {
        throw const FormatException('JW stored record header count');
      }
      values['date'] = day;
    }
    switch (key) {
      case 2:
        final w = _beWord(raw, 4, 8);
        final bucket = _bits(w, 53, 11);
        if (bucket >= 96) throw const FormatException('JW step quarter');
        minute = bucket * 15;
        values.addAll({
          'steps': _bits(w, 39, 12),
          'distanceMeters': _bits(w, 0, 16),
          'energyCalories': _bits(w, 16, 19),
          'activeMinutes': _bits(w, 35, 4),
          'mode': _bits(w, 51, 2)
        });
        identity = '$day/$minute/${values['mode']}';
      case 3:
        final w = b.getUint32(4);
        minute = w >> 16;
        final mode = w & 15;
        if (mode > 4) throw const FormatException('JW sleep mode');
        values['mode'] = mode;
        identity = '$day/$minute/$mode';
      case 0x1b:
      case 0x29:
        final w = _beWord(raw, 4, 8);
        minute = _bits(w, 16, 16);
        second = _bits(w, 8, 8);
        values['heartRateBpm'] = _nonzero(_bits(w, 0, 8));
        if (key == 0x29) {
          final temp = _bits(w, 32, 14);
          values.addAll({
            'skinTemperatureCelsius': temp == 0 ? null : temp / 10,
            'heatStress': _bits(w, 46, 2),
            'worn': _bits(w, 48, 1) == 1,
            'compensated': _bits(w, 49, 1) == 1,
            'sameWristband': _bits(w, 50, 1) == 1
          });
          validity['temperatureRecorded'] = temp != 0;
        }
        validity['heartRateRecorded'] = values['heartRateBpm'] != null;
      case 0x13:
        final w = _beWord(raw, 4, 8);
        minute = _bits(w, 32, 16);
        second = _bits(w, 24, 8);
        values.addAll({
          'systolicMmHg': _nonzero(_bits(w, 0, 8)),
          'diastolicMmHg': _nonzero(_bits(w, 8, 8)),
          'heartRateBpm': _nonzero(_bits(w, 16, 8))
        });
      case 0x2c:
        final w = _beWord(raw, 0, 8);
        day = _date(2000 + _bits(w, 57, 6), _bits(w, 53, 4), _bits(w, 48, 5));
        minute = _bits(w, 32, 16);
        second = _bits(w, 24, 8);
        values.addAll({
          'date': day,
          'percent': _nonzero(_bits(w, 16, 8)),
          'highPercent': _nonzero(_bits(w, 8, 8)),
          'lowPercent': _nonzero(_bits(w, 0, 8))
        });
      case 0x16:
        minute = b.getUint16(5);
        second = raw[7];
        if (raw[11] > 59 || raw[15] > 59) {
          throw const FormatException('JW exercise duration seconds');
        }
        values.addAll({
          'mode': raw[8],
          'durationMinutes': b.getUint16(9),
          'durationSeconds': raw[11],
          'pauseCount': raw[12],
          'pauseMinutes': b.getUint16(13),
          'pauseSeconds': raw[15],
          'steps': b.getUint32(16),
          'distanceMeters': b.getUint32(20),
          'energyCalories': b.getUint32(24),
          'heartRateMax': _nonzero(raw[28]),
          'heartRateAverage': _nonzero(raw[29]),
          'heartRateMin': _nonzero(raw[30])
        });
        identity = '$day/$minute:$second/${raw[8]}';
      case 0x3c:
        version = raw[0];
        if (version != 1) throw const FormatException('JW HRV wire version');
        final seconds = b.getUint32(1);
        if (seconds < 946656000) {
          throw const FormatException('JW HRV timestamp');
        }
        final local = seconds - 946656000;
        day = _epochDay(local);
        basis = 's200LegacyUnixOffset';
        values.addAll({
          'wireVersion': version,
          'wireUnixSeconds': seconds,
          'localEpochSeconds': local,
          'sdnnMilliseconds': _nonzero(raw[5]),
          'sampleCount': null,
          'flags': null
        });
        sourceTime = {'wireUnixSeconds': seconds, 'localEpochSeconds': local};
        identity = '$local';
      case 0x5b:
        final local = b.getUint32(0, Endian.little);
        day = _epochDay(local);
        basis = 'deviceLocalEpoch2000';
        values.addAll({'localEpochSeconds': local, 'value': _nonzero(raw[4])});
        sourceTime = {'localEpochSeconds': local};
        identity = '$local';
      case 0x60:
        version = raw[4];
        if (version != 2 && version != 3) {
          throw const FormatException('JW metabolism version');
        }
        final local = b.getUint32(0, Endian.little);
        day = _epochDay(local);
        basis = 'deviceLocalEpoch2000';
        int u16(int offset) => b.getUint16(offset, Endian.little);
        final flags = raw[5];
        bool flag(int mask) => flags & mask != 0;
        final rest = flag(1),
            sleep = flag(2),
            hrv = flag(4),
            oxygen = flag(16),
            temperature = flag(32);
        final energy = u16(40);
        values.addAll({
          'wireVersion': version,
          'dayEpochSeconds': local,
          'flags': flags,
          'wearMinutes': u16(6),
          'restStartMinute': rest && u16(8) != 0xffff ? u16(8) : null,
          'restHeartRateBpm': rest ? _nonzero(raw[10]) : null,
          'nightHeartRateP10': rest ? _nonzero(raw[11]) : null,
          'sdnnMedianMs': hrv ? u16(12) : null,
          'sdnnP25Ms': hrv ? u16(14) : null,
          'sdnnP75Ms': hrv ? u16(16) : null,
          'sdnnCount': u16(18),
          'spo2MeanPercent': oxygen ? _nonzero(raw[20]) : null,
          'spo2MinPercent': oxygen ? _nonzero(raw[21]) : null,
          'spo2Lt90Count': oxygen ? raw[22] : null,
          'dayHeartRateAverageBpm': _nonzero(raw[23]),
          'skinTemperatureMeanCelsius':
              temperature ? b.getInt16(24, Endian.little) / 10 : null,
          'skinTemperatureRangeCelsius': temperature ? u16(26) / 10 : null,
          'sleepMinutes': sleep ? u16(28) : null,
          'deepSleepMinutes': sleep ? u16(30) : null,
          'sleepOnsetMinute': sleep && u16(32) != 0xffff ? u16(32) : null,
          'activeMinutes': u16(34),
          'steps': b.getUint32(36, Endian.little),
          'energyRaw': energy,
          'energyKilocalories': version == 3 ? energy : energy / 1000,
          'sedentaryMaxMinutes': u16(42),
          'stressAverage': _nonzero(raw[44]),
          'heartRatePeriodMinutes': raw[45] == 0xff ? null : raw[45],
          'flags2': raw[46]
        });
        for (final field in ['restStartMinute', 'sleepOnsetMinute']) {
          final v = values[field];
          if (v is int && v >= 1440) {
            throw FormatException('JW metabolism $field');
          }
        }
        validity.addAll({
          'restFound': rest,
          'sleepAvailable': sleep,
          'hrvValid': hrv,
          'hrvPartial': flag(8),
          'spo2Valid': oxygen,
          'temperatureValid': temperature,
          'clockJump': flag(64),
          'heartRateCoarse': flag(128),
          'lateClose': raw[46] & 1 != 0,
          'temperatureDisplayUnavailable': raw[46] & 2 != 0
        });
        sourceTime = {'dayEpochSeconds': local};
        identity = day;
      case 0x64:
        version = raw[16];
        if (version != 3 || raw[4] > 7) {
          throw const FormatException('JW readiness algorithm/availability');
        }
        day = _date(b.getUint16(0, Endian.little), raw[2], raw[3]);
        final available = raw[4] == 0;
        if (available && (raw[6] == 0xff || raw[6] > 100)) {
          throw const FormatException('JW readiness available score');
        }
        final sleepValue = b.getUint16(14, Endian.little);
        values.addAll({
          'date': day,
          'availability': raw[4],
          'tier': raw[5],
          'score': available ? raw[6] : null,
          'hrContribution': b.getInt8(7),
          'hrvContribution': b.getInt8(8),
          'baselineNights': raw[9],
          'restHeartRateBpm': _nonzero(raw[10]),
          'flags': raw[11],
          'sdnnMedianMs': b.getUint16(12, Endian.little),
          'sleepMinutes':
              raw[11] & 4 != 0 || sleepValue == 0xffff ? null : sleepValue,
          'algorithmVersion': version
        });
        validity['available'] = available;
        sourceTime = {'date': day};
        identity = day;
    }
    if (basis == 'deviceLocalCalendar' && key != 0x64) {
      if (minute >= 1440 || second > 59) {
        throw const FormatException('JW history minute/second');
      }
      values['minute'] = minute;
      if (![2, 3].contains(key)) values['second'] = second;
      sourceTime = {'date': day, 'minute': minute, 'second': second};
      identity ??= '$day/$minute:$second';
    }
    final hex = raw.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    records.add(JwHistoryRecord(
        deviceKey: deviceKey,
        type: layout.$1,
        key: key,
        wireVersion: version,
        sourceIdentity: identity!,
        sourceTimeBasis: basis,
        day: day,
        rawHex: hex,
        values: values,
        sourceTime: sourceTime,
        validity: validity,
        firstSeenBatch: batchId,
        firstSeenOrdinal: firstSeenOrdinal + records.length));
  }
  return List.unmodifiable(records);
}

BigInt _beWord(Uint8List bytes, int offset, int length) {
  var result = BigInt.zero;
  for (var i = offset; i < offset + length; i++) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

int _bits(BigInt word, int shift, int width) =>
    ((word >> shift) & ((BigInt.one << width) - BigInt.one)).toInt();
int? _nonzero(int value) => value == 0 ? null : value;
String _date(int year, int month, int day) {
  if (year < 2000 ||
      year > 9999 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31) {
    throw const FormatException('JW history calendar date');
  }
  final d = DateTime.utc(year, month, day);
  if (d.year != year || d.month != month || d.day != day) {
    throw const FormatException('JW history invalid calendar date');
  }
  return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

String _epochDay(int seconds) {
  final d = DateTime.utc(2000).add(Duration(seconds: seconds));
  return _date(d.year, d.month, d.day);
}
