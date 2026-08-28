import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ebadge/ebadge_demo_presets.dart';
import 'package:honeybox/pages/ebadge/ebadge_stream_demo_frames.dart';
import 'package:honeybox/services/image_jpeg.dart';

/// 从裸 JFIF 里读 SOF0/SOF2 的宽高。§6.2 的 14 字节流头**不带宽高**,设备只能按
/// JPEG 自身的 SOF 解 —— 所以「帧是 466×466」这件事必须在字节里成立,光对 Dart
/// 常量断言等于什么都没测。
({int width, int height})? _sofSize(Uint8List jpeg) {
  var i = 2; // 跳过 SOI
  while (i + 3 < jpeg.length) {
    if (jpeg[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = jpeg[i + 1];
    if (marker == 0xD8 ||
        marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final len = (jpeg[i + 2] << 8) | jpeg[i + 3];
    // SOF0 baseline / SOF1 / SOF2 progressive
    if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
      final h = (jpeg[i + 5] << 8) | jpeg[i + 6];
      final w = (jpeg[i + 7] << 8) | jpeg[i + 8];
      return (width: w, height: h);
    }
    if (marker == 0xDA) return null; // 到 SOS 还没见到 SOF
    i += 2 + len;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('尺寸与 Wi-Fi 传图档位共用同一个常量', () {
    // 两条链路发的图尺寸无谓地不一样,排查时就多一个「是不是尺寸的问题」要排除。
    expect(EBadgeStreamDemoFrames.width, kEBadgeDemoImageSize);
    expect(EBadgeStreamDemoFrames.height, kEBadgeDemoImageSize);
    expect(EBadgeStreamDemoFrames.width, 466);
  });

  // at() 是同步的,而编码是异步的 —— 没预热就取帧只能返回 null。这条钉住「返回
  // null 而不是抛」:ticker 里抛异常会把整个会话打断,而跳过一 tick 是无害的。
  test('未 prepare 时 at() 返回 null,不抛', () {
    if (!EBadgeStreamDemoFrames.ready) {
      expect(EBadgeStreamDemoFrames.at(0), isNull);
    }
  });

  test('prepare 后四帧都是 466×466 的裸 JFIF', () async {
    await EBadgeStreamDemoFrames.prepare();
    expect(EBadgeStreamDemoFrames.ready, isTrue);

    for (var i = 0; i < EBadgeStreamDemoFrames.count; i++) {
      final f = EBadgeStreamDemoFrames.at(i);
      expect(f, isNotNull, reason: '第 $i 帧缺失');

      // 推流发的是裸 JFIF,不能带 §5 传图那个 16B 设备头 —— §6.2 的 size 是
      // payload 长度,多 16 字节设备就解不出图。
      expect(isImageJpegBin(f!), isFalse, reason: '第 $i 帧不该带 16B 头');
      expect(f.sublist(0, 2), orderedEquals(<int>[0xFF, 0xD8]),
          reason: '第 $i 帧不是以 SOI 开头');

      final size = _sofSize(f);
      expect(size, isNotNull, reason: '第 $i 帧读不到 SOF 尺寸');
      expect(size!.width, 466, reason: '第 $i 帧 SOF 宽度');
      expect(size.height, 466, reason: '第 $i 帧 SOF 高度');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  // 四格轮转的意义就在于「帧与帧不同」:丢帧/卡帧靠画面变化辨认。真有两帧编出来
  // 一样,设备上看到的就是不动的画面,而那正是我们要判断的故障现象本身。
  test('四帧互不相同 —— 否则卡帧/丢帧无从辨认', () async {
    await EBadgeStreamDemoFrames.prepare();
    final seen = <String>{};
    for (var i = 0; i < EBadgeStreamDemoFrames.count; i++) {
      final f = EBadgeStreamDemoFrames.at(i)!;
      expect(seen.add(f.join(',')), isTrue, reason: '第 $i 帧与前面某帧字节相同');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('at() 自动取模,越界不抛', () async {
    await EBadgeStreamDemoFrames.prepare();
    const n = EBadgeStreamDemoFrames.count;
    expect(EBadgeStreamDemoFrames.at(n),
        orderedEquals(EBadgeStreamDemoFrames.at(0)!));
    expect(EBadgeStreamDemoFrames.at(n * 3 + 2),
        orderedEquals(EBadgeStreamDemoFrames.at(2)!));
  }, timeout: const Timeout(Duration(minutes: 2)));

  // 10 fps 下的码率上限。帧太大 TCP 就成了瓶颈,推流卡顿会被误读成协议时序问题 ——
  // 而这条链路存在的意义恰恰是把故障归因到协议本身。
  test('单帧体积够小,10 fps 不会让 TCP 成为瓶颈', () async {
    await EBadgeStreamDemoFrames.prepare();
    for (var i = 0; i < EBadgeStreamDemoFrames.count; i++) {
      final n = EBadgeStreamDemoFrames.at(i)!.length;
      expect(n, lessThan(30 * 1024),
          reason: '第 $i 帧 $n B —— 10 fps 下超过 300 KB/s');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('prepare 可重复调用,不会重编', () async {
    final a = await EBadgeStreamDemoFrames.prepare();
    final b = await EBadgeStreamDemoFrames.prepare();
    expect(identical(a, b), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
