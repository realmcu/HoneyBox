import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

/// WiFi video framing + TCP transport — ported from desk-mate's
/// `tabs/stream.py` (6-byte frame header) and `tcp_worker.py` (socket I/O).
///
/// Unlike the BLE Stream Service (credit-flow L2 protocol), the WiFi channel is
/// a plain framed byte stream: each frame is
/// `[0xA5,0xA9] + seq(1) + len(2 LE) + checksum(1) + encoded data`, written
/// continuously to a TCP socket with no ACK / credits. The device slices frames
/// from the byte stream by the fixed 6-byte header. Works for MSV1 / JPEG /
/// H.264 alike (H.264 relies on TCP's ordered, lossless delivery).
class WifiFrame {
  WifiFrame._();

  static const int magic0 = 0xA5;
  static const int magic1 = 0xA9;
  static const int headerLen = 6;

  /// Max encoded bytes representable by the 2-byte length field (64 KB).
  static const int maxFrame = 0xFFFF;

  /// Build the 6-byte header. checksum = (seq + len_lo + len_hi) & 0xFF.
  static Uint8List buildHeader(int seq, int dataLen) {
    final h = Uint8List(headerLen);
    h[0] = magic0;
    h[1] = magic1;
    h[2] = seq & 0xFF;
    h[3] = dataLen & 0xFF; // little-endian length
    h[4] = (dataLen >> 8) & 0xFF;
    h[5] = (h[2] + h[3] + h[4]) & 0xFF;
    return h;
  }

  /// Prepend the 6-byte header to [data], returning the complete frame bytes.
  static Uint8List wrap(Uint8List data, int seq) {
    final out = Uint8List(headerLen + data.length);
    out.setRange(0, headerLen, buildHeader(seq, data.length));
    out.setRange(headerLen, out.length, data);
    return out;
  }
}

/// A TCP client that connects to the device's video server and writes framed
/// video. One connection carries the whole projection session.
class TcpVideoClient {
  Socket? _socket;
  bool _connected = false;
  int _seq = 0; // 0–255 frame counter, wraps

  /// Fired when the socket drops (peer close / error) after a successful
  /// connect. Not fired for a failed initial [connect].
  void Function()? onDisconnected;

  bool get isConnected => _connected;
  String? host;
  int? port;

  /// Connect to [ip]:[port]. Returns true on success. [timeout] bounds the
  /// TCP handshake.
  Future<bool> connect(
    String ip,
    int port, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await close();
    try {
      final s = await Socket.connect(ip, port, timeout: timeout);
      try {
        s.setOption(SocketOption.tcpNoDelay, true); // low-latency small frames
      } catch (_) {}
      _socket = s;
      _connected = true;
      host = ip;
      this.port = port;
      _seq = 0;
      // Drain inbound bytes (device may echo/keepalive); detect drop via done.
      s.listen(
        (_) {},
        onError: (Object e) {
          debugPrint('WiFi/TCP 接收错误: $e');
          _handleDrop();
        },
        onDone: _handleDrop,
        cancelOnError: true,
      );
      debugPrint('WiFi/TCP 已连接 $ip:$port');
      return true;
    } catch (e) {
      debugPrint('WiFi/TCP 连接失败 $ip:$port → $e');
      _connected = false;
      _socket = null;
      return false;
    }
  }

  void _handleDrop() {
    if (!_connected) return;
    _connected = false;
    _socket = null;
    debugPrint('WiFi/TCP 连接已断开');
    onDisconnected?.call();
  }

  /// Wrap [encoded] with the 6-byte header and write it to the socket, then
  /// flush (giving natural TCP backpressure). Returns false if not connected,
  /// the frame exceeds 64 KB, or the write fails. The frame counter advances
  /// only on a frame actually handed to the socket.
  Future<bool> sendFrame(Uint8List encoded) async {
    final s = _socket;
    if (!_connected || s == null) return false;
    if (encoded.length > WifiFrame.maxFrame) {
      debugPrint('WiFi/帧过大 ${encoded.length}B > ${WifiFrame.maxFrame}B，跳过');
      return false;
    }
    final seq = _seq;
    _seq = (_seq + 1) & 0xFF;
    try {
      s.add(WifiFrame.wrap(encoded, seq));
      await s.flush();
      return true;
    } catch (e) {
      debugPrint('WiFi/TCP 发送失败: $e');
      _handleDrop();
      return false;
    }
  }

  Future<void> close() async {
    final s = _socket;
    _socket = null;
    _connected = false;
    if (s != null) {
      try {
        await s.flush().timeout(const Duration(milliseconds: 300),
            onTimeout: () {});
      } catch (_) {}
      try {
        await s.close();
      } catch (_) {}
      s.destroy();
    }
  }
}
