import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ble_manager.dart' as ble;
import '../services/navi_frame_service.dart';
import '../services/navi_projection_protocol.dart';
import 'ble_provider.dart';

/// 投屏会话状态。
enum NaviProjState { idle, opening, projecting, error }

/// 导航投屏 Provider — 管理 NaviProjectionSession 生命周期。
class NaviProjectionNotifier extends StateNotifier<NaviProjState> {
  final ble.BleManager _ble;
  NaviProjectionSession? _session;
  StreamSubscription<Uint8List>? _ctrlSub;
  StreamSubscription<Uint8List>? _dataSub;
  Timer? _frameTimer;
  bool _sending = false;
  final NaviFrameService _naviFrame;

  /// 最后一次错误信息 (供 UI 展示)。
  String? lastError;

  /// 已发送帧计数 (供 UI 展示)。
  int sentFrames = 0;

  /// 已发送字节数 (供诊断)。
  int sentBytes = 0;

  /// 上一帧序号, 用于去重。
  int _lastSentSeq = -1;

  NaviProjectionNotifier(this._ble)
      : _naviFrame = NaviFrameService(),
        super(NaviProjState.idle);

  bool get available => _ble.naviProjAvailable;
  bool get isProjecting => state == NaviProjState.projecting;

  Future<void> startProjection({
    int width = 400,
    int height = 480,
    int fps = 5,
    int quality = 60,
  }) async {
    if (!_ble.naviProjAvailable) {
      lastError = '设备不支持导航投屏 Profile (缺少 FFD1-FFD4)';
      state = NaviProjState.error;
      return;
    }

    final naviL1 = _ble.naviL1;
    if (naviL1 == null) {
      lastError = '导航控制通道未就绪';
      state = NaviProjState.error;
      return;
    }

    _teardownSession();

    debugPrint('NaviProj: [1/4] 启动原生虚拟屏导航 (${width}x$height @${fps}fps)');
    try {
      await _naviFrame.startCapture(
        width: width,
        height: height,
        fps: fps,
      );
    } catch (e) {
      lastError = '启动导航虚拟屏失败: $e';
      state = NaviProjState.error;
      debugPrint('NaviProj: 启动 NaviCaptureService 失败: $e');
      return;
    }
    debugPrint('NaviProj: [1/4] NaviCaptureService 已启动');

    // 创建 BLE 会话
    debugPrint('NaviProj: [2/4] 创建 BLE 会话, '
        'chunk=${_ble.naviDataChunkSize} B, mtu=${_ble.mtu}');
    final session = NaviProjectionSession(
      sendControl: (l2) =>
          _ble.sendNaviControl(l2) ??
          (throw StateError('navi control channel not ready')),
      sendData: (l2) => _ble.writeNaviData(l2),
      chunkSize: () => _ble.naviDataChunkSize,
    );
    session.onLog = (msg) => debugPrint('NaviProj: $msg');
    _session = session;

    // 订阅控制通道 L2 (FFD2 → L1 解帧 → ACK/ERROR)
    _ctrlSub = _ble.naviCtrlNotifications.listen((payload) {
      debugPrint('NaviProj: ← FFD2 ctrl L2 ${payload.length}B');
      session.onControlL2(payload);
    });
    naviL1.onAck = (seq, ok) {
      debugPrint('NaviProj: ← FFD2 L1 ACK seq=$seq ${ok ? "OK" : "NAK"}');
      session.onControlL1Ack(seq, ok);
    };

    // 订阅数据通道 (FFD4 → CREDIT / REPORT)
    _dataSub = _ble.naviDataNotifications.listen((payload) {
      debugPrint('NaviProj: ← FFD4 data L2 ${payload.length}B '
          'key=0x${payload.length >= 3 ? payload[2].toRadixString(16) : "?"}');
      session.onDataNotify(payload);
    });

    // 握手
    debugPrint('NaviProj: [3/4] 发送 NAVI_OPEN 并等待 ACK...');
    state = NaviProjState.opening;
    final ok = await session.open(width, height, fps, quality);
    if (!ok) {
      lastError = '投屏握手失败 (设备拒绝或超时)';
      state = NaviProjState.error;
      debugPrint('NaviProj: ✗ 握手失败');
      _teardownSession();
      return;
    }

    debugPrint('NaviProj: [3/4] ✓ 握手成功 '
        'credits=${session.credits}');
    state = NaviProjState.projecting;

    debugPrint('NaviProj: [4/4] 启动帧发送循环 @${fps}fps');
    _startFrameLoop(fps);
  }

  void stopProjection() {
    debugPrint('NaviProj: 停止投屏 (已发送 $sentFrames 帧)');
    _session?.close();
    _teardownSession();
    state = NaviProjState.idle;
  }

  void _startFrameLoop(int fps) {
    _frameTimer?.cancel();
    final interval = Duration(milliseconds: (1000 / fps).round());
    debugPrint('NaviProj: 帧定时器 interval=${interval.inMilliseconds}ms');
    _frameTimer = Timer.periodic(interval, (_) => _sendNextFrame());
  }

  Future<void> _sendNextFrame() async {
    // 防止前一次 sendFrame (可能阻塞在 credit wait) 尚未返回时
    // 下一次 tick 重复进入。
    if (state != NaviProjState.projecting || _session == null) return;
    if (_sending) return;
    _sending = true;

    try {
      final frame = await _naviFrame.pollFrame();
      if (frame == null) {
        debugPrint('NaviProj: pollFrame → null (原生侧尚未产出帧)');
        return;
      }

      // 去重: 导航画面变化慢时 Native 侧可能发同一帧
      if (frame.seq == _lastSentSeq) return;

      debugPrint('NaviProj: → 准备发送帧 seq=${frame.seq} '
          'size=${frame.jpeg.length}B · credits=${_session?.credits}');
      _lastSentSeq = frame.seq;

      final ok = await _session!.sendFrame(frame.jpeg);
      if (ok) {
        sentFrames++;
        sentBytes += frame.jpeg.length;
        debugPrint('NaviProj: ✓ 帧 seq=${frame.seq} 发送完成 '
            '(累计 $sentFrames 帧 / ${(sentBytes / 1024).toStringAsFixed(1)} KB)');
      } else {
        debugPrint('NaviProj: ✗ 帧 seq=${frame.seq} 发送失败 '
            '(credit 超时或 session 已关闭)');
      }
    } finally {
      _sending = false;
    }
  }

  void _teardownSession() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _ctrlSub?.cancel();
    _ctrlSub = null;
    _dataSub?.cancel();
    _dataSub = null;
    _session = null;
    _sending = false;
    sentFrames = 0;
    sentBytes = 0;
    _lastSentSeq = -1;
    _naviFrame.stopCapture().catchError((_) {});
  }

  @override
  void dispose() {
    _teardownSession();
    super.dispose();
  }
}

final naviProjectionProvider =
    StateNotifierProvider<NaviProjectionNotifier, NaviProjState>((ref) {
  final bleManager = ref.read(bleManagerProvider);
  final notifier = NaviProjectionNotifier(bleManager);
  ref.onDispose(notifier.dispose);
  return notifier;
});
