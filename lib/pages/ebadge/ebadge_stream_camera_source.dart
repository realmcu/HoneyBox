// ebadge_stream_camera_source.dart
//
// 协议调试页 §6 同屏推流的**摄像头帧源**。
//
// 与内置测试帧([EBadgeStreamDemoFrames])并列的第二个源:测试帧图案固定,用来排除
// 「画面来源」这个变量;摄像头则相反 —— 画面一直在变、每帧体积也在变,压的是真实
// 负载下的协议时序(帧间隔、码率、设备解码跟不跟得上)。两个源都必要,所以做成可
// 切换而不是替换。

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/encoder.dart';
import 'ebadge_demo_presets.dart';

/// 把原生相机链路当成「一帧一张 JPEG」的帧源用。
///
/// **为什么可以直接复用拍照投屏那套原生编码器**:`CameraEncoder` 的 `format=jpeg`
/// 分支本来就是「每帧独立编成一个完整 JFIF 文件」(`SoftwareCodec.encodeJpeg` →
/// `Bitmap.compress`),经 `frame` 事件原样交给 Dart。这正是 §6.2 要的 payload 形态
/// —— 流头之后跟一个完整可独立解码的 JPEG。H.264 就不行:它是带 SPS/PPS 和帧间
/// 依赖的码流,单帧拿出来解不开。
///
/// GL 阶段会把裁切/旋转/缩放烘进输出,输出分辨率与摄像头支持的尺寸无关,所以
/// [size] 想要多少就是多少 —— 466 不必是任何一档相机预览尺寸。
///
/// **不会和拍照投屏页互相干扰**:两页是设备页下的并列入口,不会同时存活;原生侧
/// `CameraEncoder` 是单例,谁打开谁用,退页面时 [close] 会 `closeCamera` 交还。
/// 之前注释里说的「碰了就抢 GL 上下文」指的是**同时**用,而不是不能用。
class EBadgeStreamCameraSource {
  EBadgeStreamCameraSource({EncoderService? encoder})
      : _encoder = encoder ?? EncoderService() {
    // 回调在构造时就挂好(而不是等 [open]):这样帧槽逻辑不依赖平台通道,能直接测。
    _encoder
      ..onCamera = (info) {
        _camera = info;
        if (!(_ready?.isCompleted ?? true)) _ready!.complete(null);
        onChanged?.call();
      }
      ..onError = (msg) {
        _error = msg;
        if (!(_ready?.isCompleted ?? true)) _ready!.complete(msg);
        onChanged?.call();
      }
      ..onFrame = _acceptFrame;
  }

  final EncoderService _encoder;

  /// 帧的边长。与传图档位、内置测试帧共用同一个常量 —— §6.2 的流头不带宽高,设备
  /// 只能按 JPEG 自身的 SOF 解,三条链路发不同尺寸只会多出一个待排除的变量。
  static const int size = kEBadgeDemoImageSize;

  /// IJG 质量档的**默认值**。80 是原生 JPEG 分支的默认档,466×466 下每帧约
  /// 20–40 KB。实际用哪一档由调用方经 [open] / [setQuality] 给 —— 单帧体积是这条
  /// 链路的主要瓶颈,得能一边推一边调。
  static const int quality = 80;

  /// 当前生效的质量档。
  int get activeQuality => _quality;
  int _quality = quality;

  /// 当前生效的帧率(原生据此节流 GL 回读)。
  int get activeFps => _fps;
  int _fps = 10;

  /// 相机就绪信息(预览纹理 id 和尺寸)。null 表示还没就绪。
  CameraInfo? get camera => _camera;
  CameraInfo? _camera;

  /// 原生侧报上来的最后一条错误。
  String? get error => _error;
  String? _error;

  /// 状态有变(相机就绪 / 出错 / 帧计数变化),让界面重画。
  void Function()? onChanged;

  Completer<String?>? _ready;
  bool _open = false;
  bool get isOpen => _open;

  // ── 帧槽 ──────────────────────────────────────────────────────────────
  //
  // 只留**最新一帧**,不排队。相机产帧和推流 tick 是两个独立节拍,排队的话一旦推
  // 得比编得慢,推出去的就是越来越旧的画面 —— 屏上看着像「延迟越攒越大」,而这会
  // 被误读成设备解码慢。丢掉过期帧、只推最新的,延迟才是有界的。
  Uint8List? _slot;

  /// 原生编出来的总帧数。
  int get produced => _produced;
  int _produced = 0;

  /// 被 [takeLatest] 取走推出去的帧数。
  int get consumed => _consumed;
  int _consumed = 0;

  /// 因为推流没跟上而被新帧顶掉的帧数。**这个数不是故障** —— 相机按 fps 一直产,
  /// 而设备协商的 fps 可能更低,差额就落在这里。它大到接近 [produced] 才说明推流
  /// 侧被堵住了。
  int get dropped => _dropped;
  int _dropped = 0;

  /// 最近一帧的字节数,用来看真实码率量级。
  int get lastBytes => _lastBytes;
  int _lastBytes = 0;

