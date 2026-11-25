import 'dart:typed_data';

import 'ble_cmd_registry.dart';

/// One device notification on CMD 0x14.
class WatchRecordResponse {
  const WatchRecordResponse(this.key, this.value);

  final int key;
  final Uint8List value;
}

abstract final class WatchRecordProtocol {
  static const int startKey = BleCmdWatchRecordKey.start;
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
    if (value.length < 10 || value[0] != 0x01) {
      return '录音已启动';
    }
    final sampleRate =
        (value[1] << 24) | (value[2] << 16) | (value[3] << 8) | value[4];
    final channels = value[5] == 1 ? '单声道' : '${value[5]} 声道';
    final frameMs = value[6];
    final bitrate = (value[7] << 8) | value[8];
    final framesPerPacket = value[9];
    return 'Opus $sampleRate Hz · $channels · ${frameMs}ms\n'
        '$bitrate bps · $framesPerPacket 帧/包';
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
