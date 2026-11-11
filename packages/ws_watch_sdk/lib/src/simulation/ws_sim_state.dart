import 'dart:typed_data';

/// Cross-connection simulator device state (W5.2).
final class WsSimWatchState {
  String? boundUserId;
  int language = 1;
  int phoneSystem = 2;

  /// Canned `0x23` payload from HoneyProtocol example (2 heart-rate points).
  Uint8List heartRateDataFrame = Uint8List.fromList([
    0x05,
    0x00,
    0x02,
    0x6A,
    0xCC,
    0x9A,
    0x88,
    0x48,
    0x6A,
    0xCC,
    0x9A,
    0xC4,
    0x4B,
  ]);

  bool historyBusy = false;

  int batteryPercent = 75;
  int batteryCharging = 0;

  bool heartRateSpotActive = false;

  /// Canned `0x61` payload from HoneyProtocol example (23B).
  Uint8List todayPayload = Uint8List.fromList([
    0x6A, 0xCC, 0x9A, 0xA1,
    0x00, 0x00, 0x14, 0x6E,
    0x00, 0x00, 0x0E, 0x42,
    0x00, 0x00, 0x07, 0x48,
    0x00, 0x2A,
    0x48,
    0x6A, 0xCC, 0x9A, 0x10,
  ]);
}
