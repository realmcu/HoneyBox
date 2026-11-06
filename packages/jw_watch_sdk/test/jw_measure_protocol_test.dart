import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/src/connection/jw_protocol.dart';
import 'package:jw_watch_sdk/src/measure/jw_measure_codec.dart';
import 'package:jw_watch_sdk/src/measure/jw_measure_models.dart';
import 'package:jw_watch_sdk/src/measure/jw_measure_protocol.dart';

void main() {
  test('measure sport commands match Android V2 FunctionPacketHelper keys', () {
    expect(
      encodeJWRequest(JWMeasureProtocol.readHeartRateAutoMeasure()),
      Uint8List.fromList([5, 0, 0x11, 0, 0]),
    );
    expect(
      encodeJWRequest(JWMeasureProtocol.setHeartRateAutoMeasure(
          JWMeasureProtocol.encodeAutoMeasure(
              const JWAutoMeasureConfig(enabled: true, intervalMinutes: 5)))),
      Uint8List.fromList([5, 0, 0x0e, 0, 2, 1, 5]),
    );
    expect(
      encodeJWRequest(JWMeasureProtocol.setHeartRateSpotMeasure(true)),
      Uint8List.fromList([5, 0, 0x0d, 0, 1, 1]),
    );
    expect(
      encodeJWRequest(JWMeasureProtocol.checkSpO2SpotMeasure()),
      Uint8List.fromList([5, 0, 0x2d, 0, 1, 2]),
    );
    expect(
      encodeJWRequest(JWMeasureProtocol.setTemperatureControl(
          JWMeasureProtocol.encodeTemperatureControl(
              const JWTemperatureControlSetting(
                  enabled: true, adjust: true, celsius: true)))),
      Uint8List.fromList([8, 0, 0x22, 0, 4, 0, 0, 0, 0x03]),
    );
    expect(
      encodeJWRequest(JWMeasureProtocol.setPressureAutoMeasure(
          JWMeasureProtocol.encodeContinuousMonitoringSubCommand(0x07, true))),
      Uint8List.fromList([5, 0, 0x4f, 0, 3, 0x07, 1, 0]),
    );
  });

  test('spot heart rate payload matches HeartRateDataHandler layout', () {
    // 2026-11-05 12:30:45, HR 72
    final data = Uint8List.fromList([
      0x6a,
      0x85,
      0,
      1,
      0x02,
      0xee,
      45,
      72,
    ]);
    final payload = decodeSpotHeartRatePayload(data, temperatureCapable: false);
    expect(payload, isNotNull);
    expect(payload!.heartRates.single.heartRate, 72);
    expect(payload.heartRates.single.time.hour, 12);
    expect(payload.heartRates.single.time.minute, 30);
    expect(payload.heartRates.single.time.second, 45);
  });

  test('spot blood glucose uses tenths in JWBloodGlucose.value', () {
    final data = Uint8List.fromList([
      0x6a,
      0x85,
      0x02,
      0xee,
      45,
      56,
      0,
      0,
    ]);
    final rows = decodeSpotBloodGlucose(data);
    expect(rows, isNotNull);
    expect(rows!.single.value, 56);
  });
}
