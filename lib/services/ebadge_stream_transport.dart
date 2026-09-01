import 'dart:async';
import 'dart:collection';
import 'dart:io';

// Uint8List 由 flutter/services 转出,不再单独 import 'dart:typed_data'
// —— unnecessary_import 会告警。
import 'package:flutter/services.dart';

import 'ebadge_protocol.dart';

/// 一次 [EBadgeStreamTransport.sendFrame] 的结果。
///
/// **为什么要把「错误」和「警告」分成两个字段**:原来两者共用一个 `String?` 返回值,
/// 于是「设备关了连接」(实证)和「App 自己算出帧间隔超了 3 s」(推测)在调用方看来
/// 一模一样,都会把会话拆掉。而后者本身还是一次**成功**的写出 —— 计数器都加过了。
///
/// 类型上分开而不是靠约定,是因为这个错误犯过一次:只要两者还是同一个 `String?`,
/// 下一处调用就还会 `if (e != null) abort()`。
class EBadgeFrameOutcome {
  const EBadgeFrameOutcome({this.error, this.warning, this.diagnosis});

  /// 一切正常。
  static const ok = EBadgeFrameOutcome();

  /// 会话应当停止的原因。**只在有实证时非空** —— 设备关了连接、socket 写失败、
  /// 未连接。App 自己推算出来的异常一律走 [warning]。
  final String? error;

  /// 异常但会话继续。调用方该把它记进日志给人看,不该据此拆会话。
  final String? warning;

  /// 警告的成因拆解(哪一侧的问题)。仅 [warning] 非空时有值。
  final EBadgeGapCause? diagnosis;

  bool get isOk => error == null && warning == null;
}

/// 帧间隔异常的归因。
///
/// 这是排查这条链路的**核心分岔**:同样一句「距上一帧 3200ms」,底下是两件相反的
/// 事,处置也相反。混在一句话里报,等于把排查工作留给读日志的人。
enum EBadgeGapCause {
  /// 推送侧背压:间隔期间有帧被跳过([EBadgeStreamTransport.framesSkipped] 在涨),
  /// 说明帧源在产、是我们写不出去 —— 设备读得比我们发得慢,或已经不读了。
  ///
  /// 处置:往下调 JPEG 质量或帧率。
  backpressure,

