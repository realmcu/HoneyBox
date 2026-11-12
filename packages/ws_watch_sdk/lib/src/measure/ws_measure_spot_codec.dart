import 'dart:typed_data';

import '../history/ws_history_models.dart';

/// Decodes `0x11` spot realtime/result payloads (record layout = 0x05 types).
abstract final class WSMeasureSpotCodec {
  static const int resultSuccess = 0x00;

  static DateTime _wallTimeLe(ByteData data, int offset) {
    final seconds = data.getUint32(offset, Endian.little);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static WSHeartRate? heartRateRealtime(Uint8List value) {
    if (value.isEmpty || value[0] == 0xFF) return null;
    return WSHeartRate(
      time: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      bpm: value[0],
    );
  }

  static WSHeartRate? heartRateResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 6) {
      return null;
    }
    final data = ByteData.sublistView(value, 1, 6);
    return WSHeartRate(
      time: data.getUint32(0, Endian.little),
      bpm: value[5],
    );
  }

  static WSBloodPressure? bloodPressureResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 7) {
      return null;
    }
    final data = ByteData.sublistView(value, 1, 7);
    return WSBloodPressure(
      time: _wallTimeLe(data, 0),
      systolic: value[5],
      diastolic: value[6],
    );
  }

  static WSBloodOxygen? bloodOxygenRealtime(Uint8List value) {
    if (value.isEmpty || value[0] == 0xFF) return null;
    return WSBloodOxygen(
      time: DateTime.now().toUtc(),
      value: value[0],
    );
  }

  static WSBloodOxygen? bloodOxygenResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 8) {
      return null;
    }
    final data = ByteData.sublistView(value, 1, 8);
    return WSBloodOxygen(
      time: _wallTimeLe(data, 0),
      value: value[5],
      high: value[6] == 0xFF ? null : value[6],
      low: value[7] == 0xFF ? null : value[7],
    );
  }

  static WSTemperature? temperatureRealtime(Uint8List value) {
    if (value.length < 2) return null;
    final raw = ByteData.sublistView(value).getUint16(0);
    if (raw == 0x8000) return null;
    return WSTemperature(
      time: DateTime.now().toUtc(),
      skinTemperature: raw / 100,
      heatStress: 0,
      worn: true,
      compensated: false,
      skinHundredthCelsius: raw,
    );
  }

  static WSTemperature? temperatureResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 11) {
      return null;
    }
    final record = Uint8List.sublistView(value, 1);
    final data = ByteData.sublistView(record);
    final skinRaw = data.getUint16(4);
    final flags = record[9];
    return WSTemperature(
      time: _wallTimeLe(data, 0),
      skinTemperature: skinRaw / 100,
      heatStress: record[8] == 0xFF ? 0 : record[8],
      worn: (flags & 0x01) != 0,
      compensated: (flags & 0x02) != 0,
      skinHundredthCelsius: skinRaw,
      flags: flags,
    );
  }

  static WSBloodGlucose? bloodGlucoseRealtime(Uint8List value) {
    if (value.length < 2) return null;
    final raw = ByteData.sublistView(value).getUint16(0);
    return WSBloodGlucose(
      time: DateTime.now().toUtc(),
      value: raw,
    );
  }

  static WSBloodGlucose? bloodGlucoseResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 7) {
      return null;
    }
    final data = ByteData.sublistView(value, 1, 7);
    return WSBloodGlucose(
      time: _wallTimeLe(data, 0),
      value: data.getUint16(4),
    );
  }

  static String resultLine(Uint8List value) {
    if (value.isEmpty) return '点测结束';
    return switch (value[0]) {
      resultSuccess => '点测成功',
      0x01 => '点测已停止',
      _ => '点测结束（结果码 0x${value[0].toRadixString(16)}）',
    };
  }
}
