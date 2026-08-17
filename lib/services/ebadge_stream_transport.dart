import 'dart:async';
import 'dart:io';

// Uint8List 由 flutter/services 转出,不再单独 import 'dart:typed_data'
// —— unnecessary_import 会告警。
import 'package:flutter/services.dart';

import 'ebadge_protocol.dart';

/// eBadge 协议 §6「Wi‑Fi 同屏预览」的数据面:一条 TCP 连接上**连续推多帧**
/// JPEG,每帧前置 14 字节流头([EBadgeStreamHeader])。
///
/// **与另外两条推流路径的关系 —— 三者刻意不复用,别合并**:
///
/// | | 帧头 | 会话形态 | 应答 |
/// | --- | --- | --- | --- |
/// | `TcpVideoClient`(拍照投屏) | `0xA5 0xA9` + seq + len + checksum,6B | 连续多帧 | 不读 |
/// | [EBadgeWifiTransport](§5 壁纸传图) | 'EBXF' 40B,带 name | 单文件单连接 | 必读 8B EBXR |
/// | 本类(§6 同屏预览) | 'EBXF' 14B,无 name | 连续多帧 | **可选** |
///
/// 中间那列才是关键:§5 是「一个文件传完就关」,§6 是「开着连接一直推到用户退出
/// 预览」。帧头虽然共用 'EBXF' magic(协议如此,不是笔误),但长度不同、字段不同,
/// 收发两侧只能靠会话类型(0x10 Offer 还是 0x08 Offer)决定拿哪个头去解。
///
/// 本类**仅用于协议调试**:它不接任何摄像头、不做编码,payload 由调用方给。真正
/// 的拍照投屏功能走 `wifi_transport.dart`,两边不共享任何状态。
///
/// STA 关联(连设备热点)不在这里 —— 那一步和 §5 完全相同,直接用
/// [EBadgeWifiTransport.join] / [EBadgeWifiTransport.leave],没必要抄一遍。
class EBadgeStreamTransport {
  /// §6.4 的帧超时:设备侧「帧超时 3 秒,清理资源,流程结束」。这里当作**发送侧
  /// 的自检上限** —— 相邻两帧间隔超过它,设备很可能已经把会话拆了,再推也是白推,
  /// 所以要让调用方立刻知道。
  static const Duration frameGapLimit = Duration(seconds: 3);

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;

  var _framesSent = 0;
  var _bytesSent = 0;
  DateTime? _lastFrameAt;
  EBadgeXferAck? _lastAck;
  String? _peerClosed;

  bool get connected => _socket != null && _peerClosed == null;
  int get framesSent => _framesSent;

  /// 已推出的 payload 字节数(不含 14B 头)。
  int get bytesSent => _bytesSent;

  /// 设备可选回的 EBXR 应答里最后一条。§6.3 写明这是「可选」的,所以 null 是正常
  /// 情况,不能当失败看。
  EBadgeXferAck? get lastAck => _lastAck;

  /// 设备主动断开的原因描述;未断开时为 null。
  String? get peerClosed => _peerClosed;

  /// 连接设备的 TCP 监听口。返回 null 表示成功,否则是失败原因。
  ///
  /// [timeout] 对齐 §6.5「STA 关联成功 → TCP 连接 10 s」。
  Future<String?> connect({
    required String ip,
    required int port,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_socket != null) return '已有连接,先 close 再连';
    Socket s;
    try {
      s = await Socket.connect(ip, port, timeout: timeout);
    } catch (e) {
      return 'TCP 连接 $ip:$port 失败：$e';
    }
    try {
      // 同屏预览对延迟敏感,必须关掉 Nagle:一帧 JPEG 分块写出去时,内核为了凑
      // 满一个 MSS 会压着最后一个小包不发,直接给每帧加上几十毫秒抖动。
      s.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    _socket = s;
    _peerClosed = null;
    _framesSent = 0;
    _bytesSent = 0;
    _lastFrameAt = null;
    _lastAck = null;

    // 应答是可选的,但连接必须一直被读 —— 不读的话设备真回了 8 字节,这些数据会
    // 堆在接收缓冲里,而我们也永远不知道对方已经断开。
    final buf = <int>[];
    _sub = s.listen(
      (data) {
        buf.addAll(data);
        while (buf.length >= EBadgeXferAck.length) {
          final ack =
              EBadgeXferAck.parse(Uint8List.fromList(buf.take(8).toList()));
          buf.removeRange(0, EBadgeXferAck.length);
          // magic 不对说明对面发的不是 EBXR;丢掉整个窗口而不是逐字节重同步 ——
          // §6 里设备除了 EBXR 不该发别的,出现杂字节本身就是要查的问题。
          if (ack != null) _lastAck = ack;
        }
      },
      onError: (Object e) => _peerClosed = '连接出错：$e',
      onDone: () => _peerClosed = '设备关闭了连接',
      cancelOnError: true,
    );
    return null;
  }

  /// 推一帧。返回 null 表示写出成功,否则是失败原因。
  ///
  /// [crc32] 缺省自算 —— §6.2 的 crc32 是对**本帧 payload** 的,没有「必须与
  /// 握手一致」的约束(那是 §5.2 的规则),所以这里自算是安全的。调试要构造坏帧
  /// 时可以显式传一个错的值进来。
  Future<String?> sendFrame(
    Uint8List payload, {
    int fileType = EBadgeFileType.jpegStream,
    int? crc32,
  }) async {
    final s = _socket;
    if (s == null) return 'TCP 未连接';
    if (_peerClosed != null) return _peerClosed;
    if (payload.isEmpty) return '空帧:payload 长度为 0';

    // 间隔自检:超过 §6.4 的 3 s,设备那边大概率已经清理掉会话了。这里只报不拦,
    // 让调试的人能亲眼看到「超时后设备是怎么反应的」。
    final now = DateTime.now();
    final last = _lastFrameAt;
    final gap = last == null ? Duration.zero : now.difference(last);

    try {
      s.add(EBadgeStreamHeader.build(
        fileType: fileType,
        size: payload.length,
        crc32: crc32 ?? eBadgeCrc32(payload),
      ));
      s.add(payload);
      await s.flush();
    } catch (e) {
      return '推帧失败：$e';
    }

    _framesSent++;
    _bytesSent += payload.length;
    _lastFrameAt = now;

    if (last != null && gap > frameGapLimit) {
      return '距上一帧 ${gap.inMilliseconds}ms,已超 §6.4 的 '
          '${frameGapLimit.inSeconds}s 帧超时,设备可能已清理会话';
    }
    return null;
  }

  /// 关连接。幂等,吞掉清理阶段的异常。
  Future<void> close() async {
    final s = _socket;
    _socket = null;
    await _sub?.cancel();
    _sub = null;
    if (s == null) return;
    try {
      await s.close();
    } catch (_) {}
    s.destroy();
  }
}
