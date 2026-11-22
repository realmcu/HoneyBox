import 'dart:typed_data';

import '../history/ws_history_models.dart';
import '../history/ws_health_codecs.dart';
import '../wire/ws_data_command.dart';
import '../wire/ws_l2_message.dart';
import '../wire/ws_measure_command.dart';
import 'ws_measure_events.dart';

/// Decodes `0x11` spot realtime/result payloads (record layout = 0x05 types).
abstract final class WSMeasureSpotCodec {
  static const int resultSuccess = 0x00;

  static DateTime _wallTime(ByteData data, int offset) {
    final seconds = data.getUint32(offset);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
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
      time: data.getUint32(0),
      bpm: value[5],
    );
  }

  static WSBloodPressure? bloodPressureResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 7) {
      return null;
    }
    final data = ByteData.sublistView(value, 1, 7);
    return WSBloodPressure(
      time: _wallTime(data, 0),
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
      time: _wallTime(data, 0),
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
      time: DateTime.now(),
      skinTemperature: raw / 100,
      heatStress: 0,
      worn: true,
      compensated: false,
      bodyHundredthCelsius: raw,
      skinHundredthCelsius: raw,
    );
  }

  static WSTemperature? temperatureResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 11) {
      return null;
    }
    final record = Uint8List.sublistView(value, 1);
    final data = ByteData.sublistView(record);
    final bodyRaw = data.getUint16(4);
    final skinRaw = data.getUint16(6);
    final flags = record[9];
    return WSTemperature(
      time: _wallTime(data, 0),
      skinTemperature: skinRaw == 0xffff ? 0 : skinRaw / 100,
      heatStress: record[8] == 0xFF ? 0 : record[8],
      worn: (flags & 0x01) != 0,
      compensated: (flags & 0x02) != 0,
      bodyHundredthCelsius: bodyRaw == 0x8000 ? null : bodyRaw,
      skinHundredthCelsius: skinRaw == 0xffff ? null : skinRaw,
      heatStressRaw: record[8] == 0xff ? null : record[8],
      flags: flags,
    );
  }

  static WSBloodGlucose? bloodGlucoseRealtime(Uint8List value) {
    if (value.length < 2) return null;
    final raw = ByteData.sublistView(value).getUint16(0);
    if (raw == 0xffff) return null;
    return WSBloodGlucose(
      time: DateTime.now(),
      value: raw,
    );
  }

  static WSBloodGlucose? bloodGlucoseResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 7) {
      return null;
    }
    final data = ByteData.sublistView(value, 1, 7);
    final raw = data.getUint16(4);
    if (raw == 0xffff) return null;
    return WSBloodGlucose(
      time: _wallTime(data, 0),
      value: raw,
    );
  }

  static WSHrv? hrvRealtime(Uint8List value) {
    if (value.length < 2) return null;
    final raw = ByteData.sublistView(value).getUint16(0);
    if (raw == 0xffff) return null;
    return WSHrv(time: DateTime.now(), sdnn: raw);
  }

  static WSHrv? hrvResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 7)
      return null;
    final record = Uint8List.sublistView(value, 1);
    final data = ByteData.sublistView(record);
    return WSHrv(time: _wallTime(data, 0), sdnn: data.getUint16(4));
  }

  static WSPressure? pressureRealtime(Uint8List value) {
    if (value.isEmpty || value[0] == 0xff) return null;
    return WSPressure(time: DateTime.now(), value: value[0]);
  }

  static WSPressure? pressureResult(Uint8List value) {
    if (value.isEmpty || value[0] != resultSuccess || value.length < 6)
      return null;
    final record = Uint8List.sublistView(value, 1);
    return WSPressure(
      time: _wallTime(ByteData.sublistView(record), 0),
      value: record[4],
    );
  }

  static WSSpotMeasureStatus decodeStatus(Uint8List value) {
    if (value.length < 7)
      throw const FormatException('spot status requires 7 bytes');
    return WSSpotMeasureStatus(
      active: value[0] == 1,
      dataTypeCode: value[1],
      initiator: value[2],
      startedAtSeconds: ByteData.sublistView(value).getUint32(3),
    );
  }

  static Object? decodeRealtime(WSSpotMeasureLane lane, Uint8List value) =>
      switch (lane) {
        WSSpotMeasureLanes.heartRate ||
        WSSpotMeasureLanes.continuousHeartRate =>
          heartRateRealtime(value),
        WSSpotMeasureLanes.bloodPressure => heartRateRealtime(value),
        WSSpotMeasureLanes.bloodOxygen => bloodOxygenRealtime(value),
        WSSpotMeasureLanes.hrv => hrvRealtime(value),
        WSSpotMeasureLanes.pressure => pressureRealtime(value),
        WSSpotMeasureLanes.temperature => temperatureRealtime(value),
        WSSpotMeasureLanes.bloodGlucose => bloodGlucoseRealtime(value),
        _ => null,
      };

  static Object? decodeResult(WSSpotMeasureLane lane, Uint8List value) =>
      switch (lane) {
        WSSpotMeasureLanes.heartRate => heartRateResult(value),
        WSSpotMeasureLanes.bloodPressure => bloodPressureResult(value),
        WSSpotMeasureLanes.bloodOxygen => bloodOxygenResult(value),
        WSSpotMeasureLanes.hrv => hrvResult(value),
        WSSpotMeasureLanes.pressure => pressureResult(value),
        WSSpotMeasureLanes.temperature => temperatureResult(value),
        WSSpotMeasureLanes.bloodGlucose => bloodGlucoseResult(value),
        _ => null,
      };

  static WSSportRealtimeSnapshot decodeSportRealtime(Uint8List value) {
    if (value.length < 23)
      throw const FormatException('sport realtime requires 23 bytes');
    final data = ByteData.sublistView(value);
    return WSSportRealtimeSnapshot(
      mode: value[0],
      state: value[1],
      startedAtSeconds: data.getUint32(2),
      durationSeconds: data.getUint32(6),
      heartRateBpm: value[10] == 0xff ? null : value[10],
      steps: data.getUint32(11),
      distanceMeters: data.getUint32(15),
      caloriesTenthKcal: data.getUint32(19),
    );
  }

  static WSSportState decodeSportState(Uint8List value) {
    if (value.isEmpty) throw const FormatException('sport state empty');
    if (value[0] == 0) return const WSSportState(hasActiveSport: false);
    if (value.length < 24)
      throw const FormatException('active sport state requires snapshot');
    return WSSportState(
      hasActiveSport: true,
      snapshot: decodeSportRealtime(Uint8List.sublistView(value, 1)),
    );
  }

  static WSSportEndedEvent decodeSportEnd(Uint8List value) {
    if (value.length < 2)
      throw const FormatException('sport end requires 2 bytes');
    WSSport? summary;
    if (value.length >= 33) {
      final frame = WSL2Message(
        command: WSDataCommand.command,
        version: WSDataCommand.version,
        key: WSDataCommand.keyDataSport,
        value: Uint8List.fromList([31, 0, 1, ...value.sublist(2, 33)]),
      );
      summary = WSHealthCodecs.decodeSportDataFrame(frame).single;
    }
    return WSSportEndedEvent(
        result: value[0], endedBy: value[1], summary: summary);
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
