import 'dart:typed_data';

/// Canned `0x21`–`0x2A` **Value** payloads（RST 形态 + 动态时间轴）。
///
/// 全量同步默认 **不下发睡眠数据**：`0x40` 仍保留 type `0x02` 且 count=`0`；
/// 其余类型 2 条记录时间分别为「现在 −1h」「现在 −30min」，便于 Demo 按「今天」查库。
abstract final class WsSimFixtures {
  /// 为 `true` 时在 `0x40` 将睡眠 count 置为 2 并下发 `0x22`；默认只报 0 条、不发帧。
  static const bool includeSleepInFullSync = false;

  static const dataActivity = [
    0x12, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x04, 0xB0, 0x03, 0x52, 0x01, 0xC8,
    0x62, 0x0F, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x6A, 0xCC, 0x9E, 0x0C, 0x01, 0x2C,
    0x00, 0xD2, 0x00, 0x70, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ];

  static const dataSleep = [
    0x08, 0x00, 0x02, 0x6A, 0xCC, 0x3F, 0x20, 0x01, 0x00, 0x00, 0x00, 0x6A, 0xCC,
    0x54, 0x38, 0x02, 0x00, 0x00, 0x00,
  ];

  static const dataHeartRate = [
    0x05, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x48, 0x6A, 0xCC, 0x9A, 0xC4, 0x4B,
  ];

  static const dataBloodPressure = [
    0x06, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x78, 0x50, 0x6A, 0xCC, 0xCB, 0xC0,
    0x76, 0x4E,
  ];

  static const dataBloodOxygen = [
    0x07, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x62, 0x63, 0x60, 0x6A, 0xCC, 0xCB,
    0xC0, 0x61, 0xFF, 0xFF,
  ];

  static const dataHrv = [
    0x06, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x00, 0x2D, 0x6A, 0xCC, 0xCB, 0xC0,
    0x00, 0x34,
  ];

  static const dataPressure = [
    0x05, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x23, 0x6A, 0xCC, 0xCB, 0xC0, 0x3E,
  ];

  static const dataTemperature = [
    0x0A, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x0E, 0x44, 0x0C, 0xEE, 0x00, 0x03,
    0x6A, 0xCC, 0xCB, 0xC0, 0x80, 0x00, 0x0B, 0xB8, 0xFF, 0x00,
  ];

  static const dataBloodGlucose = [
    0x06, 0x00, 0x02, 0x6A, 0xCC, 0x9A, 0x88, 0x00, 0x38, 0x6A, 0xCC, 0xCB, 0xC0,
    0x00, 0x48,
  ];

  static const dataSport = [
    0x1F, 0x00, 0x01, 0x00, 0x00, 0x00, 0x2A, 0x6A, 0xCC, 0x9A, 0x88, 0x6A, 0xCC,
    0xA1, 0x90, 0x01, 0x07, 0x08, 0x07, 0x44, 0x00, 0x00, 0x11, 0x94, 0x00, 0x00,
    0x14, 0x50, 0x00, 0x00, 0x0C, 0x80, 0x91, 0x01,
  ];

  /// RST 模板里第一条/第二条记录的基准 epoch（秒），用于映射帧内其它同系列时间戳。
  static const templateEpochOlder = 0x6ACC9A88;
  static const templateEpochNewer = 0x6ACC9AC4;
  static const _epochTemplateLo = 0x6ACC0000;
  static const _epochTemplateHi = 0x6ACDFFFF;

  static ({int older, int newer}) liveEpochSeconds({DateTime? now}) {
    final n = now ?? DateTime.now();
    return (
      older: n.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      newer: n.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// 下发用 payload：指标与 RST 一致，时间戳相对「当前」滑动。
  static Uint8List liveBytes(List<int> template, {DateTime? now}) =>
      _shiftFrameToLive(Uint8List.fromList(template), liveEpochSeconds(now: now));

  static Uint8List buildTodayPayload({DateTime? now}) {
    final n = now ?? DateTime.now();
    final epochs = liveEpochSeconds(now: n);
    final dayStart =
        DateTime(n.year, n.month, n.day).millisecondsSinceEpoch ~/ 1000;
    final out = Uint8List(23);
    final data = ByteData.sublistView(out);
    data.setUint32(0, dayStart, Endian.little);
    data.setUint32(4, 5230, Endian.little);
    data.setUint32(8, 3650, Endian.little);
    data.setUint32(12, 2242, Endian.little);
    data.setUint16(16, 72, Endian.little);
    out[18] = 0x48;
    data.setUint32(19, epochs.newer, Endian.little);
    return out;
  }

  /// 全量 `0x40`：`0x01`…`0x0A` 固定顺序；睡眠条数由 [includeSleepInFullSync] 决定。
  static Uint8List syncStartMulti() {
    final plan = <(int type, int count)>[
      (0x01, 2),
      (0x02, includeSleepInFullSync ? 2 : 0),
      (0x03, 2),
      (0x04, 2),
      (0x05, 2),
      (0x06, 2),
      (0x07, 2),
      (0x08, 2),
      (0x09, 2),
      (0x0A, 1),
    ];
    final out = Uint8List(plan.length * 3);
    var o = 0;
    for (final (type, count) in plan) {
      out[o++] = type;
      out[o++] = (count >> 8) & 0xff;
      out[o++] = count & 0xff;
    }
    return out;
  }

  /// `0x41` 总 wire 条数 = `0x40` 各 count 之和（睡眠为 0 时不计入）。
  static int get totalWireRecords => includeSleepInFullSync ? 19 : 17;

  /// 单测 / codec 仍用 RST 原始字节。
  static Uint8List bytes(List<int> value) => Uint8List.fromList(value);

  static Uint8List _shiftFrameToLive(
    Uint8List frame,
    ({int older, int newer}) epochs,
  ) {
    if (frame.length < 3) return frame;
    final recordLen = frame[0];
    final count = (frame[1] << 8) | frame[2];
    final out = Uint8List.fromList(frame);
    final view = ByteData.sublistView(out);
    var offset = 3;
    final templateOlder = templateEpochOlder;
    final templateNewer = templateEpochNewer;
    for (var i = 0; i < count; i++) {
      final live = i == 0 ? epochs.older : epochs.newer;
      if (recordLen == 0x1F) {
        view.setUint32(offset + 4, live, Endian.little);
        view.setUint32(offset + 8, epochs.newer, Endian.little);
      } else {
        view.setUint32(offset, live, Endian.little);
      }
      final recordEnd = offset + recordLen;
      for (var p = offset + 4; p <= recordEnd - 4; p++) {
        final u = view.getUint32(p, Endian.little);
        if (u >= _epochTemplateLo && u <= _epochTemplateHi) {
          if (u == templateOlder || u < templateNewer) {
            view.setUint32(p, epochs.older, Endian.little);
          } else {
            view.setUint32(p, epochs.newer, Endian.little);
          }
        }
      }
      offset += recordLen;
    }
    for (var p = 3; p <= out.length - 4; p++) {
      final u = view.getUint32(p, Endian.little);
      if (u < _epochTemplateLo || u > _epochTemplateHi) continue;
      if (u == templateOlder) {
        view.setUint32(p, epochs.older, Endian.little);
      } else {
        view.setUint32(p, epochs.newer, Endian.little);
      }
    }
    return out;
  }
}
