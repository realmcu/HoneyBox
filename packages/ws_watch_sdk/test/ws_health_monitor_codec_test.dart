import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/wire/ws_health_monitor_codec.dart';
import 'package:ws_watch_sdk/src/wire/ws_l2_message.dart';
import 'package:ws_watch_sdk/src/wire/ws_settings_command.dart';

void main() {
  test('auto monitor round-trip matches protocol example', () {
    const schedule = WSAutoMeasureSchedule(
      enabled: true,
      startHour: 0,
      startMinute: 0,
      endHour: 0,
      endMinute: 0,
      intervalMinutes: 10,
    );
    final body = WSHealthMonitorCodec.encodeAutoMonitorBody(schedule);
    expect(body, [0x01, 0, 0, 0, 0, 0, 0x0A]);
    final decoded = WSHealthMonitorCodec.decodeAutoMonitorBody(body);
    expect(decoded.enabled, isTrue);
    expect(decoded.intervalMinutes, 10);
    expect(decoded.isAllDay, isTrue);
  });

  test('heart rate high alarm encode', () {
    const alarm = WSHeartRateHighAlarm(enabled: true, thresholdBpm: 120);
    final body = WSHealthMonitorCodec.encodeHeartRateHighAlarm(alarm);
    final decoded = WSHealthMonitorCodec.decodeHeartRateHighAlarm(body);
    expect(decoded.enabled, isTrue);
    expect(decoded.thresholdBpm, 120);
  });

  test('settings read reply extracts 7B body', () {
    final readReply = WSL2Message(
      command: WSSettingsCommand.command,
      version: WSSettingsCommand.version,
      key: WSHealthMonitorCodec.keyHeartRateAuto,
      value: Uint8List.fromList([
        WSSettingsCommand.opcodeReadReply,
        0x01,
        0,
        0,
        0,
        0,
        0,
        0x0A,
      ]),
    );
    final extracted = WSHealthMonitorCodec.extractSettingBody(readReply);
    expect(
      WSHealthMonitorCodec.decodeAutoMonitorBody(extracted).intervalMinutes,
      10,
    );
  });
}
