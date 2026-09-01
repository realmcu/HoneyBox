import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ebadge/ebadge_demo_presets.dart';
import 'package:honeybox/pages/ebadge/ebadge_stream_camera_source.dart';
import 'package:honeybox/services/encoder.dart';

/// 帧槽逻辑不碰平台通道,所以能直接测:构造时回调就挂在注入的 [EncoderService] 上,
/// 测试扮演原生侧调 `onFrame` 投帧。open()/close() 走 MethodChannel,不在这里测。
({EBadgeStreamCameraSource src, EncoderService enc}) _wire() {
  final enc = EncoderService();
  final src = EBadgeStreamCameraSource(encoder: enc);
  return (src: src, enc: enc);
}

Uint8List _frame(int seed, {int len = 32}) =>
    Uint8List.fromList(List<int>.generate(len, (i) => (seed + i) & 0xFF));

void main() {
  // 摄像头帧和传图档位、内置测试帧发的必须是同一个尺寸:§6.2 的 14B 流头**不带
  // 宽高**,设备只能按 JPEG 自身的 SOF 解,三条链路尺寸不一就多出一个待排除的变量。
  test('帧尺寸与传图档位共用同一个常量', () {
    expect(EBadgeStreamCameraSource.size, kEBadgeDemoImageSize);
    expect(EBadgeStreamCameraSource.size, 466);
  });

  // 关键一条:必须是 jpeg。H.264 是带 SPS/PPS 和帧间依赖的码流,单帧拿出来设备解
  // 不开 —— 而 §6.2 要求流头之后跟一个能独立解码的完整 JPEG。改成 h264/mvs1 会让
  // 设备收到一堆解不开的字节,现象是「有帧但不显示」,极难归因。
  test('编码配置是 466×466 的 JPEG，且分辨率随常量走', () {
    final cfg = EBadgeStreamCameraSource.debugConfigFor(10);
    expect(cfg.format, EncoderFormat.jpeg);
    expect(cfg.width, EBadgeStreamCameraSource.size);
    expect(cfg.height, EBadgeStreamCameraSource.size);
    expect(cfg.jpegQuality, EBadgeStreamCameraSource.quality);
    // 落地文件与协议无关,只会额外占 IO 并在停止时触发 AVI 封装。
    expect(cfg.recordToFile, isFalse);
  });

  // fps 要透到原生:原生据此节流 GL 回读,否则软件编码器跟着相机的自动曝光帧率跑,
  // 白编大量推不出去的帧。
  test('请求的 fps 透传到编码配置', () {
    expect(EBadgeStreamCameraSource.debugConfigFor(10).fps, 10);
    expect(EBadgeStreamCameraSource.debugConfigFor(3).fps, 3);
  });

  // 质量滑条的值必须真的进到下发给原生的 config 里。不然滑条动了、界面读数变了,
  // 而每帧还是按 80 编 —— 「调质量没效果」就成了一个查不出因由的现象。
  test('请求的 JPEG 质量透传到编码配置', () {
    expect(EBadgeStreamCameraSource.debugConfigFor(10, 30).jpegQuality, 30);
    expect(EBadgeStreamCameraSource.debugConfigFor(10, 100).jpegQuality, 100);
  });

  // 不给质量时沿用默认档:调用方(比如内部重建 config 的路径)漏传不该把画面质量
  // 悄悄改掉。
  test('不给质量时沿用默认档', () {
    expect(EBadgeStreamCameraSource.debugConfigFor(10).jpegQuality,
        EBadgeStreamCameraSource.quality);
  });

  // 相机没开时 setQuality 只记住值、不碰平台通道(碰了在测试里就会抛
  // MissingPluginException),等 open() 带上它。用户在推流前先把质量拖好是常见操作。
  test('相机未开时 setQuality 只记值，不打平台通道', () async {
    final w = _wire();
    expect(w.src.activeQuality, EBadgeStreamCameraSource.quality);
    expect(await w.src.setQuality(35), isNull);
    expect(w.src.activeQuality, 35);
    expect(w.src.isOpen, isFalse);
  });

  test('没有帧时 takeLatest 返回 null，不抛', () {
    final w = _wire();
    expect(w.src.takeLatest(), isNull);
    expect(w.src.produced, 0);
    expect(w.src.consumed, 0);
  });

  // 取一次就清空。这是有意的:如果没有新帧还把上一帧再推一遍,相机卡死和相机正常
  // 在设备屏上长得一模一样(都是持续有帧、画面不动),而「画面为什么不动」正是要判断
  // 的东西。返回 null 让推帧数停止增长,故障立刻可见。
  test('takeLatest 取过就没了 —— 不重复推同一帧', () {
    final w = _wire();
    final f = _frame(1);
    w.enc.onFrame!(f, true);

    expect(w.src.takeLatest(), orderedEquals(f));
    expect(w.src.takeLatest(), isNull, reason: '同一帧被返回了第二次');
    expect(w.src.consumed, 1);
  });

  // 只留最新一帧。排队的话一旦推得比编得慢,推出去的就是越来越旧的画面 —— 屏上像
  // 「延迟越攒越大」,而这会被误读成设备解码慢。
  test('只保留最新一帧，旧帧被顶掉', () {
    final w = _wire();
    final a = _frame(1);
    final b = _frame(2);
    final c = _frame(3);
    w.enc.onFrame!(a, true);
    w.enc.onFrame!(b, true);
    w.enc.onFrame!(c, true);

    expect(w.src.takeLatest(), orderedEquals(c), reason: '拿到的不是最新一帧');
    expect(w.src.produced, 3);
    expect(w.src.dropped, 2, reason: '被顶掉的帧数应为 2');
    expect(w.src.consumed, 1);
  });

  // 取走之后再来一帧不算「顶掉」—— 槽是空的。这个数要能当「推送侧是否被堵住」的
  // 指标用,凡是新帧就计一次的话它只是产帧数的复读,没有诊断价值。
  test('取走后再来的帧不计入顶掉数', () {
    final w = _wire();
    w.enc.onFrame!(_frame(1), true);
    w.src.takeLatest();
    w.enc.onFrame!(_frame(2), true);

    expect(w.src.dropped, 0);
    expect(w.src.produced, 2);
  });

  // 空帧直接丢:§6.2 的 size 是 payload 长度,0 没有意义,推出去只会让设备去解一个
  // 空 JPEG。也不能让它占住槽位把一帧真画面顶掉。
  test('空帧被忽略，不占槽位也不计数', () {
    final w = _wire();
    final good = _frame(7);
    w.enc.onFrame!(good, true);
    w.enc.onFrame!(Uint8List(0), true);

    expect(w.src.produced, 1);
    expect(w.src.takeLatest(), orderedEquals(good));
  });

  test('lastBytes 反映最近一帧的真实长度', () {
    final w = _wire();
    w.enc.onFrame!(_frame(1, len: 100), true);
    expect(w.src.lastBytes, 100);
    w.enc.onFrame!(_frame(2, len: 250), true);
    expect(w.src.lastBytes, 250);
  });

  // 界面靠这个回调重画帧计数,漏了的话屏上的数会停在旧值 —— 而这些数正是判断瓶颈
  // 在相机侧还是推送侧的依据。
  test('每帧都通知界面重画', () {
    final w = _wire();
    var n = 0;
    w.src.onChanged = () => n++;
    w.enc.onFrame!(_frame(1), true);
    w.enc.onFrame!(_frame(2), true);
    expect(n, 2);
  });

  // 原生报错要留在 error 里给界面显示。相机打不开时原生只发 error 事件,吞掉的话
  // 界面就只能一直转圈,看不出是权限、被占用还是硬件问题。
  test('原生错误被记下来', () {
    final w = _wire();
    w.enc.onError!('相机被占用');
    expect(w.src.error, '相机被占用');
  });
}
