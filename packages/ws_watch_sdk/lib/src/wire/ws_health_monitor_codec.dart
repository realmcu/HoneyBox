import 'dart:typed_data';

import '../measure/ws_measure_models.dart';
import 'ws_l2_message.dart';
import 'ws_settings_command.dart';

/// 0x02 自动监测 7B / 告警 10B 编解码。
abstract final class WSHealthMonitorCodec {
  static const int autoMonitorBodyLength = 7;
  static const int alarmBodyLength = 10;

  static const int keyHeartRateAuto = 0x40;
  static const int keyHeartRateAlarm = 0x41;
  static const int keyBloodPressureAuto = 0x48;
  static const int keyBloodSugarAuto = 0x4C;
  static const int keySpO2Auto = 0x50;
  static const int keySpO2Alarm = 0x51;
  static const int keyPressureAuto = 0x54;
  static const int keyTemperatureAuto = 0x58;
  static const int keyTemperatureUnit = 0x5A;
  static const int keyHeatStressAuto = 0x5C;

  static Uint8List encodeAutoMonitorBody(WSAutoMeasureSchedule schedule) {
    final data = ByteData(autoMonitorBodyLength);
    data.setUint8(0, schedule.enabled ? 0x01 : 0x00);
    data.setUint8(1, schedule.startHour);
    data.setUint8(2, schedule.startMinute);
    data.setUint8(3, schedule.endHour);
    data.setUint8(4, schedule.endMinute);
    data.setUint16(5, schedule.intervalMinutes);
    return data.buffer.asUint8List();
  }

  static WSAutoMeasureSchedule decodeAutoMonitorBody(Uint8List bytes) {
    if (bytes.length < autoMonitorBodyLength) {
      throw const FormatException('WS auto monitor payload too short');
    }
    final data = ByteData.sublistView(bytes, 0, autoMonitorBodyLength);
    return WSAutoMeasureSchedule(
      enabled: bytes[0] == 0x01,
      startHour: bytes[1],
      startMinute: bytes[2],
      endHour: bytes[3],
      endMinute: bytes[4],
      intervalMinutes: data.getUint16(5),
    );
  }

  static Uint8List encodeHeartRateHighAlarm(WSHeartRateHighAlarm alarm) {
    final body = ByteData(alarmBodyLength);
    body.setUint8(0, alarm.enabled ? 0x01 : 0x00);
    body.setUint16(1, alarm.thresholdBpm);
    body.setUint8(3, 0);
    body.setUint16(4, 0);
    body.setUint8(6, 0);
    body.setUint8(7, 0);
    body.setUint8(8, 0);
    body.setUint8(9, 0);
    return body.buffer.asUint8List();
  }

  static WSHeartRateHighAlarm decodeHeartRateHighAlarm(Uint8List bytes) {
    if (bytes.length < alarmBodyLength) {
      throw const FormatException('WS heart rate alarm payload too short');
    }
    final data = ByteData.sublistView(bytes, 0, alarmBodyLength);
    return WSHeartRateHighAlarm(
      enabled: bytes[0] == 0x01,
      thresholdBpm: data.getUint16(1),
    );
  }

  static Uint8List encodeSpO2LowAlarm(WSSpO2LowAlarm alarm) {
    final body = ByteData(alarmBodyLength);
    body.setUint8(0, 0);
    body.setUint16(1, 0);
    body.setUint8(3, alarm.enabled ? 0x01 : 0x00);
    body.setUint16(4, alarm.thresholdPercent);
    body.setUint8(6, 0);
    body.setUint8(7, 0);
    body.setUint8(8, 0);
    body.setUint8(9, 0);
    return body.buffer.asUint8List();
  }

  static WSSpO2LowAlarm decodeSpO2LowAlarm(Uint8List bytes) {
    if (bytes.length < alarmBodyLength) {
      throw const FormatException('WS SpO2 alarm payload too short');
    }
    final data = ByteData.sublistView(bytes, 0, alarmBodyLength);
    return WSSpO2LowAlarm(
      enabled: bytes[3] == 0x01,
      thresholdPercent: data.getUint16(4) & 0xFF,
    );
  }

  static Uint8List encodeTemperatureUnit(bool celsius) =>
      Uint8List.fromList([celsius ? 0x00 : 0x01]);

  static bool decodeTemperatureUnitCelsius(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('WS temperature unit empty');
    }
    return bytes[0] == 0x00;
  }

  static Uint8List extractSettingBody(WSL2Message reply) {
    if (reply.value.isEmpty ||
        reply.value[0] != WSSettingsCommand.opcodeReadReply) {
      throw FormatException(
        'unexpected settings read reply key=0x${reply.key.toRadixString(16)}',
      );
    }
    return Uint8List.sublistView(reply.value, 1);
  }
}
