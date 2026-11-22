import 'dart:typed_data';

import '../data/ws_data_models.dart';
import 'ws_binary.dart';
import 'ws_data_command.dart';
import 'ws_l2_message.dart';

abstract final class WSDataExtraCodec {
  static WSDeviceDataCapabilities decodeCapabilities(Uint8List value) {
    int? width, height, maxFrame, quality, features, maxChunk, fps;
    final unknown = <int, Uint8List>{};
    var offset = 0;
    while (offset < value.length) {
      if (value.length - offset < 3)
        throw const FormatException('truncated capability TLV');
      final id = value[offset];
      final len = WSBinary.readU16(value, offset + 1);
      offset += 3;
      if (offset + len > value.length)
        throw const FormatException('capability TLV length overflow');
      final data = Uint8List.sublistView(value, offset, offset + len);
      switch (id) {
        case 0x01 when len == 4:
          width = WSBinary.readU16(data, 0);
          height = WSBinary.readU16(data, 2);
        case 0x02 when len == 4:
          maxFrame = WSBinary.readU32(data, 0);
        case 0x03 when len == 1:
          quality = data[0];
        case 0x04 when len == 4:
          features = WSBinary.readU32(data, 0);
        case 0x05 when len == 2:
          maxChunk = WSBinary.readU16(data, 0);
        case 0x06 when len == 1:
          fps = data[0];
        default:
          unknown[id] = Uint8List.fromList(data);
      }
      offset += len;
    }
    return WSDeviceDataCapabilities(
      displayWidth: width,
      displayHeight: height,
      maxCompressedFrameBytes: maxFrame,
      suggestedJpegQuality: quality,
      featureBits: features,
      maxChunkBytes: maxChunk,
      requestedFps: fps,
      unknown: Map.unmodifiable(unknown),
    );
  }

  static WSL2Message todayConfig([WSTodayNotificationConfig? config]) {
    final value = config == null ? Uint8List(0) : encodeTodayConfig(config);
    return WSL2Message(
      command: WSDataCommand.command,
      version: WSDataCommand.version,
      key: WSDataCommand.keyTodayConfig,
      value: value,
    );
  }

  static Uint8List encodeTodayConfig(WSTodayNotificationConfig config) {
    WSBinary.requireRange(config.startHour, 0, 23, 'startHour');
    WSBinary.requireRange(config.endHour, 0, 23, 'endHour');
    WSBinary.requireRange(config.startMinute, 0, 59, 'startMinute');
    WSBinary.requireRange(config.endMinute, 0, 59, 'endMinute');
    WSBinary.requireRange(config.intervalMinutes, 1, 1440, 'intervalMinutes');
    return Uint8List.fromList([
      config.enabled ? 1 : 0,
      config.startHour,
      config.startMinute,
      config.endHour,
      config.endMinute,
      ...WSBinary.u16(config.intervalMinutes),
    ]);
  }

  static WSTodayNotificationConfig decodeTodayConfig(Uint8List value) {
    WSBinary.requireLength(value, 7, 'today config');
    return WSTodayNotificationConfig(
      enabled: value[0] == 1,
      startHour: value[1],
      startMinute: value[2],
      endHour: value[3],
      endMinute: value[4],
      intervalMinutes: WSBinary.readU16(value, 5),
    );
  }

  static WSTodayNotificationConfigResult decodeTodayConfigReply(
      Uint8List value) {
    WSBinary.requireLength(value, 8, 'today config reply');
    return WSTodayNotificationConfigResult(
      result: value[0],
      config: decodeTodayConfig(Uint8List.sublistView(value, 1)),
    );
  }

  static ({int sportId, bool more, List<WSSportDetailPoint> points})
      decodeSportDetailFrame(Uint8List value) {
    WSBinary.requireLength(value, 8, 'sport detail frame');
    final sportId = WSBinary.readU32(value, 0);
    final more = value[4] == 1;
    final itemLen = value[5];
    final count = WSBinary.readU16(value, 6);
    if (itemLen < 25 || value.length < 8 + itemLen * count) {
      throw const FormatException('invalid sport detail frame');
    }
    final points = <WSSportDetailPoint>[];
    for (var i = 0; i < count; i++) {
      final o = 8 + i * itemLen;
      final latitude = ByteData.sublistView(value).getInt32(o + 15);
      final longitude = ByteData.sublistView(value).getInt32(o + 19);
      final altitude = ByteData.sublistView(value).getInt16(o + 23);
      points.add(WSSportDetailPoint(
        elapsedSeconds: WSBinary.readU16(value, o),
        heartRateBpm: value[o + 2] == 0xff ? null : value[o + 2],
        steps: WSBinary.readU32(value, o + 3),
        distanceMeters: WSBinary.readU32(value, o + 7),
        caloriesTenthKcal: WSBinary.readU32(value, o + 11),
        latitudeE7: latitude == 0x7fffffff ? null : latitude,
        longitudeE7: longitude == 0x7fffffff ? null : longitude,
        altitudeMeters: altitude == -0x8000 ? null : altitude,
      ));
    }
    return (sportId: sportId, more: more, points: points);
  }
}
