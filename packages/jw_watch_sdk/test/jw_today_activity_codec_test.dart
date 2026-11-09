import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/src/connection/jw_protocol.dart';
import 'package:jw_watch_sdk/src/today/jw_today_activity_codec.dart';

void main() {
  test('query today activity uses HL 0x05 / 0x0B → 0x0C keys', () {
    expect(
      encodeJWRequest(JWProtocolCommands.queryTodayActivitySummary),
      Uint8List.fromList([5, 0, 0x0b, 0, 0]),
    );
  });

  test('decodes 17-byte ApplicationLayerTodayAdjustPacket layout', () {
    final data = Uint8List.fromList([
      12, // offset
      0x00,
      0x13,
      0x58, // 4952 steps
      0x00,
      0x03,
      0x6A, // 874 cal
      0x00,
      0x0E,
      0x10, // 3600 m
      0x00,
      0x64, // recent steps 100
      0x00,
      0x00,
      0x32, // recent cal 50
      0x01,
      0x2C, // recent dist 300
    ]);
    final summary = decodeJWTodayActivitySummary(data);
    expect(summary.slotOffset, 12);
    expect(summary.steps, 4952);
    expect(summary.caloriesCal, 874);
    expect(summary.distanceMeters, 3600);
    expect(summary.recentSteps, 100);
    expect(summary.recentCaloriesCal, 50);
    expect(summary.recentDistanceMeters, 300);
    expect(summary.caloriesKcal, closeTo(0.874, 0.001));
    expect(summary.distanceKm, closeTo(3.6, 0.001));
  });

  test('decodes legacy 16-byte layout', () {
    final data = Uint8List.fromList([
      0,
      0,
      0,
      0x64, // 100 steps
      0,
      0,
      0xC8, // 200 cal
      0,
      0x03,
      0xE8, // 1000 m
      0,
      0x0A, // recent steps 10
      0,
      0x14, // recent cal 20
      0,
      0x32, // recent dist 50
    ]);
    final summary = decodeJWTodayActivitySummary(data);
    expect(summary.steps, 100);
    expect(summary.recentCaloriesCal, 20);
    expect(summary.recentDistanceMeters, 50);
  });
}
