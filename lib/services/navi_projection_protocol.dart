import 'dart:async';
import 'dart:typed_data';

import 'ble_cmd_registry.dart';

/// 导航投屏 L2 协议层 (CMD 0x11)。
///
/// 架构：
///   控制通道 (FFD1/FFD2) — 走 L1 封装 (CRC16 + ACK + seq)
///   数据通道 (FFD3/FFD4) — 裸 L2 (BLE LL ARQ + credit flow control)
///
/// 与 WiFi 传图 (`NaviJpgTcpSender`) 的对应关系：
///   WiFi: "JPG <size> <seq>\n" + JPEG payload → TCP socket
///   BLE:  NAVI_OPEN/ACK 握手 →  FFD3 分包发 JPEG chunks → FFD4 CREDIT/REPORT
///
/// 低带宽风险管控：
///   - credit flow control 为强制项 (不允许 0xFFFF 无限模式)
///   - 保留最近 3 帧用于 gap retransmission
///   - 连续丢帧 ≥3 帧时主动报错，由上层决定降帧率或停止

// ---------------------------------------------------------------------------
// 结果 / 错误码
// ---------------------------------------------------------------------------

/// 设备在 NAVI_ACK 中返回的结果码。
class NaviProjResult {
  NaviProjResult._();
  static const int ok = 0x00;
  static const int busy = 0x01;
  static const int unsupportedParams = 0x02;
  static const int decoderError = 0x03;
  static const int lowMemory = 0x04;

  static String label(int code) => switch (code) {
        ok => 'OK',
        busy => '设备忙',
        unsupportedParams => '参数不支持',
        decoderError => '解码器错误',
        lowMemory => '内存不足',
        _ => '0x${code.toRadixString(16)}',
      };
}

/// 设备在 NAVI_ERROR 中上报的错误码。
class NaviProjErrorCode {
  NaviProjErrorCode._();
  static const int bufferOverflow = 0x01;
  static const int decodeFailed = 0x02;
  static const int timeout = 0x03;
  static const int unexpectedFrame = 0x04;
}

/// APP 在 NAVI_CLOSE 中的关闭原因。
class NaviProjCloseReason {
  NaviProjCloseReason._();
  static const int normal = 0x00;
  static const int userCancel = 0x01;
  static const int creditTimeout = 0x02; // 连续多帧无 credit 补充
  static const int encodeError = 0x03;
}

// ---------------------------------------------------------------------------
// Byte helpers
// ---------------------------------------------------------------------------

void _writeU16(Uint8List data, int offset, int value) {
  data[offset] = (value >> 8) & 0xFF;
  data[offset + 1] = value & 0xFF;
}

int _readU16(List<int> data, int offset) {
  return (data[offset] << 8) | data[offset + 1];
}

int _u24be(int a, int b, int c) => (a << 16) | (b << 8) | c;

/// Build a generic L2 frame: [cmd, 0x00, key, vlen_hi, vlen_lo, ...value].
Uint8List buildNaviProjL2(int key, List<int> value) {
  final out = Uint8List(5 + value.length);
  out[0] = BleCmd.naviProj;
  out[1] = 0x00;
  out[2] = key;
  out[3] = (value.length >> 8) & 0xFF;
  out[4] = value.length & 0xFF;
  out.setRange(5, 5 + value.length, value);
  return out;
}

// ---------------------------------------------------------------------------
// Frame builders
// ---------------------------------------------------------------------------

/// NAVI_OPEN value: `width(u16 LE), height(u16 LE), fps(u8), quality(u8), flags(u8)`.
/// flags bit 0: flow_ctrl_enable (App 端强制置 1 — 必须开启 credit 流控)。
Uint8List buildNaviOpen(int w, int h, int fps, int quality) {
  return buildNaviProjL2(BleCmdNaviProjKey.open, [
    w & 0xFF,
    (w >> 8) & 0xFF,
    h & 0xFF,
    (h >> 8) & 0xFF,
    fps & 0xFF,
    quality.clamp(10, 100) & 0xFF,
    0x01, // flags: flow_ctrl_enable = 1 (强制)
  ]);
}

