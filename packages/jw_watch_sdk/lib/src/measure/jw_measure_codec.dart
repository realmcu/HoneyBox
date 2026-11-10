import 'dart:typed_data';

import '../history/jw_history_models.dart';
import 'jw_measure_models.dart';

/// HR interval options on sport `0x18` (Android `ApplicationLayerHrpParamsPacket`).
List<int> decodeHeartRateIntervalOptions(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const FormatException('Invalid JW heart rate interval options');
  }
  final flags = bytes[0] & 0xff;
  const candidates = <int, int>{
    0: 1,
    1: 5,
    2: 10,
    3: 30,
    4: 60,
    5: 120,
  };
  final options = <int>[];
  for (final entry in candidates.entries) {
    if ((flags >> entry.key) & 0x01 == 1) {
      options.add(entry.value);
    }
  }
  return options;
}

/// `cmd 0x07` key `0x1D` device sync switch bundle.
Iterable<({int type, int value})> decodeDeviceSyncSwitchItems(Uint8List bytes) {
  if (bytes.length < 2) return const [];
  final items = <({int type, int value})>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    items.add((type: bytes[i] & 0xff, value: bytes[i + 1] & 0xff));
  }
  return items;
}

JWAutoMeasureConfig decodeAutoMeasureConfig(Uint8List bytes) {
  if (bytes.length < 2) {
    throw const FormatException('Invalid JW auto measure config');
  }
  return JWAutoMeasureConfig(
    enabled: bytes[0] == 0x01,
    intervalMinutes: bytes[1] & 0xff,
  );
}

JWBloodSugarAutoMeasureConfig decodeBloodSugarAutoMeasure(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const FormatException('Invalid JW blood sugar auto config');
  }
  if (bytes.length >= 2) {
    return JWBloodSugarAutoMeasureConfig(
      enabled: bytes[0] == 0x01,
      intervalMinutes: bytes[1] & 0xff,
    );
  }
  return JWBloodSugarAutoMeasureConfig(
    enabled: bytes[0] == 0x01,
    intervalMinutes: 0,
  );
}

JWTemperatureControlSetting decodeTemperatureControl(Uint8List bytes) {
  if (bytes.length < 4) {
    throw const FormatException('Invalid JW temperature control');
  }
  final flags = bytes[3];
  return JWTemperatureControlSetting(
    enabled: (flags & 0x01) != 0,
    adjust: (flags & 0x02) != 0,
    celsius: (flags & 0x04) == 0,
  );
}

DateTime _timeFromLegacyDate(int yearOffset, int month, int day, int minutes,
    int second) {
  return DateTime.utc(
    2000 + yearOffset,
    month,
    day,
    minutes ~/ 60,
    minutes % 60,
    second,
  );
}

(int year, int month, int day) _legacyDate(Uint8List data) {
  final year = (data[0] & 0x7e) >> 1;
  final month = ((data[0] & 0x01) << 3) | ((data[1] >> 5) & 0x07);
  final day = data[1] & 0x1f;
  return (year, month, day);
}

double _round1(double value) => (value * 10).roundToDouble() / 10;

double _spotSkinTemperature(int tempRaw, int statusByte) {
  if (tempRaw <= 0) return 0;
  final animation = ((statusByte >> 2) & 0x01) == 1;
  final adjust = ((statusByte >> 1) & 0x01) == 1;
  final wear = (statusByte & 0x01) == 1;
  if (animation || tempRaw >= 368) {
    return _round1(tempRaw / 10);
  }
  if (wear && adjust) {
    final adjusted = 368 - (368 - tempRaw) ~/ 20;
    return _round1(adjusted / 10);
  }
  return _round1(tempRaw / 10);
}

