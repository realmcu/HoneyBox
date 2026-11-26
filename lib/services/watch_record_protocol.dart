import 'dart:typed_data';

import 'ble_cmd_registry.dart';

/// One device notification on CMD 0x14.
class WatchRecordResponse {
  const WatchRecordResponse(this.key, this.value);

  final int key;
  final Uint8List value;
}

class WatchRecordData {
  const WatchRecordData({
    required this.seq,
    required this.timestamp,
    required this.frames,
  });

  final int seq;
  final int timestamp;
  final List<Uint8List> frames;

  int get byteLength => frames.fold(0, (sum, frame) => sum + frame.length);
}

abstract final class WatchRecordProtocol {
  static const int startKey = BleCmdWatchRecordKey.start;
  static const int dataKey = BleCmdWatchRecordKey.data;
  static const int stopKey = BleCmdWatchRecordKey.stop;

  static Uint8List buildRequest() => _build(BleCmdWatchRecordKey.recordRequest);

  static Uint8List buildCancelRequest() =>
      _build(BleCmdWatchRecordKey.cancelRequest);

  static Uint8List _build(int key) => Uint8List.fromList([
        BleCmd.watchRecord,
        0x00,
        key,
        0x00,
        0x00,
      ]);

  static WatchRecordResponse? parseResponse(Uint8List frame) {
    if (frame.length < 5 ||
        frame[0] != BleCmd.watchRecord ||
        frame[1] != 0x00) {
      return null;
    }
    final valueLength = (frame[3] << 8) | frame[4];
    if (frame.length != 5 + valueLength) return null;
    return WatchRecordResponse(
      frame[2],
      Uint8List.fromList(frame.sublist(5)),
    );
  }

  static String decodeStart(Uint8List value) {
    if (value.length < 10) {
      return '录音已启动';
    }
    final sampleRate =
        (value[1] << 24) | (value[2] << 16) | (value[3] << 8) | value[4];
    final channels = value[5] == 1 ? '单声道' : '${value[5]} 声道';
    final frameMs = value[6];
    if (value[0] == 0x02) {
      final bits = value.length >= 11 ? value[10] : 16;
      final frameBytes = value.length >= 13
          ? (value[11] << 8) | value[12]
          : sampleRate * value[5] * bits ~/ 8 * frameMs ~/ 1000;
      return 'PCM $sampleRate Hz · $channels · $bits bit\n'
          '${frameMs}ms · $frameBytes B/帧';
    }
    if (value[0] != 0x01) return '录音已启动';
    final bitrate = (value[7] << 8) | value[8];
    final framesPerPacket = value[9];
    return 'Opus $sampleRate Hz · $channels · ${frameMs}ms\n'
        '$bitrate bps · $framesPerPacket 帧/包';
  }

  static WatchRecordData? parseData(WatchRecordResponse response) {
    if (response.key != dataKey || response.value.length < 8) return null;
    final value = response.value;
    final seq = (value[0] << 8) | value[1];
    final timestamp =
        (value[2] << 24) | (value[3] << 16) | (value[4] << 8) | value[5];
    final frameCount = value[6];
    if (frameCount == 0) return null;

    var offset = 8;
    final frames = <Uint8List>[];
    for (var i = 0; i < frameCount; i++) {
      if (offset + 2 > value.length) return null;
      final frameLength = (value[offset] << 8) | value[offset + 1];
      offset += 2;
      if (frameLength == 0 || offset + frameLength > value.length) return null;
      frames.add(Uint8List.fromList(value.sublist(offset, offset + frameLength)));
      offset += frameLength;
    }
    if (offset != value.length) return null;
    return WatchRecordData(seq: seq, timestamp: timestamp, frames: frames);
  }

  static String decodeStop(Uint8List value) {
    if (value.length != 1) return '录音已停止';
    return switch (value[0]) {
      0x00 => '录音已完成',
      0x01 => '手机已取消录音',
      0x02 => '音频异常停止',
      0x03 => '传输异常停止',
      0x04 => '手表拒绝录音请求',
      _ => '录音已停止（原因 0x${value[0].toRadixString(16)}）',
    };
  }
}
