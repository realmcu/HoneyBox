import 'dart:async';
import 'dart:io';

// Uint8List 由 flutter/services 转出,不再单独 import 'dart:typed_data'
// —— unnecessary_import 会告警。
import 'package:flutter/services.dart';

import 'ebadge_protocol.dart';

/// eBadge 协议 §5 的 Wi-Fi 数据面：连设备 SoftAP + 裸 TCP 上传文件正文。
///
/// 与 [EBadgeLink]（BLE 控制面）的分工：控制面负责握手（Offer / Decision /
/// AP_INFO）和结果（Progress / Done / Fail），本类只管「连上热点，把 EBXF 头 +
/// 正文推过去，读回 EBXR」这一段。两条通道在传图期间**同时**在用 —— BLE 不走 IP
/// 栈，进程网络绑到设备热点上不影响 GATT 通知。
///
/// 刻意不复用 [TcpVideoClient]（`wifi_transport.dart`）：那个走的是 WiFi 投屏的
/// `0xA5 0xA9` 6 字节帧头、按帧连续推流、不读应答；这里是单文件单连接、40 字节
/// EBXF 头、传完必须读 8 字节 EBXR 再关。两套帧格式互不兼容，混在一个类里只会让
/// 两边都难读。
class EBadgeWifiTransport {
  EBadgeWifiTransport({MethodChannel? channel})
      : _ch = channel ?? const MethodChannel('ebadge/wifi');

  final MethodChannel _ch;

  /// §4.7 定稿默认值。AP_INFO 一般会带真值，这里只作兜底。
  static const String defaultIpv4 = '192.168.4.1';
  static const int defaultPort = 9000;

  bool _joined = false;
  bool get joined => _joined;

  // ── STA:连设备热点 ──────────────────────────────────────────────────

  /// 连上 [ssid]。返回 null 表示成功，否则返回给人看的失败原因。
  ///
  /// 原生侧连上后会 `bindProcessToNetwork`，让本进程的 `Socket.connect` 落到这张
  /// 无外网的热点上 —— 否则请求会走蜂窝数据出去，`192.168.4.1` 必然不可达。
  /// 副作用是**绑定期间 App 其它网络功能（如检查更新）都会失败**，所以务必配对
  /// 调用 [leave]，并且放在 finally 里。
  ///
  /// [timeout] 对齐协议 §5.5 的「Decision 同意 → STA 关联成功 60 s」。
  Future<String?> join({
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final bound = await _ch.invokeMethod<bool>('joinAp', {
        'ssid': ssid,
        'password': password,
        'timeoutMs': timeout.inMilliseconds,
      });
      _joined = true;
      if (bound != true) {
        // 连上了但没绑成功。不直接判失败 —— 万一默认路由碰巧可达就还能传，
        // 但要把话说清楚，否则后面 TCP 超时会被误当成设备问题。
        return null;
      }
      return null;
    } on PlatformException catch (e) {
      _joined = false;
      return e.message ?? e.code;
    } on MissingPluginException {
      _joined = false;
      return '当前平台不支持连接指定 Wi-Fi（仅 Android）';
    }
  }

  /// 断开并解除进程网络绑定。幂等,失败只吞掉 —— 清理路径上再抛异常没有意义。
  Future<void> leave() async {
    _joined = false;
    try {
      await _ch.invokeMethod<void>('leaveAp');
    } catch (_) {}
  }

  // ── TCP:推 EBXF 头 + 正文,读 EBXR ──────────────────────────────────

