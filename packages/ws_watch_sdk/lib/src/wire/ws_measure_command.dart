import 'dart:typed_data';

import 'ws_l2_message.dart';

/// Command `0x11` spot measure ([WS protocol 0x11-measurement.rst]).
abstract final class WSMeasureCommand {
  static const int command = 0x11;
  static const int version = 0;

  static const int keyQueryStatus = 0x01;
  static const int keyStatusReply = 0x02;

  static const int resultStarted = 0x00;
  static const int resultBusy = 0x01;

  static const int dataTypeHeartRate = 0x03;
  static const int dataTypeBloodPressure = 0x04;
  static const int dataTypeSpO2 = 0x05;
  static const int dataTypeHrv = 0x06;
  static const int dataTypePressure = 0x07;
  static const int dataTypeTemperature = 0x08;
  static const int dataTypeBloodGlucose = 0x09;

  static const int keySportStart = 0x60;
  static const int keySportStartReply = 0x61;
  static const int keySportControl = 0x62;
  static const int keySportRealtime = 0x63;
  static const int keySportEnd = 0x64;
  static const int keySportModesQuery = 0x65;
  static const int keySportModesReply = 0x66;
  static const int keySportStateQuery = 0x67;
  static const int keySportStateReply = 0x68;
  static const int keySportSubscribe = 0x69;
  static const int keySportUnsubscribe = 0x6A;

  static WSL2Message querySpotStatus() => WSL2Message(
        command: command,
        version: version,
        key: keyQueryStatus,
        value: Uint8List(0),
      );

  static bool isStatusReply(WSL2Message message) =>
      message.command == command && message.key == keyStatusReply;

  static WSL2Message _message(int key, [List<int> value = const []]) =>
      WSL2Message(
        command: command,
        version: version,
        key: key,
        value: Uint8List.fromList(value),
      );

  static WSL2Message sportStart(int mode) => _message(keySportStart, [mode]);
  static WSL2Message sportControl(int action) =>
      _message(keySportControl, [action]);
  static WSL2Message sportModesQuery() => _message(keySportModesQuery);
  static WSL2Message sportStateQuery() => _message(keySportStateQuery);
  static WSL2Message sportSubscribe() => _message(keySportSubscribe);
  static WSL2Message sportUnsubscribe() => _message(keySportUnsubscribe);
}

/// 点测五连：开始 / 开始回应 / 停止 / 实时 / 结果。
final class WSSpotMeasureLane {
  const WSSpotMeasureLane({
    required this.start,
    required this.startReply,
    required this.stop,
    required this.realtime,
    required this.result,
    required this.dataTypeCode,
  });

  final int start;
  final int startReply;
  final int stop;
  final int realtime;
  final int result;
  final int dataTypeCode;

  WSL2Message startMessage() => WSL2Message(
        command: WSMeasureCommand.command,
        version: WSMeasureCommand.version,
        key: start,
        value: Uint8List(0),
      );

  WSL2Message stopMessage() => WSL2Message(
        command: WSMeasureCommand.command,
        version: WSMeasureCommand.version,
        key: stop,
        value: Uint8List(0),
      );

  bool isStartReply(WSL2Message message) =>
      message.command == WSMeasureCommand.command && message.key == startReply;

  bool isStartSuccess(WSL2Message message) =>
      isStartReply(message) &&
      message.value.length == 1 &&
      message.value[0] == WSMeasureCommand.resultStarted;
}

abstract final class WSSpotMeasureLanes {
  static const heartRate = WSSpotMeasureLane(
    start: 0x03,
    startReply: 0x04,
    stop: 0x05,
    realtime: 0x06,
    result: 0x07,
    dataTypeCode: 0x03,
  );

  static const bloodPressure = WSSpotMeasureLane(
    start: 0x08,
    startReply: 0x09,
    stop: 0x0A,
    realtime: 0x0B,
    result: 0x0C,
    dataTypeCode: 0x04,
  );

  static const bloodOxygen = WSSpotMeasureLane(
    start: 0x0D,
    startReply: 0x0E,
    stop: 0x0F,
    realtime: 0x10,
    result: 0x11,
    dataTypeCode: 0x05,
  );

  static const hrv = WSSpotMeasureLane(
    start: 0x12,
    startReply: 0x13,
    stop: 0x14,
    realtime: 0x15,
    result: 0x16,
    dataTypeCode: 0x06,
  );

  static const pressure = WSSpotMeasureLane(
    start: 0x17,
    startReply: 0x18,
    stop: 0x19,
    realtime: 0x1A,
    result: 0x1B,
    dataTypeCode: 0x07,
  );

  static const temperature = WSSpotMeasureLane(
    start: 0x1C,
    startReply: 0x1D,
    stop: 0x1E,
    realtime: 0x1F,
    result: 0x20,
    dataTypeCode: 0x08,
  );

  static const bloodGlucose = WSSpotMeasureLane(
    start: 0x21,
    startReply: 0x22,
    stop: 0x23,
    realtime: 0x24,
    result: 0x25,
    dataTypeCode: 0x09,
  );

  static const continuousHeartRate = WSSpotMeasureLane(
    start: 0x26,
    startReply: 0x27,
    stop: 0x28,
    realtime: 0x29,
    result: 0x2A,
    dataTypeCode: 0x03,
  );

  static const all = [
    heartRate,
    bloodPressure,
    bloodOxygen,
    hrv,
    pressure,
    temperature,
    bloodGlucose,
    continuousHeartRate,
  ];

  static WSSpotMeasureLane? laneForKey(int key) {
    for (final lane in all) {
      if (lane.start == key ||
          lane.stop == key ||
          lane.startReply == key ||
          lane.realtime == key ||
          lane.result == key) {
        return lane;
      }
    }
    return null;
  }
}