/// NAVI_CLOSE value: `reason(u8)`.
Uint8List buildNaviClose(int reason) =>
    buildNaviProjL2(BleCmdNaviProjKey.close, [reason & 0xFF]);

/// NAVI_FRAME value: `frame_seq(u16 BE), chunk_offset(u24 BE), total_len(u24 BE), data`.
Uint8List buildNaviChunk(int seq, int off, int total, Uint8List data) {
  final out = Uint8List(8 + data.length);
  _writeU16(out, 0, seq);
  out[2] = (off >> 16) & 0xFF;
  out[3] = (off >> 8) & 0xFF;
  out[4] = off & 0xFF;
  out[5] = (total >> 16) & 0xFF;
  out[6] = (total >> 8) & 0xFF;
  out[7] = total & 0xFF;
  out.setRange(8, 8 + data.length, data);
  return buildNaviProjL2(BleCmdNaviProjKey.frame, out);
}

// ---------------------------------------------------------------------------
// Inbound frame parsers
// ---------------------------------------------------------------------------

/// Parse result + max_chunk + init_credits from a NAVI_ACK value.
/// Returns null on malformed data.
(int result, int maxChunk, int initCredits)? parseNaviAck(Uint8List value) {
  if (value.length < 5) return null;
  final result = value[0];
  final maxChunk = _readU16(value, 1);
  final initCredits = _readU16(value, 3);
  return (result, maxChunk, initCredits);
}

/// Parse error_code + frame_seq from NAVI_ERROR value.
(int errorCode, int frameSeq)? parseNaviError(Uint8List value) {
  if (value.length < 2) return null;
  return (value[0], value[1]);
}

/// Parse credits from NAVI_CREDIT value.
int? parseNaviCredit(Uint8List value) {
  if (value.length < 2) return null;
  return _readU16(value, 0);
}

/// Parse frame_seq + gap_count + gaps from NAVI_REPORT value.
/// Returns (frameSeq, gapCount, List<(gapStart, gapEnd)>).
/// An empty gaps list with gapCount=0 means the frame is complete.
(int frameSeq, int gapCount, List<(int, int)> gaps)? parseNaviReport(
    Uint8List value) {
  if (value.length < 4) return null;
  final frameSeq = _readU16(value, 0);
  final gapCount = value[2];
  final gaps = <(int, int)>[];
  const base = 3, gapBytes = 6;
  if (value.length < base + gapCount * gapBytes) return null;
  for (int i = 0; i < gapCount; i++) {
    final off = base + i * gapBytes;
    final gs = _u24be(value[off], value[off + 1], value[off + 2]);
    final ge = _u24be(value[off + 3], value[off + 4], value[off + 5]);
    gaps.add((gs, ge));
  }
  return (frameSeq, gapCount, gaps);
}

// ---------------------------------------------------------------------------
// Session state machine
// ---------------------------------------------------------------------------

/// Sends one raw L2 message over the control channel (FFD1, 经 L1 封装).
/// Returns the L1 sequence number.
typedef NaviSendControlFn = int Function(Uint8List l2);

/// Send one raw L2 message over the data channel (FFD3, writeWithoutResponse).
typedef NaviSendDataFn = Future<void> Function(Uint8List l2);

/// Session states.
enum NaviProjState { idle, opening, open }

/// Retransmit buffer entry for one chunk.
class _RetxEntry {
  final Uint8List chunk;
  final int totalLen;
  const _RetxEntry(this.chunk, this.totalLen);
}

/// 导航投屏会话 — 管理 OPEN/ACK 握手、credit 流控、分包发送、gap 重传。
///
/// 使用方式：
/// ```dart
/// final session = NaviProjectionSession(
///   sendControl: (l2) => l1.sendL2(l2),    // FFD1 走 L1
///   sendData: (l2) => manager.writeNaviData(l2), // FFD3 裸 L2
///   chunkSize: () => manager.naviDataChunkSize,
/// );
/// await session.open(400, 480, 5, 60);
/// // 收到 L1 ACK → session.onControlL1Ack(seq, ok)
/// // 收到 L2 数据 → session.onDataNotify(l2)   // FFD4 notify
/// // 发送一帧
/// await session.sendFrame(jpegBytes);
/// session.close();
/// ```
class NaviProjectionSession {
  final NaviSendControlFn sendControl;
  final NaviSendDataFn sendData;
  final int Function() chunkSize;