/// Spot heart rate / temperature on `cmd 0x05` keys `0x0f` / `0x28`
/// (V2 [HeartRateDataHandler]).
SpotMeasurePayload? decodeSpotHeartRatePayload(
  Uint8List data, {
  required bool temperatureCapable,
}) {
  if (data.length != 8 && data.length != 12) return null;
  final (year, month, day) = _legacyDate(data);
  if (data.length == 8) {
    final minutes = ((data[4] << 8) | (data[5] & 0xff)) & 0xffff;
    final second = data[6] & 0xff;
    final rate = data[7] & 0xff;
    if (rate == 0) return const SpotMeasurePayload();
    final time = _timeFromLegacyDate(year, month, day, minutes, second);
    return SpotMeasurePayload(
      heartRates: [JWHeartRate(time: time, heartRate: rate)],
    );
  }
  final status = data[5] & 0xff;
  final tempRaw = ((data[6] << 8) | (data[7] & 0xff)) & 0xffff;
  final minutes = ((data[8] << 8) | (data[9] & 0xff)) & 0xffff;
  final second = data[10] & 0xff;
  final rate = data[11] & 0xff;
  if (rate == 0) return const SpotMeasurePayload();
  final time = _timeFromLegacyDate(year, month, day, minutes, second);
  final wear = (status & 0x01) == 1;
  final adjust = ((status >> 1) & 0x01) == 1;
  final skin = _spotSkinTemperature(tempRaw, status);
  return SpotMeasurePayload(
    heartRates: [JWHeartRate(time: time, heartRate: rate)],
    temperatures: temperatureCapable && tempRaw != 0
        ? [
            JWTemperature(
              time: time,
              skinTemperature: skin,
              heatStress: 0,
              worn: wear,
              compensated: adjust,
            ),
          ]
        : const [],
  );
}

List<JWBloodPressure>? decodeSpotBloodPressure(Uint8List data) {
  const width = 12;
  if (data.length < width || data.length % width != 0) return null;
  final rows = <JWBloodPressure>[];
  for (var offset = 0; offset < data.length; offset += width) {
    final slice = data.sublist(offset, offset + width);
    final (year, month, day) = _legacyDate(slice);
    final minutes = ((slice[6] << 8) | (slice[7] & 0xff)) & 0xffff;
    final second = slice[8] & 0xff;
    final diastolic = slice[10] & 0xff;
    final systolic = slice[11] & 0xff;
    if (systolic == 0 || diastolic == 0) continue;
    rows.add(
      JWBloodPressure(
        time: _timeFromLegacyDate(year, month, day, minutes, second),
        systolic: systolic,
        diastolic: diastolic,
      ),
    );
  }
  return rows;
}

List<JWBloodOxygen>? decodeSpotBloodOxygen(Uint8List data) {
  const width = 8;
  if (data.length < width || data.length % width != 0) return null;
  final rows = <JWBloodOxygen>[];
  for (var offset = 0; offset < data.length; offset += width) {
    final slice = data.sublist(offset, offset + width);
    final (year, month, day) = _legacyDate(slice);
    final minutes = ((slice[2] << 8) | (slice[3] & 0xff)) & 0xffff;
    final second = slice[4] & 0xff;
    final value = slice[5] & 0xff;
    if (value == 0) continue;
    final high = slice[6] & 0xff;
    final low = slice[7] & 0xff;
    rows.add(
      JWBloodOxygen(
        time: _timeFromLegacyDate(year, month, day, minutes, second),
        value: value,
        high: high == 0 ? null : high,
        low: low == 0 ? null : low,
      ),
    );
  }
  return rows;
}

List<JWBloodGlucose>? decodeSpotBloodGlucose(Uint8List data) {
  const width = 8;
  if (data.length < width || data.length % width != 0) return null;
  final rows = <JWBloodGlucose>[];
  for (var offset = 0; offset < data.length; offset += width) {
    final slice = data.sublist(offset, offset + width);
    final (year, month, day) = _legacyDate(slice);
    final minutes = ((slice[2] << 8) | (slice[3] & 0xff)) & 0xffff;
    final second = slice[4] & 0xff;
    final valueTenth = slice[5] & 0xff;
    if (valueTenth == 0) continue;
    rows.add(
      JWBloodGlucose(
        time: _timeFromLegacyDate(year, month, day, minutes, second),
        value: valueTenth,
      ),
    );
  }
  return rows;
}

/// Decoded spot-measure push for key `0x0f`.
final class SpotMeasurePayload {
  const SpotMeasurePayload({
    this.heartRates = const [],
    this.temperatures = const [],
  });

  final List<JWHeartRate> heartRates;
  final List<JWTemperature> temperatures;

  bool get isEmpty => heartRates.isEmpty && temperatures.isEmpty;
}
