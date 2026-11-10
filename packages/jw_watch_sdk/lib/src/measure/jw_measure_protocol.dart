import 'dart:typed_data';

import '../connection/jw_protocol.dart';
import 'jw_measure_models.dart';

/// HL `cmd 0x05` / `0x08` sport & multiple commands for measure control.
abstract final class JWMeasureProtocol {
  static const sportCommand = 5;
  static const _sport = sportCommand;
  static const _multiple = 8;
  static const heartRateAutoMeasureRspKey = 0x12;
  static const heartRateIntervalOptionsRspKey = 0x18;
  static const deviceSyncSwitchRspKey = 0x1d;

  static JWProtocolRequest readHeartRateAutoMeasure() =>
      const JWProtocolRequest(command: _sport, key: 0x11, responseKey: 0x12);

  /// Settings `0x3F` request; interval kinds arrive on sport `0x18`.
  static JWProtocolRequest readHeartRateIntervalOptions() =>
      const JWProtocolRequest(
        command: 2,
        key: 0x3f,
        responseKey: heartRateIntervalOptionsRspKey,
        responseCommand: _sport,
      );

  static JWProtocolRequest setHeartRateAutoMeasure(Uint8List value) =>
      JWProtocolRequest(
          command: _sport, key: 0x0e, responseKey: null, value: value);

  static JWProtocolRequest readSpO2AutoMeasure() =>
      const JWProtocolRequest(command: _sport, key: 0x34, responseKey: 0x35);

  static JWProtocolRequest setSpO2AutoMeasure(Uint8List value) =>
      JWProtocolRequest(
          command: _sport, key: 0x33, responseKey: null, value: value);

  static JWProtocolRequest readBloodPressureAutoMeasure() =>
      const JWProtocolRequest(command: _sport, key: 0x3e, responseKey: 0x3f);

  static JWProtocolRequest setBloodPressureAutoMeasure(Uint8List value) =>
      JWProtocolRequest(
          command: _sport, key: 0x3d, responseKey: null, value: value);

  static JWProtocolRequest readBloodSugarAutoMeasure() =>
      const JWProtocolRequest(command: _sport, key: 0x44, responseKey: 0x45);

  static JWProtocolRequest setBloodSugarAutoMeasure(Uint8List value) =>
      JWProtocolRequest(
          command: _sport, key: 0x43, responseKey: null, value: value);

  static JWProtocolRequest readTemperatureControl() =>
      const JWProtocolRequest(command: _sport, key: 0x23, responseKey: 0x24);

  static JWProtocolRequest setTemperatureControl(Uint8List value) =>
      JWProtocolRequest(
          command: _multiple, key: 0x22, responseKey: null, value: value);

  static JWProtocolRequest setPressureAutoMeasure(Uint8List value) =>
      JWProtocolRequest(
          command: _sport, key: 0x4f, responseKey: null, value: value);

  static JWProtocolRequest setHeartRateSpotMeasure(bool enable) =>
      JWProtocolRequest(
        command: _sport,
        key: 0x0d,
        responseKey: null,
        value: Uint8List.fromList([enable ? 1 : 0]),
      );

  static JWProtocolRequest setBloodPressureSpotMeasure(bool enable) =>
      JWProtocolRequest(
        command: _sport,
        key: 0x14,
        responseKey: null,
        value: Uint8List.fromList([enable ? 1 : 0]),
      );

  static JWProtocolRequest setSpO2SpotMeasure(bool enable) =>
      JWProtocolRequest(
        command: _sport,
        key: 0x2d,
        responseKey: null,
        value: Uint8List.fromList([enable ? 1 : 0]),
      );

  static JWProtocolRequest checkSpO2SpotMeasure() => JWProtocolRequest(
      command: _sport,
      key: 0x2d,
      responseKey: null,
      value: Uint8List.fromList([0x02]));

  static JWProtocolRequest setTemperatureSpotMeasure(bool enable) =>
      JWProtocolRequest(
        command: _sport,
        key: 0x20,
        responseKey: null,
        value: Uint8List.fromList([enable ? 1 : 0]),
      );

  static JWProtocolRequest checkTemperatureSpotMeasure() => JWProtocolRequest(
      command: _sport,
      key: 0x20,
      responseKey: null,
      value: Uint8List.fromList([0x02]));

  static JWProtocolRequest setBloodSugarSpotMeasure(bool enable) =>
      JWProtocolRequest(
        command: _sport,
        key: 0x41,
        responseKey: null,
        value: Uint8List.fromList([enable ? 1 : 0]),
      );

  static Uint8List encodeAutoMeasure(JWAutoMeasureConfig config) =>
      Uint8List.fromList([
        config.enabled ? 1 : 0,
        config.intervalMinutes & 0xff,
      ]);

  static Uint8List encodeTemperatureControl(JWTemperatureControlSetting setting) {
    final flags = (setting.enabled ? 0x01 : 0) |
        (setting.adjust ? 0x02 : 0) |
        (setting.celsius ? 0 : 0x04);
    return Uint8List.fromList([0, 0, 0, flags]);
  }

  static Uint8List encodeContinuousMonitoringSubCommand(int sub, bool enable) =>
      Uint8List.fromList([sub & 0xff, enable ? 1 : 0, 0]);
}