  NaviProjectionSession({
    required this.sendControl,
    required this.sendData,
    required this.chunkSize,
  });

  // ── Timeouts ───────────────────────────────────────────────────────
  static const Duration _openTimeout = Duration(seconds: 5);
  static const Duration _creditTimeout = Duration(seconds: 3);

  // ── State ──────────────────────────────────────────────────────────
  NaviProjState _state = NaviProjState.idle;
  int _frameSeq = 0;
  int _credits = 0;
  int _maxChunk = 496; // default before ACK

  /// 连续耗光 credit 等待超时的帧数。≥3 时 session 自动进入错误状态。
  int _creditStallCount = 0;
  static const int _maxStallBeforeError = 3;

  Completer<bool>? _openCompleter;
  Completer<bool>? _creditCompleter;
  Timer? _openTimer;
  Timer? _creditTimer;

  /// Retransmit buffers: frame_seq → (byte_offset → entry). 保留最近 3 帧。
  final Map<int, Map<int, _RetxEntry>> _retxFrames = {};

  /// Pending L1 seq for the OPEN/CLOSE frame; matched in [onControlL1Ack].
  int? _pendingControlSeq;

  // ── Callbacks ──────────────────────────────────────────────────────
  void Function(String message)? onLog;

  NaviProjState get state => _state;
  bool get isOpen => _state == NaviProjState.open;
  int get credits => _credits;

  // ──────────────────────────────────────────────────────────────────
  // Session lifecycle
  // ──────────────────────────────────────────────────────────────────

  /// 发送 NAVI_OPEN 并等待设备 ACK。返回 false 表示握手失败。
  Future<bool> open(int w, int h, int fps, int quality) async {
    if (_state != NaviProjState.idle) return false;
    _state = NaviProjState.opening;
    _frameSeq = 0;
    _credits = 0;
    _maxChunk = 496;
    _creditStallCount = 0;
    _retxFrames.clear();

    final completer = Completer<bool>();
    _openCompleter = completer;
    _openTimer?.cancel();
    _openTimer = Timer(_openTimeout, () {
      if (_state == NaviProjState.opening) {
        _failOpen('NAVI_OPEN 握手超时 (${_openTimeout.inSeconds}s)');
      }
    });

    final l2 = buildNaviOpen(w, h, fps, quality);
    _pendingControlSeq = sendControl(l2);
    _log(
        '→ NAVI_OPEN ${w}x$h @${fps}fps q=$quality% (L1 seq=$_pendingControlSeq)');
    return completer.future;
  }

  /// 发送 NAVI_CLOSE 并清理。
  void close({int reason = NaviProjCloseReason.normal}) {
    if (_state == NaviProjState.idle) return;
    final prev = _state;
    _cancelTimers();
    _state = NaviProjState.idle;
    _credits = 0;
    _retxFrames.clear();
    _openCompleter = null;
    _wakeCredit(false);
    if (prev != NaviProjState.idle) {
      sendControl(buildNaviClose(reason));
      _log('→ NAVI_CLOSE reason=0x${reason.toRadixString(16)}');
    }
  }

  /// 传输断开时调用 (不发送 CLOSE)。
  void onDisconnect() {
    _cancelTimers();
    _openCompleter?.complete(false);
    _openCompleter = null;
    _state = NaviProjState.idle;
    _credits = 0;
    _wakeCredit(false);
    _retxFrames.clear();
    _creditStallCount = 0;
  }

  // ──────────────────────────────────────────────────────────────────
  // 控制通道入站 (FFD2 → L1 → 此层)
  // ──────────────────────────────────────────────────────────────────

  /// 控制通道 L1 ACK 回调。seq 匹配 [sendControl] 返回值。
  void onControlL1Ack(int seq, bool ok) {
    if (seq != _pendingControlSeq) return;
    _pendingControlSeq = null;
    if (!ok) {
      _failOpen('L1 NAK for control frame seq=$seq');
    }
    // L1 ACK 仅确认送达；真正的握手结果在 onControlL2(NAVI_ACK) 中。
  }

