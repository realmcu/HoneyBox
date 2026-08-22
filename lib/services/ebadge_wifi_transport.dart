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

  /// §4.9 定稿默认值。AP_INFO 一般会带真值，这里只作兜底。
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
    final total = body.length;

    // 失败时这两个值就是全部线索,所以在最外层声明 —— 每条 return 路径都能带上它们。
    var sent = 0;
    var headerSent = false;

    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: connectTimeout);
    } catch (e) {
      return EBadgeWifiResult.fail(
        EBadgeWifiFailure.connect,
        totalBytes: total,
        detail: 'TCP 连接 $ip:$port 失败：$e',
      );
    }

    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    // 应答只有 8 字节且传完才来,但监听必须在写之前就挂上 —— 设备可能在校验失败
    // 时立刻回 EBXR 并关连接,那时我们还在写正文。晚挂就漏掉了。
    //
    // 这里刻意**只攒字节、不解析**:是「一个字节都没回」「回短了」还是「回的不是
    // EBXR」要分开报,而 [EBadgeXferAck.parse] 把这三种都变成 null。判定留给
    // [finish]。
    final ackBuf = <int>[];
    final ackDone = Completer<void>();
    void settle() {
      if (!ackDone.isCompleted) ackDone.complete();
    }

    late StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (data) {
        ackBuf.addAll(data);
        if (ackBuf.length >= EBadgeXferAck.length) settle();
      },
      onError: (Object _) => settle(),
      // 设备关连接时若还没攒够 8 字节,说明它没打算回完整应答(§5.2 校验失败会
      // 直接 close),立刻结束等待而不是挂死到超时。
      onDone: settle,
      cancelOnError: true,
    );

    /// 按收到的字节数判定结局。多处调用 —— 正常写完后要判,写到一半被设备打断
    /// 时如果已经收到字节也要判(那说明它先回了应答再关连接)。
    EBadgeWifiResult finish() {
      final raw = Uint8List.fromList(ackBuf);
      if (raw.isEmpty) {
        return EBadgeWifiResult.fail(
          sent >= total
              ? EBadgeWifiFailure.ackMissing
              : EBadgeWifiFailure.closedWhileSending,
          bytesSent: sent,
          totalBytes: total,
          headerSent: headerSent,
        );
      }
      if (raw.length < EBadgeXferAck.length) {
        return EBadgeWifiResult.fail(
          EBadgeWifiFailure.ackTruncated,
          bytesSent: sent,
          totalBytes: total,
          headerSent: headerSent,
          ackRaw: raw,
        );
      }
      final ack = EBadgeXferAck.parse(raw);
      if (ack == null) {
        return EBadgeWifiResult.fail(
          EBadgeWifiFailure.ackMalformed,
          bytesSent: sent,
          totalBytes: total,
          headerSent: headerSent,
          ackRaw: raw,
        );
      }
      return EBadgeWifiResult.ok(
        ack,
        bytesSent: sent,
        totalBytes: total,
        headerSent: headerSent,
      );
    }

    try {
      final header = EBadgeXferHeader.build(
        fileType: fileType,
        name: name,
        size: total,
        crc32: crc32,
      );
      socket.add(header);
      await socket.flush();
      headerSent = true;

      // 分块写并 flush:一次 add 整个大文件会把它全压进内核缓冲,进度条直接从 0
      // 跳到 100,也失去了 TCP 天然的背压。
      for (var o = 0; o < total; o += chunkSize) {
        final end = (o + chunkSize < total) ? o + chunkSize : total;
        socket.add(Uint8List.sublistView(body, o, end));
        await socket.flush();
        // 先记账再回调:回调里若抛异常,已写字节数也不能丢。
        sent = end;
        onProgress?.call(end, total);
      }

      await ackDone.future.timeout(
        ackTimeout,
        onTimeout: () => throw TimeoutException('等待 EBXR 应答超时'),
      );
      return finish();
    } on TimeoutException catch (e) {
      // 超时前已经收到几个字节 —— 那是「固件应答写短了」,比「超时」具体得多。
      if (ackBuf.isNotEmpty) return finish();
      return EBadgeWifiResult.fail(
        EBadgeWifiFailure.ackTimeout,
        bytesSent: sent,
        totalBytes: total,
        headerSent: headerSent,
        detail: '${e.message ?? "超时"}（协议 §5.5 限 ${ackTimeout.inSeconds}s）',
      );
    } on SocketException {
      // 写的过程中设备把连接掐了。若它掐之前回过字节,那是应答而不是「写挂了」。
      if (ackBuf.isNotEmpty) return finish();
      return EBadgeWifiResult.fail(
        EBadgeWifiFailure.closedWhileSending,
        bytesSent: sent,
        totalBytes: total,
        headerSent: headerSent,
      );
    } catch (e) {
      return EBadgeWifiResult.fail(
        EBadgeWifiFailure.socket,
        bytesSent: sent,
        totalBytes: total,
        headerSent: headerSent,
        detail: '上传失败：$e',
      );
    } finally {
      await sub.cancel();
      try {
        await socket.close();
      } catch (_) {}
      socket.destroy();
    }
  }
}

/// [EBadgeWifiTransport.upload] 失败的**具体环节**。
///
/// 分这么细是因为每一种对应完全不同的下一步排查动作:连不上是热点/IP 层的事,
/// 设备中途关连接是它嫌数据不对,应答短了或 magic 不对是固件的应答实现有问题。
/// 全都报成「上传失败」的话,调试的人只能一个个去猜。
enum EBadgeWifiFailure {
  none,