  /// 帧源饿死:间隔期间**一帧都没被跳过**,说明 `nextFrame` 一直没给出画面 ——
  /// 摄像头帧槽空着(相机卡住/帧率太低),或内置帧没预热。
  ///
  /// 处置:查相机侧,调质量没有用。
  starvation,
}

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
  /// [stallLimit] 只为测试留的缝:默认就是 [frameGapLimit],生产路径不要传。
  EBadgeStreamTransport({Duration? stallLimit})
      : _stallLimit = stallLimit ?? frameGapLimit;

  /// §6.4 的帧超时:设备侧「帧超时 3 秒,清理资源,流程结束」。这里当作**发送侧
  /// 的自检上限** —— 相邻两帧间隔超过它,设备很可能已经把会话拆了,再推也是白推,
  /// 所以要让调用方立刻知道。
  static const Duration frameGapLimit = Duration(seconds: 3);

  /// 「上一帧卡了多久算故障」的阈值。见 [frameGapLimit]。
  final Duration _stallLimit;

  /// 实时带宽的滑动窗口长度。
  ///
  /// **取 §6.4 的帧超时值不是随手选的**:窗口与设备的清理阈值对齐之后,「带宽读数
  /// 掉到 0」就等价于「这条连接上已经 3 s 没有字节出去」—— 也就是设备那边正好该
  /// 超时了。换成 1 s 或 5 s 都会让这个对应关系消失,读数就只是个数字,不再能当
  /// 判断依据用。
  static const Duration bandwidthWindow = frameGapLimit;

  /// 窗口短于这个值时不给读数。
  ///
  /// 刚连上的头几十毫秒里,单帧会把速率放大到荒谬的量级(0.5 ms 内推 40 KB ⇒
  /// 80 MB/s)。与其显示一个假数让人以为链路很快,不如明说还算不出来。
  static const Duration _minMeterSpan = Duration(milliseconds: 500);

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;

  var _framesSent = 0;
  var _bytesSent = 0;
  var _wireBytesSent = 0;
  var _framesSkipped = 0;
  var _gapWarnings = 0;
  DateTime? _lastFrameAt;
  Duration? _lastGap;
  EBadgeXferAck? _lastAck;
  String? _peerClosed;

  /// 带宽窗口里的样本:每次成功写出记一条(时刻 + 本帧线上字节)。
  ///
  /// 用队列而不是「累计字节 ÷ 累计时间」:后者是**整场的平均值**,推了两分钟之后
  /// 再拖质量滑条,平均值几乎不动 —— 而拖滑条的人要看的正是「刚才那一下有没有用」。
  /// 只有滑动窗口能立刻反映当下。
  final Queue<({DateTime at, int bytes})> _meter = Queue();

  /// 窗口的起点:第一帧写出的时刻。用它算跨度而不是用 connect 的时刻 —— 握手到首帧
  /// 之间那段空白不该被算进带宽的分母里。
  DateTime? _meterSince;

  /// 整场见过的最高瞬时带宽。
  int _peakBps = 0;

  /// 正在写出的那一帧:开始时刻 + 写完的 future。
  ///
  /// **这个字段是为了不让 `flush()` 并发**。dart:io 的 `IOSink.flush()` 在执行
  /// 期间会把 sink 标成 bound,此时第二个 `flush()`(以及 `close()`)直接抛
  /// `StateError('StreamSink is bound to a stream')`。而 §6 的推帧是**定时器
  /// 驱动**的:设备读得慢一点,TCP 收窗压住,`flush()` 就会迟迟不返回,下一个
  /// tick 照样进来写 —— 于是必然撞上。所以推帧必须自己串起来,不能靠「帧率低、
  /// 应该来得及」这种时间余量。
  ({DateTime since, Future<void> done})? _inFlight;

  bool get connected => _socket != null && _peerClosed == null;
  int get framesSent => _framesSent;

  /// 已推出的 payload 字节数(不含 14B 头)。
  int get bytesSent => _bytesSent;

  /// 已推出的**线上**字节数(payload + 每帧 14B 流头)。
  ///
  /// 和 [bytesSent] 并存而不是二选一:带宽要按这个算 —— 占的是真实链路,头也要过
  /// 网卡。而「设备收到多少图像数据」是 [bytesSent]。低帧率大图时两者差不到 0.1%,
  /// 但高帧率小图时头的占比很可观(1 KB 的帧头就占 1.4%),用错一个会让「码率对不
  /// 对得上设置」这种核对差出一截。
  int get wireBytesSent => _wireBytesSent;

  /// 最近 [bandwidthWindow] 内的实时带宽,单位**字节/秒**,按线上字节算。
  ///
  /// null 表示还算不出来(样本跨度不足 [_minMeterSpan],见那里的说明)。
  ///
  /// **窗口是「现在往前推 3 s」,不是「最后一帧往前推 3 s」** —— 所以停止推帧之后
  /// 这个数会自己往下掉、最终归零,而不是永远停在最后那一瞬的速率上。这正是它作为
  /// 故障读数的价值:画面卡住时带宽跟着掉到 0,一眼就能和「还在正常推」分开。
  int? get bandwidthBps {
    _trimMeter(DateTime.now());
    if (_meter.isEmpty) {
      // 推过帧但窗口已经空了 ⇒ 至少 3 s 没有字节出去。这是实打实的 0,不是「算不
      // 出来」—— 而且 0 恰好是设备该超时的那个点,必须报出来。
      return _meterSince == null ? null : 0;
    }
    final span = _meterSpan(DateTime.now());
    if (span < _minMeterSpan) return null;
    var sum = 0;
    for (final s in _meter) {
      sum += s.bytes;
    }
    return (sum * 1000 / span.inMilliseconds).round();
  }

  /// 整场的峰值瞬时带宽(字节/秒);没有过读数时为 0。
  ///
  /// 留着是因为**瞬时值抓不住**:拖滑条时人眼盯着的是当下那个数,而「这条链路到底
  /// 冲到过多少」得事后回看。峰值和当前值差得远就说明中途被压下来过。
  int get peakBandwidthBps => _peakBps;

  /// 整场平均带宽(字节/秒),按线上字节算;不足 [_minMeterSpan] 时为 null。
  ///
  /// 和 [bandwidthBps] 一起看才有意义:瞬时值是「现在」,这个是「整场」,两者拉开
  /// 就说明链路能力在会话期间变过。
  int? get averageBandwidthBps {
    final since = _meterSince;
    if (since == null) return null;
    final span = DateTime.now().difference(since);
    if (span < _minMeterSpan) return null;
    return (_wireBytesSent * 1000 / span.inMilliseconds).round();
  }

  /// 因为上一帧还没写完而被跳过的帧数。
  ///
  /// 这个数就是**推送侧背压**的指标:它在涨说明设备收得比我们发得慢(或已经不读
  /// 了),而不是帧源没产出。两者在屏上都表现为「画面不动」,分不开就没法排查。
  int get framesSkipped => _framesSkipped;

  /// 帧间隔超 §6.4 阈值的次数。
  ///
  /// 单独计数(而不是只报最后一次)是因为**一次和一直在发生是两种情况**:偶发一次
  /// 多半是设备侧某帧解码慢了,而持续累积说明这个帧率/质量组合根本跑不动。日志会
  /// 滚过去,这个数不会。
  int get gapWarnings => _gapWarnings;

  /// 最近一次成功推帧与其前一帧的间隔。首帧为 null。
  ///
  /// 暴露出来是为了让界面能显示**实际**帧间隔 —— 它和「协商的 fps」往往差很远,
  /// 而这个差值本身就是这条链路能力的读数。
  Duration? get lastGap => _lastGap;

  /// 上一帧成功写出的时刻。null 表示这条连接上还没推出过帧。
  DateTime? get lastFrameAt => _lastFrameAt;

  /// 是否有帧正在写出。调用方可据此跳过本 tick,省掉一次白取帧。
  bool get sending => _inFlight != null;

  /// 设备可选回的 EBXR 应答里最后一条。§6.3 写明这是「可选」的,所以 null 是正常
  /// 情况,不能当失败看。
  EBadgeXferAck? get lastAck => _lastAck;

  /// 设备主动断开的原因描述;未断开时为 null。
  String? get peerClosed => _peerClosed;

  /// 丢掉窗口外的样本。
  void _trimMeter(DateTime now) {
    final cutoff = now.subtract(bandwidthWindow);
    while (_meter.isNotEmpty && _meter.first.at.isBefore(cutoff)) {
      _meter.removeFirst();
    }
  }

  /// 当前窗口的有效跨度。
  ///
  /// 取「窗口长度」和「首帧至今」里更小的那个:会话刚开始 1 s 就把分母当 3 s 用,
  /// 会把读数压到实际的三分之一 —— 那会看起来像链路很差,而其实只是刚开始。
  Duration _meterSpan(DateTime now) {
    final since = _meterSince;
    if (since == null) return Duration.zero;
    final elapsed = now.difference(since);
    return elapsed < bandwidthWindow ? elapsed : bandwidthWindow;
  }

  /// 记一次成功写出。[wire] 是本帧的线上字节数(含 14B 头)。
  void _meterFrame(DateTime at, int wire) {
    _meterSince ??= at;
    _meter.add((at: at, bytes: wire));
    _trimMeter(at);
    // 峰值在这里更新而不是靠界面轮询:界面刷新频率跟不上帧率时,真正的尖峰会被
    // 整个漏掉 —— 而尖峰恰恰是「链路到底能跑多快」的答案。
    final bps = bandwidthBps;
    if (bps != null && bps > _peakBps) _peakBps = bps;
  }

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
    _wireBytesSent = 0;
    _framesSkipped = 0;
    _gapWarnings = 0;
    _lastFrameAt = null;
    _lastGap = null;
    _lastAck = null;
    _inFlight = null;
    // 带宽窗口也要清空:上一场会话的样本留下来,新会话头几秒的读数会是两场混算的
    // 结果 —— 而重连之后第一眼看的就是这个数。
    _meter.clear();
    _meterSince = null;
    _peakBps = 0;

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

  /// 推一帧。
  ///
  /// **上一帧还在写就跳过本帧**(计入 [framesSkipped],算成功 —— 跳帧不是错误,
  /// §6 允许丢帧,而重入会直接抛 `StreamSink is bound to a stream`)。跳过而不是
  /// 排队:排队意味着推出去的画面越来越旧,屏上像「延迟越攒越大」,而这会被误读成
  /// 设备解码慢。
  ///
  /// **返回值里 error 和 warning 是两回事**,见 [EBadgeFrameOutcome]:只有实证
  /// (对端断开、socket 写失败、未连接)才给 error;帧间隔/卡顿这类 App 自查出来的
  /// 异常一律是 warning,会话继续。这条区分是这个方法最重要的语义 —— 「间隔超了
  /// 3 s」是推测,而按推测拆掉一条其实还活着的会话,会把真正要观察的现象抹掉。
  ///
  /// [crc32] 缺省自算 —— §6.2 的 crc32 是对**本帧 payload** 的,没有「必须与
  /// 握手一致」的约束(那是 §5.2 的规则),所以这里自算是安全的。调试要构造坏帧
  /// 时可以显式传一个错的值进来。
  Future<EBadgeFrameOutcome> sendFrame(
    Uint8List payload, {
    int fileType = EBadgeFileType.jpegStream,
    int? crc32,
  }) async {
    final s = _socket;
    if (s == null) return const EBadgeFrameOutcome(error: 'TCP 未连接');
    if (_peerClosed != null) return EBadgeFrameOutcome(error: _peerClosed);
    if (payload.isEmpty) {
      return const EBadgeFrameOutcome(error: '空帧:payload 长度为 0');
    }

    final now = DateTime.now();

    // 上一帧还没写完 —— 让位给它,本帧丢掉。
    final busy = _inFlight;
    if (busy != null) {
      _framesSkipped++;
      final stalled = now.difference(busy.since);
      // 卡过 §6.4 的帧超时。这**同样只是警告**:写还在进行中,socket 没报错,设备
      // 也没关连接 —— 拆会话是我们自己的推测。真拆了反而看不到设备接下来的反应,
      // 而那正是调试台要观察的东西。
      if (stalled > _stallLimit) {
        _gapWarnings++;
        return EBadgeFrameOutcome(
          warning: '上一帧已写了 ${stalled.inMilliseconds}ms 仍未完成，'
              '已超 §6.4 的 ${_stallLimit.inMilliseconds}ms 帧超时，'
              '设备可能已清理会话（累计 $_gapWarnings 次）',
          diagnosis: EBadgeGapCause.backpressure,
        );
      }
      return EBadgeFrameOutcome.ok;
    }

    // 间隔自检:超过 §6.4 的 3 s,设备那边大概率已经清理掉会话了。只报不拦 ——
    // 「超时后设备是怎么反应的」本身就是要观察的现象。
    final last = _lastFrameAt;
    final gap = last == null ? Duration.zero : now.difference(last);
    // 归因要在写之前取样:间隔期间到底有没有帧被跳过,决定了这是背压还是帧源饿死。
    final skippedBefore = _framesSkipped;

    // add() 是同步入队、不会抛 bound;真正要串起来的是 flush()。两者一起纳入
    // _inFlight,否则下一帧的 add 会插到本帧的头和正文之间,线上字节就错位了。
    final done = Completer<void>();
    _inFlight = (since: now, done: done.future);
    try {
      s.add(EBadgeStreamHeader.build(
        fileType: fileType,
        size: payload.length,
        crc32: crc32 ?? eBadgeCrc32(payload),
      ));
      s.add(payload);
      await s.flush();
    } catch (e) {
      // 这里是实证 —— socket 真的写失败了,不是推测。
      return EBadgeFrameOutcome(error: '推帧失败：$e');
    } finally {
      // 失败也要解锁,否则一次异常之后每一帧都报「上一帧还在写」,真因被永久盖住。
      _inFlight = null;
      done.complete();
    }

    _framesSent++;
    _bytesSent += payload.length;
    // 带宽按**线上字节**算:头也占链路。用 EBadgeStreamHeader.length 而不是写 14,
    // 头长将来改了这里不该悄悄算错。
    final wire = payload.length + EBadgeStreamHeader.length;
    _wireBytesSent += wire;
    _lastFrameAt = now;
    _lastGap = last == null ? null : gap;
    // 取样时刻用 now(开始写的时刻)而不是此刻:窗口衡量的是「帧以什么节奏离开
    // App」,而一帧卡在满收窗上的那段时间属于背压,已经由 framesSkipped 记着了。
    _meterFrame(now, wire);

    if (last != null && gap > frameGapLimit) {
      _gapWarnings++;
      // 间隔期间有帧被跳过 ⇒ 帧源在产、是我们写不出去(背压);一帧都没跳过 ⇒
      // 帧源根本没给画面(饿死)。两者处置相反,所以必须在报的时候就分开。
      final cause = _framesSkipped > skippedBefore
          ? EBadgeGapCause.backpressure
          : EBadgeGapCause.starvation;
      return EBadgeFrameOutcome(
        warning: '距上一帧 ${gap.inMilliseconds}ms，已超 §6.4 的 '
            '${frameGapLimit.inSeconds}s 帧超时，设备可能已清理会话'
            '（累计 $gapWarnings 次，${_causeText(cause)}）',
        diagnosis: cause,
      );
    }
    return EBadgeFrameOutcome.ok;
  }

  /// 归因写成人话跟在警告后面。**不只说现象,还给下一步动作** —— 光报「间隔 3200ms」
  /// 读日志的人还得自己去比对跳帧数才知道该动哪个旋钮。
  static String _causeText(EBadgeGapCause cause) => switch (cause) {
        EBadgeGapCause.backpressure => '期间有帧被跳过 ⇒ 推送侧背压，设备收得比我们发得慢：往下调质量或帧率',
        EBadgeGapCause.starvation => '期间无跳帧 ⇒ 帧源没产出画面，问题在相机侧而不是协议侧：调质量没用',
      };

  /// 带宽写成人话。[bps] 为 null 时给「—」,不给 0 —— 「还算不出来」和「真的是 0」
  /// 是两回事,后者说明设备那边正好该超时了。
  ///
  /// 放在这里当静态方法,是为了让界面、日志、会话总结共用同一套单位和小数位:三处
  /// 各自格式化的话,同一个数在屏上和日志里长得不一样,核对时会先怀疑是不是两个数。
  static String formatBps(int? bps) {
    if (bps == null) return '—';
    if (bps < 1024) return '$bps B/s';
    final kb = bps / 1024;
    if (kb < 1024) {
      // 小于 100 KB/s 时给一位小数:这条链路的典型区间就在几十 KB/s,取整会把
      // 「63 还是 68」这种拖滑条时唯一能看出的变化抹平。
      return kb < 100 ? '${kb.toStringAsFixed(1)} KB/s' : '${kb.round()} KB/s';
    }
    return '${(kb / 1024).toStringAsFixed(2)} MB/s';
  }

  /// 关连接。幂等,吞掉清理阶段的异常。
  Future<void> close() async {
    // 等在写的那一帧收尾再关:`close()` 与 `flush()` 争的是同一个 bound 标志,
    // 抢在前面同样会抛 `StreamSink is bound to a stream` —— 而这条路径正是用户
    // 点「停止推流」时走的,报在那里格外费解。
    final busy = _inFlight;
    if (busy != null) {
      try {
        await busy.done.timeout(_stallLimit);
      } catch (_) {
        // 卡死就不等了:清理路径不能被一条不读的连接拖住。destroy() 会强拆。
      }
    }
    final s = _socket;
    _socket = null;
    _inFlight = null;
    await _sub?.cancel();
    _sub = null;
    if (s == null) return;
    try {
      await s.close();
    } catch (_) {}
    s.destroy();
  }
}