  /// 控制通道收到的 L2 payload (来自 FFD2 → L1 解帧)。
  /// 仅处理 CMD=0x11 且 key=ACK/ERROR 的消息。
  void onControlL2(Uint8List l2) {
    if (l2.length < 5 || l2[0] != BleCmd.naviProj) return;
    final key = l2[2];
    final vlen = _readU16(l2, 3);
    final value = Uint8List.sublistView(l2, 5, (5 + vlen).clamp(5, l2.length));

    if (key == BleCmdNaviProjKey.ack && _state == NaviProjState.opening) {
      _onAck(value);
    } else if (key == BleCmdNaviProjKey.error) {
      final err = parseNaviError(value);
      if (err != null) {
        _log('← NAVI_ERROR code=0x${err.$1.toRadixString(16)} '
            'frameSeq=${err.$2}');
      }
    }
  }

  void _onAck(Uint8List value) {
    _openTimer?.cancel();
    final parsed = parseNaviAck(value);
    if (parsed == null) {
      _failOpen('NAVI_ACK 格式错误');
      return;
    }
    final (result, maxChunk, initCredits) = parsed;

    if (result != NaviProjResult.ok) {
      _state = NaviProjState.idle;
      _openCompleter?.complete(false);
      _openCompleter = null;
      _log('← NAVI_ACK REJECTED: ${NaviProjResult.label(result)}');
      return;
    }

    _state = NaviProjState.open;
    _maxChunk = maxChunk > 0 ? maxChunk : 496;

    // 强制 credit flow control: 若设备返回 0xFFFF 则视为错误。
    if (initCredits == 0xFFFF) {
      _log('← NAVI_ACK 设备请求无限信用模式 — 拒绝 (导航投屏强制流控)');
      _state = NaviProjState.idle;
      _openCompleter?.complete(false);
      _openCompleter = null;
      sendControl(buildNaviClose(NaviProjCloseReason.creditTimeout));
      return;
    }
    _credits = initCredits;
    _creditStallCount = 0;
    _log('← NAVI_ACK OK maxChunk=$_maxChunk initCredits=$_credits');
    _openCompleter?.complete(true);
    _openCompleter = null;
  }

  // ──────────────────────────────────────────────────────────────────
  // 数据通道入站 (FFD4 notify → 此层)
  // ──────────────────────────────────────────────────────────────────

  /// 数据通道收到的裸 L2 通知 (FFD4 notify)。
  void onDataNotify(Uint8List l2) {
    if (l2.length < 5 || l2[0] != BleCmd.naviProj) return;
    final key = l2[2];
    final vlen = _readU16(l2, 3);
    final value = Uint8List.sublistView(l2, 5, (5 + vlen).clamp(5, l2.length));

    if (key == BleCmdNaviProjKey.credit) {
      _onCredit(value);
    } else if (key == BleCmdNaviProjKey.report) {
      _onReport(value);
    }
  }

  void _onCredit(Uint8List value) {
    final n = parseNaviCredit(value);
    if (n == null || n <= 0) return;
    _credits += n;
    _creditStallCount = 0;
    _wakeCredit(true);
    _log('← CREDIT +$n → 剩余=$_credits');
  }

