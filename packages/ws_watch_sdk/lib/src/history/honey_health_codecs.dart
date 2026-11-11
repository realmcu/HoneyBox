import 'dart:typed_data';

import '../honey/honey_data.dart';
import '../honey/honey_l2.dart';
import 'honey_data_frame.dart';
import 'ws_history_models.dart';

typedef _RecordDecoder<T> = T Function(Uint8List record);

/// Decodes history data frames (`0x21`–`0x2A`) per [HoneyProtocol 0x05-data.rst].
abstract final class HoneyHealthCodecs {
  static Object decodeByKey(int key, HoneyL2Message message) {
    switch (key) {
      case HoneyDataCommand.keyDataActivity:
        return decodeActivityDataFrame(message);
      case HoneyDataCommand.keyDataSleep:
        return decodeSleepDataFrame(message);
      case HoneyDataCommand.keyDataHeartRate:
        return decodeHeartRateDataFrame(message);
      case HoneyDataCommand.keyDataBloodPressure:
        return decodeBloodPressureDataFrame(message);
      case HoneyDataCommand.keyDataBloodOxygen:
        return decodeBloodOxygenDataFrame(message);
      case HoneyDataCommand.keyDataHrv:
        return decodeHrvDataFrame(message);
      case HoneyDataCommand.keyDataPressure:
        return decodePressureDataFrame(message);
      case HoneyDataCommand.keyDataTemperature:
        return decodeTemperatureDataFrame(message);
      case HoneyDataCommand.keyDataBloodGlucose:
        return decodeBloodGlucoseDataFrame(message);
      case HoneyDataCommand.keyDataSport:
        return decodeSportDataFrame(message);
      default:
        throw ArgumentError.value(key, 'key', 'unsupported data key');
    }
  }

  static List<WSActivity> decodeActivityDataFrame(HoneyL2Message frame) =>
      _decodeFrame(frame, HoneyDataCommand.keyDataActivity, 18, _decodeActivity);

  static List<WSSleep> decodeSleepDataFrame(HoneyL2Message frame) =>
      _decodeFrame(frame, HoneyDataCommand.keyDataSleep, 8, _decodeSleep);

  static List<WSHeartRate> decodeHeartRateDataFrame(HoneyL2Message frame) =>
      _decodeFrame(frame, HoneyDataCommand.keyDataHeartRate, 5, _decodeHeartRate);

  static List<WSBloodPressure> decodeBloodPressureDataFrame(HoneyL2Message frame) =>
      _decodeFrame(
        frame,
        HoneyDataCommand.keyDataBloodPressure,
        6,
        _decodeBloodPressure,
      );

  static List<WSBloodOxygen> decodeBloodOxygenDataFrame(HoneyL2Message frame) =>
      _decodeFrame(
        frame,
        HoneyDataCommand.keyDataBloodOxygen,
        7,
        _decodeBloodOxygen,
      );

  static List<WSHrv> decodeHrvDataFrame(HoneyL2Message frame) =>
      _decodeFrame(frame, HoneyDataCommand.keyDataHrv, 6, _decodeHrv);

  static List<WSPressure> decodePressureDataFrame(HoneyL2Message frame) =>
      _decodeFrame(frame, HoneyDataCommand.keyDataPressure, 5, _decodePressure);

  static List<WSTemperature> decodeTemperatureDataFrame(HoneyL2Message frame) =>
      _decodeFrame(
        frame,
        HoneyDataCommand.keyDataTemperature,
        10,
        _decodeTemperature,
      );

  static List<WSBloodGlucose> decodeBloodGlucoseDataFrame(HoneyL2Message frame) =>
      _decodeFrame(
        frame,
        HoneyDataCommand.keyDataBloodGlucose,
        6,
        _decodeBloodGlucose,
      );

  static List<WSSport> decodeSportDataFrame(HoneyL2Message frame) =>
      _decodeFrame(frame, HoneyDataCommand.keyDataSport, 31, _decodeSport);

  static List<T> _decodeFrame<T>(
    HoneyL2Message frame,
    int expectedKey,
    int expectedRecordLen,
    _RecordDecoder<T> decodeRecord,
  ) {
    if (frame.key != expectedKey) {
      throw FormatException(
        'expected data key 0x${expectedKey.toRadixString(16)}',
      );
    }
    final value = frame.value;
    if (value.isEmpty) {
      return const [];
    }
    if (value[0] != expectedRecordLen) {
      throw FormatException('record length mismatch');
    }
    final records = HoneyDataFrame.splitValueFrames(value);
    return records.map(decodeRecord).toList();
  }

