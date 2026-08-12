import 'package:flutter/services.dart';

/// 导航帧数据（从原生 NaviCaptureService 获取）。
class NaviFrame {
  final int seq;
  final Uint8List jpeg;

  const NaviFrame({required this.seq, required this.jpeg});
}

/// 通过 MethodChannel "honeybox/navi" 与原生 NaviCaptureService 通信。
///
/// 与 WiFi 模式使用相同的导航渲染与编码管线：
///   NaviCaptureService → VirtualDisplay → ImageReader → TurboJPEG
///   区别仅在于 WiFi 模式走 TCP (`NaviJpgTcpSender`),
///   BLE 模式走本服务的 `pollFrame()` 拉取 → BLE 发送。
///
/// 使用方式:
/// ```dart
/// final navi = NaviFrameService();
/// await navi.startCapture();
/// final frame = navi.pollFrame();
/// await navi.stopCapture();
/// ```
class NaviFrameService {
  static const _channel = MethodChannel('honeybox/navi');

  /// 启动虚拟屏导航（不走 TCP, 仅采集 + 发布到 NaviFramePreview）。
  Future<void> startCapture({
    int width = 400,
    int height = 480,
    int fps = 5,
    int speed = 60,
    double startLat = 31.314,
    double startLng = 120.728,
    double endLat = 31.325,
    double endLng = 120.629,
  }) async {
    await _channel.invokeMethod('startCapture', {
      'width': width,
      'height': height,
      'fps': fps,
      'speed': speed,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
    });
  }

  /// 停止虚拟屏导航。
  Future<void> stopCapture() async {
    await _channel.invokeMethod('stopCapture');
  }

  /// 是否正在运行。
  Future<bool> isRunning() async =>
      await _channel.invokeMethod<bool>('isRunning') ?? false;

  /// 轮询获取最新帧。无新帧时返回 null。
  NaviFrame? pollFrameSync(dynamic result) {
    if (result == null) return null;
    final map = Map<String, dynamic>.from(result as Map);
    final seq = map['seq'] as int?;
    final jpeg = map['jpeg'] as Uint8List?;
    if (seq == null || jpeg == null) return null;
    return NaviFrame(seq: seq, jpeg: jpeg);
  }

  /// 异步轮询获取最新帧。
  Future<NaviFrame?> pollFrame() async {
    final result = await _channel.invokeMethod('pollFrame');
    return pollFrameSync(result);
  }
}
