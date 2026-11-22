import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/measure/ws_measure_spot_codec.dart';
import 'package:ws_watch_sdk/src/notification/ws_notification_models.dart';
import 'package:ws_watch_sdk/src/settings/ws_setting_codecs.dart';
import 'package:ws_watch_sdk/src/settings/ws_settings_models.dart';
import 'package:ws_watch_sdk/src/wire/ws_bind_command.dart';
import 'package:ws_watch_sdk/src/wire/ws_data_extra_codec.dart';
import 'package:ws_watch_sdk/src/wire/ws_notification_command.dart';

void main() {
  test('0x02 typed settings codecs use protocol layouts', () {
    const display = WSDisplayFormat(
      hour12: true,
      dayFirst: false,
      imperialDistance: false,
      pounds: true,
    );
    expect(WSSettingCodecs.displayFormat.encode(display), [1, 0, 0, 1]);

    const goals = WSActivityGoals(
      steps: 8000,
      caloriesKcal: 300,
      sleepMinutes: 480,
      distanceMeters: 5000,
      activeMinutes: 30,
    );
    expect(
      WSSettingCodecs.goals.encode(goals),
      [0, 0, 0x1f, 0x40, 1, 0x2c, 1, 0xe0, 0, 0, 0x13, 0x88, 0, 0x1e],
    );
  });

  test('0x03 super bind contains two padded 32-byte fields', () {
    final message = WSBindCommand.superBindRequest('user', 'secret');
    expect(message.key, WSBindCommand.keySuperBindRequest);
    expect(message.value, hasLength(64));
    expect(
        WSBindCommand.decodeUserIdWire(message.value.sublist(0, 32)), 'user');
    expect(WSBindCommand.decodeUserIdWire(message.value.sublist(32)), 'secret');
  });

  test('0x04 notification message matches big-endian layout', () {
    const item = WSAppNotification(
      id: 1,
      applicationType: 2,
      wallTimeSeconds: 0x6acc9a88,
      title: 'A',
      content: 'B',
    );
    final value = WSNotificationCommand.appNotification(item).value;
    expect(value.sublist(0, 9), [0, 0, 0, 1, 2, 0x6a, 0xcc, 0x9a, 0x88]);
    expect(value.sublist(9), [1, 0x41, 0, 1, 0x42]);
  });

  test('0x05 capability TLV and sport point decode', () {
    final caps = WSDataExtraCodec.decodeCapabilities(Uint8List.fromList([
      1,
      0,
      4,
      1,
      0x9a,
      1,
      0x72,
      3,
      0,
      1,
      60,
      6,
      0,
      1,
      3,
    ]));
    expect(caps.displayWidth, 410);
    expect(caps.displayHeight, 370);
    expect(caps.suggestedJpegQuality, 60);
    expect(caps.requestedFps, 3);
  });

  test('0x11 status and sport realtime are big-endian', () {
    final status = WSMeasureSpotCodec.decodeStatus(
      Uint8List.fromList([1, 3, 0, 0x6a, 0xcc, 0x9a, 0x88]),
    );
    expect(status.startedAtSeconds, 0x6acc9a88);

    final realtime = ByteData(23)
      ..setUint8(0, 1)
      ..setUint8(1, 1)
      ..setUint32(2, 0x6acc9a88)
      ..setUint32(6, 60)
      ..setUint8(10, 120)
      ..setUint32(11, 100)
      ..setUint32(15, 500)
      ..setUint32(19, 25);
    final snapshot = WSMeasureSpotCodec.decodeSportRealtime(
      realtime.buffer.asUint8List(),
    );
    expect(snapshot.startedAtSeconds, 0x6acc9a88);
    expect(snapshot.steps, 100);
  });

  test('0x11 temperature result keeps body and skin fields distinct', () {
    final result = WSMeasureSpotCodec.temperatureResult(Uint8List.fromList([
      0,
      0x6a,
      0xcc,
      0x9a,
      0xc4,
      0x0e,
      0x44,
      0x0c,
      0xee,
      0,
      3,
    ]));
    expect(result, isNotNull);
    expect(result!.bodyHundredthCelsius, 3652);
    expect(result.skinHundredthCelsius, 3310);
    expect(result.skinTemperature, 33.10);
  });
}