  static DateTime _wallTime(int epochSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);

  static WSActivity _decodeActivity(Uint8List r) {
    final data = ByteData.sublistView(r);
    final flags = r[13];
    final calories = data.getUint16(8);
    final bucket = r[11];
    return WSActivity(
      time: _wallTime(data.getUint32(0)),
      steps: data.getUint16(4),
      distance: data.getUint16(6),
      energy: calories,
      activeTime: bucket,
      mode: r[12],
      avgHeartBpm: r[10],
      bucketMinutes: bucket,
      flags: flags,
      hasAvgHeartRate: (flags & 0x01) != 0,
      incompleteBucket: (flags & 0x02) != 0,
    );
  }

  static WSSleep _decodeSleep(Uint8List r) {
    final flags = r[5];
    return WSSleep(
      time: _wallTime(ByteData.sublistView(r).getUint32(0)),
      mode: r[4],
      flags: flags,
      timeRewind: (flags & 0x01) != 0,
    );
  }

  static WSHeartRate _decodeHeartRate(Uint8List r) {
    return WSHeartRate(
      time: ByteData.sublistView(r).getUint32(0),
      bpm: r[4],
    );
  }

  static WSBloodPressure _decodeBloodPressure(Uint8List r) {
    return WSBloodPressure(
      time: _wallTime(ByteData.sublistView(r).getUint32(0)),
      systolic: r[4],
      diastolic: r[5],
    );
  }

  static int? _optionalByte(int v) => v == 0xFF ? null : v;

  static WSBloodOxygen _decodeBloodOxygen(Uint8List r) {
    return WSBloodOxygen(
      time: _wallTime(ByteData.sublistView(r).getUint32(0)),
      value: r[4],
      high: _optionalByte(r[5]),
      low: _optionalByte(r[6]),
    );
  }

  static WSHrv _decodeHrv(Uint8List r) {
    return WSHrv(
      time: _wallTime(ByteData.sublistView(r).getUint32(0)),
      sdnn: ByteData.sublistView(r).getUint16(4),
    );
  }

  static WSPressure _decodePressure(Uint8List r) {
    return WSPressure(
      time: _wallTime(ByteData.sublistView(r).getUint32(0)),
      value: r[4],
    );
  }

  static WSTemperature _decodeTemperature(Uint8List r) {
    final data = ByteData.sublistView(r);
    final bodyRaw = data.getUint16(4);
    final skinRaw = data.getUint16(6);
    final heat = r[8];
    final flags = r[9];
    final body = bodyRaw == 0x8000 ? null : bodyRaw;
    final skin = skinRaw == 0xFFFF ? null : skinRaw;
    return WSTemperature(
      time: _wallTime(data.getUint32(0)),
      skinTemperature: skin == null ? 0 : skin / 100,
      heatStress: heat == 0xFF ? 0 : heat,
      worn: (flags & 0x01) != 0,
      compensated: (flags & 0x02) != 0,
      bodyHundredthCelsius: body,
      skinHundredthCelsius: skin,
      heatStressRaw: heat == 0xFF ? null : heat,
      flags: flags,
    );
  }

  static WSBloodGlucose _decodeBloodGlucose(Uint8List r) {
    return WSBloodGlucose(
      time: _wallTime(ByteData.sublistView(r).getUint32(0)),
      value: ByteData.sublistView(r).getUint16(4),
    );
  }

  static WSSport _decodeSport(Uint8List r) {
    final data = ByteData.sublistView(r);
    final detailFlags = r[30];
    final start = data.getUint32(4);
    final totalDuration = data.getUint16(15);
    final calories = data.getUint32(25);
    final avgHr = r[29];
    return WSSport(
      time: _wallTime(start),
      mode: r[12],
      duration: totalDuration,
      pauseCount: 0,
      pauseDuration: 0,
      steps: data.getUint32(17),
      distance: data.getUint32(21),
      energy: calories,
      heartRateAverage: avgHr,
      sportId: data.getUint32(0),
      startTime: start,
      endTime: data.getUint32(8),
      effectiveDurationSec: data.getUint16(13),
      totalDurationSec: totalDuration,
      detailFlags: detailFlags,
      hasDetail: (detailFlags & 0x01) != 0,
    );
  }
}