  /// 按 §5.2 上传一个文件，返回设备的 EBXR 应答。
  ///
  /// [onProgress] 给的是**本机已写出**的字节数,不等于设备已收 —— 后者以 BLE
  /// 0x14 PROGRESS 为准。TCP 的 write 只是进了内核缓冲。
  ///
  /// [crc32] 必须与 Offer 里的 TLV_XFER_CRC32 一致（§5.2 校验规则第 3 条），
  /// 所以由调用方传入而不在这里重算 —— 重算一遍反而掩盖了两处不一致的 bug。
  Future<EBadgeWifiResult> upload({
    required String ip,
    required int port,
    required String name,
    required int fileType,
    required Uint8List body,
    required int crc32,
    void Function(int sent, int total)? onProgress,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration ackTimeout = const Duration(seconds: 120),
    int chunkSize = 8 * 1024,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: connectTimeout);
    } catch (e) {
      return EBadgeWifiResult.error('TCP 连接 $ip:$port 失败：$e');
    }

    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    // 应答只有 8 字节且传完才来,但监听必须在写之前就挂上 —— 设备可能在校验失败
    // 时立刻回 EBXR 并关连接,那时我们还在写正文。晚挂就漏掉了。
    final ackBuf = <int>[];
    final ackDone = Completer<EBadgeXferAck?>();
    late StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (data) {
        ackBuf.addAll(data);
        if (ackBuf.length >= EBadgeXferAck.length && !ackDone.isCompleted) {
          ackDone.complete(
            EBadgeXferAck.parse(Uint8List.fromList(ackBuf)),
          );
        }
      },
      onError: (Object e) {
        if (!ackDone.isCompleted) ackDone.completeError(e);
      },
      // 设备关连接时若还没攒够 8 字节,说明它没打算回应答(§5.2 校验失败会直接
      // close),用 null 表示「无应答」而不是挂死等超时。
      onDone: () {
        if (!ackDone.isCompleted) ackDone.complete(null);
      },
      cancelOnError: true,
    );

    try {
      final header = EBadgeXferHeader.build(
        fileType: fileType,
        name: name,
        size: body.length,
        crc32: crc32,
      );
      socket.add(header);
      await socket.flush();

      // 分块写并 flush:一次 add 整个大文件会把它全压进内核缓冲,进度条直接从 0
      // 跳到 100,也失去了 TCP 天然的背压。
      for (var o = 0; o < body.length; o += chunkSize) {
        final end = (o + chunkSize < body.length) ? o + chunkSize : body.length;
        socket.add(Uint8List.sublistView(body, o, end));
        await socket.flush();
        onProgress?.call(end, body.length);
      }

      final ack = await ackDone.future.timeout(
        ackTimeout,
        onTimeout: () => throw TimeoutException('等待 EBXR 应答超时'),
      );
      if (ack == null) {
        return const EBadgeWifiResult.error('设备未回 EBXR 应答就关闭了连接');
      }
      return EBadgeWifiResult.ok(ack);
    } on TimeoutException catch (e) {
      return EBadgeWifiResult.error(
        '${e.message ?? "超时"}（协议 §5.5 限 ${ackTimeout.inSeconds}s）',
      );
    } catch (e) {
      return EBadgeWifiResult.error('上传失败：$e');
    } finally {
      await sub.cancel();
      try {
        await socket.close();
      } catch (_) {}
      socket.destroy();
    }
  }
}

/// [EBadgeWifiTransport.upload] 的结果。
///
/// 区分「传输本身失败」（[error] 非空，连不上 / 超时 / 没应答）和「设备回了应答但
/// 判定失败」（[ack] 非空且 `status=0`）—— 前者是本机或链路问题，后者是设备明确
/// 给出了 §2.6 错误码，两种要给用户看不一样的话。
class EBadgeWifiResult {
  const EBadgeWifiResult.ok(this.ack) : error = null;
  const EBadgeWifiResult.error(this.error) : ack = null;

  final EBadgeXferAck? ack;
  final String? error;

  bool get succeed => ack?.succeed ?? false;

  /// 给日志用的一行摘要。
  String describe() {
    if (error != null) return error!;
    final a = ack!;
    if (a.succeed) return 'EBXR status=成功';
    return 'EBXR status=失败 reason=0x${a.reason.toRadixString(16).padLeft(2, '0')} '
        '${EBadgeXferError.name(a.reason)}';
  }
}
