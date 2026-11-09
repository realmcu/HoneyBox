// =============================================================================
// DEPRECATED — 仪表盘投屏已改为原生实现（`honeybox/map` → MapHomeActivity，
// HoneyProtocol 0x10 over HMIS）。启动器对 dashboard 直接拉起原生页面，
// 不会再 push DashboardAppRoot，因此本文件及其下游在现行流程中不可达，
// 仅作为历史参考保留。不要在此基础上新增功能。
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ble_manager.dart' as ble;
import '../services/navi_frame_service.dart';
import '../services/navi_xfer_sender.dart';
import 'ble_provider.dart';

/// 投屏会话状态。
enum NaviProjState { idle, opening, projecting, error }

/// 导航投屏 Provider。
///
/// 传输路径：原生虚拟屏截图 → JPEG → **HoneyProtocol `0x10` 文件传输**
/// （一帧一个"文件"）→ FFD1/FFD2 上的 L1 可靠通道。
///
/// 与旧实现的区别：不再使用私有的 `0x11` 命令，也不再需要 FFD3/FFD4
/// 数据通道与 credit 流控 —— 每帧的内容与校验都由 `0x10` 的
/// BEGIN/DATA/END + CRC32 完成，速度不是本版目标。
class NaviProjectionNotifier extends StateNotifier<NaviProjState> {
  final ble.BleManager _ble;
  final NaviFrameService _naviFrame;

  NaviXferSender? _sender;
  bool _running = false;
  bool _sending = false;
  int _lastSentSeq = -1;

  /// 最后一次错误信息 (供 UI 展示)。
  String? lastError;

  /// 已发送帧计数 (供 UI 展示)。
  int sentFrames = 0;

  /// 已发送字节数 (供诊断)。
  int sentBytes = 0;

  NaviProjectionNotifier(this._ble)
      : _naviFrame = NaviFrameService(),
        super(NaviProjState.idle);

  bool get available => _ble.naviProjAvailable;
  bool get isProjecting => state == NaviProjState.projecting;

  Future<void> startProjection({
    int width = 400,
    int height = 480,
    int fps = 5,
    int quality = 45,
  }) async {
    if (!_ble.naviProjAvailable) {
      lastError = '设备不支持导航投屏 Profile (缺少 FFD1-FFD4)';
      state = NaviProjState.error;
      return;
    }

    final l1 = _ble.naviL1;
    if (l1 == null) {
      lastError = '导航控制通道未就绪';
      state = NaviProjState.error;
      return;
    }

    await _teardown();

    debugPrint('NaviProj: [1/3] 启动原生虚拟屏导航 '
        '(${width}x$height @${fps}fps, jpeg q=$quality)');
    try {
      await _naviFrame.startCapture(
        width: width,
        height: height,
        fps: fps,
        quality: quality,
      );
    } catch (e) {
      lastError = '启动导航虚拟屏失败: $e';
      state = NaviProjState.error;
      debugPrint('NaviProj: 启动 NaviCaptureService 失败: $e');
      return;
    }

    debugPrint('NaviProj: [2/3] 建立 0x10 文件传输会话 '
        '(chunk≤241B, mtu=${_ble.mtu})');
    _sender = NaviXferSender(
      sendL2: (l2) {
        final seq = _ble.sendNaviControl(l2);
        if (seq == null) {
          throw StateError('navi control channel not ready');
        }
        return seq;
      },
      attachToL1: (session) {
        l1.attach(session);
        l1.onAck = session.onL1Ack;
      },
      detachFromL1: () {
        l1.detach();
        l1.onAck = null;
      },
      onLog: (msg) => debugPrint('NaviXfer: $msg'),
    );

    state = NaviProjState.projecting;
    _running = true;
    debugPrint('NaviProj: [3/3] 开始逐帧传输');
    unawaited(_loop(fps));
  }

  void stopProjection() {
    debugPrint('NaviProj: 停止投屏 (已发送 $sentFrames 帧 / $sentBytes B)');
    _running = false;
    _sender?.abort();
    unawaited(_teardown());
    state = NaviProjState.idle;
  }

  /// 逐帧循环：一帧的 BEGIN→DATA→END 全部完成后才取下一帧。
  /// 上一帧没发完时不会并发开第二帧（0x10 同一时刻只允许一个会话）。
  Future<void> _loop(int fps) async {
    final interval = Duration(milliseconds: (1000 / fps).round());

    while (_running) {
      final started = DateTime.now();

      if (!_sending) {
        _sending = true;
        try {
          final frame = await _naviFrame.pollFrame();
          if (!_running) break;
          if (frame != null && frame.seq != _lastSentSeq) {
            _lastSentSeq = frame.seq;
            debugPrint('NaviProj: → 帧 seq=${frame.seq} '
                '${frame.jpeg.length}B');
            final started = DateTime.now();
            final ok = await _sender?.sendFrame(frame.jpeg) ?? false;
            final elapsedMs = DateTime.now().difference(started).inMilliseconds;
            if (!_running) break;
            if (ok) {
              sentFrames++;
              sentBytes += frame.jpeg.length;
              debugPrint('NaviProj: ✓ 帧 seq=${frame.seq} 已上屏 '
                  '(${elapsedMs}ms, ${frame.jpeg.length}B, 累计 $sentFrames 帧)');
            } else {
              debugPrint('NaviProj: ✗ 帧 seq=${frame.seq} 传输失败 '
                  '(${elapsedMs}ms)');
            }
          }
        } catch (e) {
          debugPrint('NaviProj: 帧循环异常 $e');
        } finally {
          _sending = false;
        }
      }

      final elapsed = DateTime.now().difference(started);
      final wait = interval - elapsed;
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }
  }

  Future<void> _teardown() async {
    _running = false;
    _sending = false;
    _sender = null;
    _lastSentSeq = -1;
    sentFrames = 0;
    sentBytes = 0;
    try {
      await _naviFrame.stopCapture();
    } catch (_) {}
  }

  @override
  void dispose() {
    _running = false;
    _sender?.abort();
    unawaited(_teardown());
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