  Future<void> _onReport(Uint8List value) async {
    final parsed = parseNaviReport(value);
    if (parsed == null) return;
    final (repSeq, gapCount, gaps) = parsed;

    final buf = _retxFrames[repSeq];
    if (buf == null) {
      _log('← REPORT seq=$repSeq gapCount=$gapCount (retx buffer 已释放)');
      return;
    }

    if (gapCount == 0) {
      _retxFrames.remove(repSeq);
      _log('← REPORT seq=$repSeq 完整确认');
      return;
    }

    _log('← REPORT seq=$repSeq gapCount=$gapCount → 重传');
    // 找到与缺口重叠的所有 chunk
    final retxOffs = <int>{};
    for (final (gs, ge) in gaps) {
      buf.forEach((boff, entry) {
        if (boff < ge && boff + entry.chunk.length > gs) retxOffs.add(boff);
      });
    }
    final sorted = retxOffs.toList()..sort();
    for (final boff in sorted) {
      if (_state != NaviProjState.open) break;
      final entry = buf[boff];
      if (entry == null) continue;
      try {
        await sendData(
            buildNaviChunk(repSeq, boff, entry.totalLen, entry.chunk));
      } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // 帧发送 (数据通道)
  // ──────────────────────────────────────────────────────────────────

  /// 发送一帧完整 JPEG。返回 false 表示帧被丢弃 (credit 超时 / 会话关闭)。
  ///
  /// 每一帧按 [chunkSize] 拆分、分片发送。每一片消耗 1 credit。
  /// credit 不足时阻塞等待（最长 [_creditTimeout]），超时则丢弃当前帧。
  /// 连续丢弃 ≥[_maxStallBeforeError] 帧后 session 自动进入错误状态。
  Future<bool> sendFrame(Uint8List jpeg) async {
    if (_state != NaviProjState.open) return false;
    final cs = chunkSize();
    if (cs < 1) return false;
    final seq = _frameSeq;
    _frameSeq = (_frameSeq + 1) & 0xFFFF;
    final total = jpeg.length;

    // 注册 retransmit buffer
    final retxBuf = <int, _RetxEntry>{};
    _retxFrames[seq] = retxBuf;
    while (_retxFrames.length > 3) {
      _retxFrames.remove(_retxFrames.keys.first);
    }

    bool failed = false;
    Future<void>? last;
    for (int off = 0; off < total; off += cs) {
      // 等待 credit
      while (_credits <= 0) {
        final got = await _waitCredit();
        if (!got || _state != NaviProjState.open) {
          _creditStallCount++;
          _log('✗ credit 超时 seq=$seq @off=$off/$total '
              '(连续丢帧 $_creditStallCount/$_maxStallBeforeError)');
          if (_creditStallCount >= _maxStallBeforeError) {
            _log('✗ 连续 $_maxStallBeforeError 帧 credit 超时, 投屏中断');
            _state = NaviProjState.idle;
            _wakeCredit(false);
            sendControl(buildNaviClose(NaviProjCloseReason.creditTimeout));
          }
          return false;
        }
        if (_state != NaviProjState.open) return false;
      }
      _credits--;

      final end = (off + cs < total) ? off + cs : total;
      final chunk = Uint8List.sublistView(jpeg, off, end);
      retxBuf[off] = _RetxEntry(chunk, total);
      final p = sendData(buildNaviChunk(seq, off, total, chunk));
      p.catchError((_) {
        failed = true;
      });
      last = p;
    }

    // 正常完成一帧，重置 credit 饥饿计数
    _creditStallCount = 0;

    if (last != null) {
      try {
        await last;
      } catch (_) {
        failed = true;
      }
    }
    return !failed && _state == NaviProjState.open;
  }

  // ──────────────────────────────────────────────────────────────────
  // Credit wait helpers
  // ──────────────────────────────────────────────────────────────────

  Future<bool> _waitCredit() {
    if (_credits > 0) return Future.value(true);
    final c = Completer<bool>();
    _creditCompleter = c;
    _creditTimer?.cancel();
    _creditTimer = Timer(_creditTimeout, () {
      if (_creditCompleter == c) _creditCompleter = null;
      if (!c.isCompleted) c.complete(false);
    });
    return c.future;
  }

  void _wakeCredit(bool ok) {
    _creditTimer?.cancel();
    final w = _creditCompleter;
    _creditCompleter = null;
    if (w != null && !w.isCompleted) w.complete(ok);
  }

  // ──────────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────────

  void _failOpen(String reason) {
    _log('✗ $reason');
    _cancelTimers();
    _openCompleter?.complete(false);
    _openCompleter = null;
    _state = NaviProjState.idle;
    _credits = 0;
    _wakeCredit(false);
  }

  void _cancelTimers() {
    _openTimer?.cancel();
    _creditTimer?.cancel();
  }

  void _log(String msg) => onLog?.call(msg);
}