  void _acceptFrame(Uint8List data, bool key) {
    if (data.isEmpty) return;
    if (_slot != null) _dropped++;
    _slot = data;
    _produced++;
    _lastBytes = data.length;
    onChanged?.call();
  }

  /// 取走最新一帧;取过就没了(**不重复返回同一帧**)。
  ///
  /// 这个「取一次就清空」是有意的:如果没有新帧还把上一帧再推一遍,相机卡死和相机
  /// 正常在设备屏上长得一模一样(都是持续有帧、画面不动),而「画面为什么不动」正是
  /// 要判断的东西。返回 null 让会话跳过这一 tick,推帧数就会停止增长,故障立刻可见。
  Uint8List? takeLatest() {
    final f = _slot;
    if (f == null) return null;
    _slot = null;
    _consumed++;
    return f;
  }

  /// 开相机并起编码。返回 null 表示成功,否则是失败原因。
  ///
  /// [fps] 传会话请求的帧率 —— 原生侧据此节流 GL 回读,不然软件编码器会跟着相机的
  /// 自动曝光帧率跑,白烧 CPU 也白编大量推不出去的帧。
  ///
  /// [jpegQuality] 缺省沿用 [quality]。
  ///
  /// [readyTimeout] 是等 `camera` 事件的上限。相机打不开时原生侧只会发 `error`,
  /// 万一连 error 都没有(权限被系统静默拒了之类),不设上限就会永远卡在这里。
  Future<String?> open({
    required int fps,
    int? jpegQuality,
    Duration readyTimeout = const Duration(seconds: 10),
  }) async {
    if (_open) return null;

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      return '相机权限被拒绝，无法用摄像头作为帧源';
    }

    _error = null;
    _camera = null;
    _fps = fps;
    _quality = jpegQuality ?? quality;
    _resetCounters();
    final ready = Completer<String?>();
    _ready = ready;

    final cfg = _configFor(_fps, _quality);
    _encoder.listen();
    try {
      await _encoder.openCamera(cfg);
    } on PlatformException catch (e) {
      _ready = null;
      return '打开相机失败：${e.message ?? e.code}';
    }

    final String? err = await ready.future.timeout(
      readyTimeout,
      onTimeout: () => '相机 ${readyTimeout.inSeconds}s 内没有就绪',
    );
    _ready = null;
    if (err != null) {
      await close();
      return err;
    }

    try {
      // stream: true 才会把每帧 JPEG 通过 frame 事件交上来;false 只是本地编码。
      await _encoder.startEncoding(cfg, stream: true);
    } on PlatformException catch (e) {
      await close();
      return '启动 JPEG 编码失败：${e.message ?? e.code}';
    }

    _open = true;
    onChanged?.call();
    return null;
  }

  /// 改 JPEG 质量,**推流中也能改**。返回 null 表示已下发。
  ///
  /// 能实时生效是因为原生的 JPEG 分支每帧现场读 `config.jpegQuality`
  /// (`CameraEncoder.encodeJpeg` 那一行),而 `setConfig` 把整个 config 换掉。
  /// 所以下一帧就是新质量,不用重开相机 —— 这正是它作为「背压旋钮」的价值:
  /// 一边看着进度里的跳帧数,一边往下调,拐点立刻就看出来了。
  ///
  /// **帧率没有对应的方法**,是有意的:帧率已经写进 0x08 OFFER 报给设备、会话的
  /// 推流周期也在握手时就定了,中途改原生节流只会让「界面说的」和「协议里说的」
  /// 对不上。改帧率必须重开会话。
  Future<String?> setQuality(int jpegQuality) async {
    _quality = jpegQuality;
    if (!_open) return null;
    try {
      await _encoder.setConfig(_configFor(_fps, _quality));
    } on PlatformException catch (e) {
      return '调整 JPEG 质量失败：${e.message ?? e.code}';
    }
    onChanged?.call();
    return null;
  }

  /// 停编码并交还相机。幂等。
  Future<void> close() async {
    _open = false;
    _slot = null;
    _camera = null;
    try {
      await _encoder.stopEncoding();
    } catch (_) {}
    try {
      await _encoder.dispose();
    } catch (_) {}
    onChanged?.call();
  }

  void _resetCounters() {
    _slot = null;
    _produced = 0;
    _consumed = 0;
    _dropped = 0;
    _lastBytes = 0;
  }

  /// 帧源用的编码配置。**格式必须是 jpeg** —— 见类文档:h264 的单帧解不开。
  static EncoderConfig _configFor(int fps, [int? jpegQuality]) => EncoderConfig(
        format: EncoderFormat.jpeg,
        width: size,
        height: size,
        fps: fps,
        jpegQuality: jpegQuality ?? quality,
        // 调试台只关心推出去的字节,不落地文件;录文件会额外占 IO 和内存,
        // 还会在停止时触发 AVI 封装,和协议无关。
        recordToFile: false,
      );

  /// 暴露给测试:配置确实是 466×466 的 JPEG。
  static EncoderConfig debugConfigFor(int fps, [int? jpegQuality]) =>
      _configFor(fps, jpegQuality);
}