  /// TCP 连不上 —— 热点、IP、端口这一层的问题,一个字节都没发出去。
  connect,

  /// 设备在正文写完之前就关了连接。§5.2 校验失败时设备会直接 close,
  /// 所以这里的**已写字节数**就是它开始不满意的位置。
  closedWhileSending,

  /// 正文全部写出去了,但设备一个字节都没回就关连接。
  ackMissing,

  /// 设备回了 1–7 字节就关连接 —— EBXR 要 8 字节,固件把应答写短了。
  ackTruncated,

  /// 回够 8 字节但 magic 不是 'EBXR' —— 设备发的是别的东西,不是应答。
  ackMalformed,

  /// 等应答超时,连接还开着 —— 设备收下了但一直没给结论。
  ackTimeout,

  /// 其它 socket 异常。
  socket,
}

/// [EBadgeWifiTransport.upload] 的结果。
///
/// 区分「传输本身失败」（[failure] 非 none）和「设备回了应答但判定失败」
/// （[ack] 非空且 `status=0`）—— 前者是本机或链路问题，后者是设备明确给出了
/// §2.6 错误码，两种要给用户看不一样的话。
///
/// **失败时一定带上 [bytesSent] / [totalBytes]**:「0 字节就失败」和「99% 处失败」
/// 指向完全不同的原因,只给一句错误文本等于把最有用的线索丢掉。
class EBadgeWifiResult {
  const EBadgeWifiResult.ok(
    this.ack, {
    this.bytesSent = 0,
    this.totalBytes = 0,
    this.headerSent = false,
  })  : failure = EBadgeWifiFailure.none,
        ackRaw = null,
        _detail = null;

  const EBadgeWifiResult.fail(
    this.failure, {
    this.bytesSent = 0,
    this.totalBytes = 0,
    this.headerSent = false,
    this.ackRaw,
    String? detail,
  })  : ack = null,
        _detail = detail;

  final EBadgeXferAck? ack;

  final EBadgeWifiFailure failure;

  /// 本机已 flush 出去的**正文**字节数(不含 40B 头)。
  final int bytesSent;

  /// 正文总长。
  final int totalBytes;

  /// 40 字节 EBXF 头是否已 flush 出去。
  ///
  /// 单独一个 flag 而不是折进 [bytesSent]:头没出去说明连接刚建就断了(路由/热点
  /// 层面),头出去了正文却卡在 0 说明设备读到头就不满意(§5.2 校验)—— 两种查的
  /// 地方完全不同,混成一个数字就分不出来了。
  final bool headerSent;

  /// 设备实际回过来的原始字节。应答短了或 magic 不对时,这几个字节是唯一线索,
  /// 必须原样带出来给人看 —— 「不是 EBXR」远不如「它回的是 45 42 58 46」有用。
  final Uint8List? ackRaw;

  /// 异常文本之类的补充,由构造方填。
  final String? _detail;

  bool get succeed => ack?.succeed ?? false;

  /// 失败原因文本;成功(含设备判失败)时为 null。
  ///
  /// 保持 null 语义不变:设备回了应答说「失败」不算 [error] —— 那是业务结果,
  /// 不是链路故障,调用方要分开处理。
  String? get error =>
      failure == EBadgeWifiFailure.none ? null : '$_reasonText（$progressText）';

  /// 「到底传出去了多少」的一行摘要 —— 失败排查时最先要看的就是这个。
  String get progressText {
    if (!headerSent) {
      return failure == EBadgeWifiFailure.connect
          ? '未建立连接，0 字节发出'
          : '40B EBXF 头都没写出去';
    }
    const head = '40B 头已发';
    if (totalBytes <= 0) return '$head，正文为空';
    if (bytesSent == 0) return '$head，正文 0/$totalBytes B（0%）';
    final pct = (bytesSent / totalBytes * 100).toStringAsFixed(1);
    return '$head，正文 $bytesSent/$totalBytes B（$pct%）';
  }

  String get _reasonText => switch (failure) {
        EBadgeWifiFailure.none => '',
        EBadgeWifiFailure.connect => _detail ?? 'TCP 连接失败',
        EBadgeWifiFailure.closedWhileSending =>
          '设备在正文写完前就关闭了连接 —— §5.2 校验失败时设备会直接 close，'
              '已写字节数即它开始拒收的位置',
        EBadgeWifiFailure.ackMissing => '正文已全部写出，但设备一个字节都没回就关闭了连接',
        EBadgeWifiFailure.ackTruncated => '设备只回了 ${ackRaw?.length ?? 0} 字节就关闭连接'
            '（EBXR 应答需 ${EBadgeXferAck.length} 字节）：${_ackHex()}',
        EBadgeWifiFailure.ackMalformed =>
          '设备回了 ${ackRaw?.length ?? 0} 字节，但开头不是 EBXR'
              '（应为 45 42 58 52）：${_ackHex()}',
        EBadgeWifiFailure.ackTimeout => _detail ?? '等待 EBXR 应答超时',
        EBadgeWifiFailure.socket => _detail ?? 'socket 异常',
      };

  String _ackHex() {
    final r = ackRaw;
    if (r == null || r.isEmpty) return '(无)';
    return EBadgeCodec.hex(r, max: 16);
  }

  /// 给日志用的一行摘要。
  String describe() {
    if (failure != EBadgeWifiFailure.none) return error!;
    final a = ack!;
    if (a.succeed) return 'EBXR status=成功（$progressText）';
    return 'EBXR status=失败 reason=0x${a.reason.toRadixString(16).padLeft(2, '0')} '
        '${EBadgeXferError.name(a.reason)}（$progressText）';
  }
}
