// =============================================================================
// DEPRECATED — 仪表盘投屏已改为原生实现（`honeybox/map` → MapHomeActivity，
// HoneyProtocol 0x10 over HMIS）。启动器对 dashboard 直接拉起原生页面，
// 不会再 push DashboardAppRoot，因此本文件及其下游在现行流程中不可达，
// 仅作为历史参考保留。不要在此基础上新增功能。
// =============================================================================

import 'dart:async';
import 'dart:typed_data';

import 'l2_file_transfer.dart';

/// 导航投屏 sender —— 把每一帧 JPEG 当成一个"文件"，走 HoneyProtocol 3.12
/// 的 `0x10` 文件传输命令。
///
/// 线上格式（全程大端，L2 帧结构 = Command | Version | Key | Len(2) | Value）：
/// ```
/// 0x01 BEGIN_REQ  file_type(1) total_size(4) chunk_size(2) name_len(1) name
/// 0x02 BEGIN_RSP  status(1) chunk_size(2)
/// 0x03 DATA       seq(2) bytes
/// 0x05 END_REQ    crc32(4)
/// 0x06 END_RSP    status(1) error_code(1)
/// 0x07 ABORT      reason(1)
/// ```
///
/// 每个 L2 帧都装入一个 L1 帧（`0xAB` + CRC16 + seq + ACK），可靠性由 L1 逐帧
/// 确认保证，因此不需要 credit、缺口报告和帧内 CRC32。本版只求"能通"，
/// 每帧一次 BEGIN/END 的握手开销留给后续优化。
class NaviXferSender {
  NaviXferSender({
    required this.sendL2,
    this.attachToL1,
    this.detachFromL1,
    this.onLog,
    this.frameTimeout = const Duration(seconds: 45),
  });

  /// 把一整条 L2 帧交给 L1；返回该帧的 L1 序号（用于匹配 ACK）。
  final int Function(Uint8List frame) sendL2;

  /// 每个会话开始时把 [FileTransferSession] 挂到 L1 引擎上（session 需要
  /// L1 的 ACK 回调才能推进数据块）。
  final void Function(FileTransferSession session)? attachToL1;

  /// 会话结束后从 L1 引擎上摘掉。
  final void Function()? detachFromL1;

  final void Function(String message)? onLog;

  /// 单帧（单文件）端到端超时。
  final Duration frameTimeout;

  FileTransferSession? _session;
  bool _busy = false;

  bool get isBusy => _busy;

  /// 发送一帧 JPEG。返回 true 表示设备校验通过（END_RSP status=0）。
  Future<bool> sendFrame(Uint8List jpeg) async {
    if (_busy || jpeg.isEmpty) {
      return false;
    }
    _busy = true;

    final completer = Completer<bool>();
    final session = FileTransferSession(
      sendL2: sendL2,
      attachToL1: attachToL1,
      detachFromL1: detachFromL1,
      onLog: onLog,
      // A/B 对照实验（临时）：window = 1 表示严格停等——发一块，等设备回
      // L1 ACK success 才发下一块。window = 6 是滑窗流水。改回 6 即恢复。
      window: 1,
      onComplete: () {
        if (!completer.isCompleted) completer.complete(true);
      },
      onError: (reason) {
        onLog?.call('帧传输失败: $reason');
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    _session = session;

    try {
      session.send(TYPE.image, jpeg, 'navi.jpg');
      return await completer.future.timeout(frameTimeout, onTimeout: () {
        onLog?.call('帧传输超时 (${frameTimeout.inSeconds}s)');
        session.abort();
        return false;
      });
    } catch (e) {
      onLog?.call('帧传输异常: $e');
      session.abort();
      return false;
    } finally {
      _busy = false;
      _session = null;
    }
  }

  void abort() {
    _session?.abort();
    _session = null;
  }
}
