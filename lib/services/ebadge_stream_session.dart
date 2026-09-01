import 'dart:async';

import 'package:flutter/services.dart';

import 'ebadge_link.dart';
import 'ebadge_protocol.dart';
import 'ebadge_stream_transport.dart';
import 'ebadge_wifi_transport.dart';

/// 同屏预览会话所处的阶段(§6.4)。
///
/// 比 [EBadgeXferStage] 少两个:没有「等用户确认」(V1.3 设备自动回),也没有
/// 「等入库」(流不入库)。多一个 [streaming] —— 它不是一个会自己结束的阶段,要
/// 靠调用方 [EBadgeStreamSession.stop] 才退出。
enum EBadgeStreamStage {
  idle,

  /// 已发 0x08 OFFER，等 0x09 DECISION。
  waitDecision,

  /// 已同意，等 0x13 AP_INFO。
  waitApInfo,

  /// 正在连设备 SoftAP。
  joiningAp,

  /// TCP 已连，正在按帧率推流 —— 直到 stop 或出错。
  streaming,

  stopped,
  failed,
}

/// 协议 §6 的同屏预览时序编排:0x08 OFFER → 0x09 DECISION → 0x13 AP_INFO →
/// 连热点 → TCP → 连续推帧 → stop。
///
/// **与 [EBadgeTransferSession] 分开写而不加个开关**:两条链路的阶段数、超时值、
/// 终止条件都不同 —— §5 传完就结束、以 BLE 0x15 DONE 为准;§6 没有「传完」这个
/// 概念,连接一直开着,EBXR 还是可选的。把两者塞进一个类,每个阶段都要挂 if,反而
/// 谁都看不清。
///
/// **与拍照投屏(`wifi_transport.dart` / `TcpVideoClient`)完全无关**:那条路径有
/// 自己的帧格式和自己的 BLE 握手。本类仅供协议调试页验证 §6 的报文与时序,不接
/// 摄像头 —— 帧内容由 [start] 的 `nextFrame` 回调提供。
class EBadgeStreamSession {
  EBadgeStreamSession({
    required this.link,
    required this.wifi,
    EBadgeStreamTransport? tcp,
    this.onStage,
  }) : tcp = tcp ?? EBadgeStreamTransport();

  final EBadgeLink link;

  /// STA 关联复用 §5 那套 —— 连热点这一步两条链路完全相同。
  final EBadgeWifiTransport wifi;

  final EBadgeStreamTransport tcp;

  final void Function(EBadgeStreamStage stage, String? detail)? onStage;

  EBadgeStreamStage _stage = EBadgeStreamStage.idle;
  EBadgeStreamStage get stage => _stage;

  /// 设备协商后的实际帧率;握手完成前为 null。
  int? _fps;
  int? get fps => _fps;

  Timer? _ticker;
  StreamSubscription<EBadgeFrame>? _failSub;
  bool _stopping = false;

  /// `nextFrame` 返回 null 的次数 —— **帧源饿死**的直接读数。
  ///
  /// 这个数只有会话层能统计:传输层看不到「本 tick 压根没取到画面」这件事(那种
  /// tick 根本不会调 sendFrame)。而它恰恰是排查帧间隔超时的第一个分岔 —— 它在涨
  /// 就说明问题在相机侧,协议侧再怎么查都是白费。
  int _emptyTicks = 0;
  int get emptyTicks => _emptyTicks;

  /// 因为上一帧还在写而整个跳过的 tick 数(连取帧都没取)。
  ///
  /// 与 [EBadgeStreamTransport.framesSkipped] 是两个数,不能合:那个是「取了帧但
  /// 写不出去」,这个是「知道写不出去所以没取」。两者相加才是背压吃掉的总 tick 数。
  int _busyTicks = 0;
  int get busyTicks => _busyTicks;

  /// 会话期间累计的警告数(帧间隔超时之类)。会话不会因此中止。
  int _warnings = 0;
  int get warnings => _warnings;

  /// 最后一条警告的原文,以及它的归因。
  ///
  /// 留在这里(而不是只发进日志)是因为**日志会滚过去**:1 fps 下几十秒就把它顶出
  /// 可见区,而拖滑条的人正需要一直盯着「上次警告是哪一侧的问题」来决定动哪个旋钮。
  String? _lastWarning;
  String? get lastWarning => _lastWarning;

  EBadgeGapCause? _lastCause;
  EBadgeGapCause? get lastCause => _lastCause;

  void _to(EBadgeStreamStage s, [String? detail]) {
    _stage = s;
    onStage?.call(s, detail);
  }

  /// 跑握手并开始推流。返回 null 表示已进入 [EBadgeStreamStage.streaming],
  /// 否则是失败原因。
  ///
  /// [nextFrame] 每个 tick 调一次,返回本帧的 JPEG 字节;返回 null 表示这一 tick
  /// 没有新画面,跳过(不推空帧 —— §6.2 的 size 是 payload 长度,0 没有意义)。
  ///
  /// 注意:推流启动后本方法就返回了,后续错误通过 [onStage] 报到 failed 阶段。
  /// 这样设计是因为「推流中」不是一个能 await 出结果的状态,它的终点由调用方决定。
  Future<String?> start({
    required String name,
    required int requestedFps,
    required Uint8List? Function() nextFrame,
  }) async {
    if (!link.ready) return _fail('BLE 通道未就绪，无法发起同屏预览');
    if (_stage != EBadgeStreamStage.idle) return _fail('会话已启动，不能重入');

    // 设备任何阶段失败都走 0x16 FAIL(§6.4),整个会话期间都要盯着。
    final failed = Completer<EBadgeTransferFail>();
    _failSub = link.frames
        .where((f) => f.cmd == EBadgeCmd.d2hTransferFail)
        .listen((f) {
      final p = EBadgeTransferFail.parse(f);
      if (p == null) return;
      if (!failed.isCompleted) failed.complete(p);
      // 推流已经开始后,0x16 不会有人在 await 它,得主动把会话拆掉。
      if (_stage == EBadgeStreamStage.streaming) {
        _abort('设备报告失败：${EBadgeXferError.name(p.reason)}'
            '${p.detail == null ? "" : " (${p.detail})"}');
      }
    });

    final err = await _handshake(
      name: name,
      requestedFps: requestedFps,
      deviceFailed: failed.future,
    );
    if (err != null) {
      await _cleanup();
      return _fail(err);
    }

    // ── 推流 ────────────────────────────────────────────────────────────
    final period = Duration(microseconds: (1000000 / _fps!).round());
    _to(EBadgeStreamStage.streaming, 'fps=$_fps，已推 0 帧');
    _ticker = Timer.periodic(period, (_) async {
      if (_stage != EBadgeStreamStage.streaming) return;
      // 上一帧还在写就别取帧了:取了也只会被 sendFrame 丢掉,而内置源取一次就把
      // 游标推进一格,白跳帧号会让「设备屏上的序号该不该连续」变得没法判断。
      if (tcp.sending) {
        _busyTicks++;
        return;
      }
      final frame = nextFrame();
      if (frame == null || frame.isEmpty) {
        // 帧源这一 tick 没画面。记下来 —— 这是「帧间隔为什么会超 3 s」的头号成因,
        // 而它在传输层完全看不见(这种 tick 根本走不到 sendFrame)。
        _emptyTicks++;
        return;
      }
      final r = await tcp.sendFrame(frame);

      // 只有实证才拆会话:设备关了连接、socket 写失败。
      if (r.error != null) {
        _abort(r.error!);
        return;
      }

      // 警告只记日志,会话继续 —— 「间隔超了 3 s」是 App 自己推算的,设备既没回
      // 0x16 也没关连接。按推测拆掉一条其实还活着的会话,会把真正要观察的现象
      // (超时之后设备到底怎么反应)抹掉。
      if (r.warning != null) {
        _warnings++;
        _lastWarning = r.warning;
        _lastCause = r.diagnosis;
        link.logInfo('同屏预览警告：${r.warning}', detail: _diagnosticSnapshot());
      }

      _to(EBadgeStreamStage.streaming, _progressText());
    });
    return null;
  }

  /// 进度行。除了「推了多少」,还要能看出**瓶颈在哪一侧** —— 这几个数放在一起才有
  /// 诊断价值:单看「已推 N 帧」不动,相机卡死和设备不读长得一模一样。
  String _progressText() {
    final b = StringBuffer('fps=$_fps');
    // 实测帧间隔 vs 协商帧率:两者的差距就是这条链路真实能力的读数。
    final gap = tcp.lastGap;
    if (gap != null) b.write('（实测 ${gap.inMilliseconds}ms/帧）');
    b.write('，已推 ${tcp.framesSent} 帧 / ${tcp.bytesSent}B');
    // 实时带宽紧跟帧数:两者一起才能分开「帧少但每帧大」和「帧多但每帧小」——
    // 同样的 KB/s 下这两种情况对设备解码的压力完全不同。
    b.write('，${EBadgeStreamTransport.formatBps(tcp.bandwidthBps)}');
    if (tcp.framesSkipped > 0) b.write('，跳 ${tcp.framesSkipped} 帧');
    if (_emptyTicks > 0) b.write('，源空 $_emptyTicks 次');
    if (_warnings > 0) b.write('，警告 $_warnings 次');
    if (tcp.lastAck != null) {
      b.write('，EBXR=${tcp.lastAck!.succeed ? "成功" : "失败"}');
    }
    return b.toString();
  }

  /// 警告随行的现场快照。
  ///
  /// 警告本身只说「间隔超了」,而处置取决于哪一侧的问题。把四个计数一起落进日志 ——
  /// 日志会滚过去,事后回看时进度行早就被后续的覆盖掉了,只有这一行留着当时的现场。
  String _diagnosticSnapshot() => '已推 ${tcp.framesSent} 帧 / '
      '跳 ${tcp.framesSkipped} 帧 / 源空 $_emptyTicks 次 / '
      '忙跳 $_busyTicks tick / 间隔超时累计 ${tcp.gapWarnings} 次 / '
      // 带宽是警告现场里最能定性的一项:警告时它还在正常量级 ⇒ 帧在发、是设备不认;
      // 掉到 0 ⇒ 确实断流了。事后回看时这个数已经变了,只有这一行留着当时的值。
      '带宽 ${EBadgeStreamTransport.formatBps(tcp.bandwidthBps)}';

  /// 主动停止推流并清理。§6.4 的正常收尾:App 退出预览 → close TCP。
  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    final sent = tcp.framesSent;
    // 快照要在 _cleanup 之前取:close() 之后这些计数还在,但把总结留到清理后再拼
    // 容易在将来某次「顺手把计数也归零」的改动里悄悄变空。
    final snapshot = _diagnosticSnapshot();
    // 带宽总结也必须在清理前取,而且取的是**均值和峰值**不是瞬时值:瞬时值按「现在
    // 往前推 3 s」算,停下来的这一刻它正在往 0 掉,拿它当总结等于每次都报 0。
    final avg = EBadgeStreamTransport.formatBps(tcp.averageBandwidthBps);
    final peak = EBadgeStreamTransport.formatBps(tcp.peakBandwidthBps);
    final wire = tcp.wireBytesSent;
    await _cleanup();
    // 停下来时把整场的账一起报出来 —— 有警告的那次会话最需要事后回看,而进度行
    // 只留最后一瞬的状态。
    _to(
      EBadgeStreamStage.stopped,
      '已停止，共推 $sent 帧 / $wire B（均 $avg，峰 $peak）'
      '${_warnings == 0 ? "" : "（期间 $_warnings 次警告：$snapshot）"}',
    );
    _stopping = false;
  }

  Future<String?> _handshake({
    required String name,
    required int requestedFps,
    required Future<EBadgeTransferFail> deviceFailed,
  }) async {
    // ── 1. 0x08 OFFER ──────────────────────────────────────────────────
    _to(EBadgeStreamStage.waitDecision, '等待设备自检并回复');
    final offer = EBadgeRequest.jpgStreamOffer(
      name: name,
      fps: requestedFps,
    );
    if (!await link.send(offer, '$name JPEG_STREAM fps=$requestedFps')) {
      return '0x08 OFFER 发送失败';
    }

    // ── 2. 0x09 DECISION ───────────────────────────────────────────────
    // §6 没给这一步的超时值。设备是自查后自动回(不等人点),10 s 已经很宽 ——
    // 沿用 §5.5 那个「等用户确认 30 s」在这里没有依据,只会让失败反馈变慢。
    final dr = await _await<EBadgeStreamDecision>(
      cmd: EBadgeCmd.d2hJpgStreamDecision,
      parse: EBadgeStreamDecision.parse,
      timeout: const Duration(seconds: 10),
      deviceFailed: deviceFailed,
      what: '同屏确认',
    );
    if (dr is String) return dr;
    final d = dr as EBadgeStreamDecision;
    if (!d.accepted && !d.negotiated) {
      final why = d.reason == null
          ? EBadgeDecision.nameForStream(d.decision)
          : '${EBadgeDecision.nameForStream(d.decision)} / '
              '${EBadgeXferError.name(d.reason!)}';
      return '设备未同意同屏预览：$why';
    }
    _fps = d.effectiveFps(requestedFps);
    if (_fps! < 1) return '设备协商出的帧率 $_fps 不可用';
    if (_fps != requestedFps) {
      link.logInfo('设备协商帧率：$requestedFps → $_fps');
    }

    // ── 3. 0x13 AP_INFO ────────────────────────────────────────────────
    // 与 §5 同一套:设备应在 AP 就绪后主动 Notify,没来就补发 0x12。
    _to(EBadgeStreamStage.waitApInfo, '等待设备上报热点信息');
    var apr = await _await<EBadgeApInfo>(
      cmd: EBadgeCmd.d2hApInfo,
      parse: EBadgeApInfo.parse,
      timeout: const Duration(seconds: 10),
      deviceFailed: deviceFailed,
      what: 'AP 信息',
    );
    if (apr is String) {
      link.logInfo('未收到主动上报的 AP_INFO，补发 0x12 查询');
      await link.send(EBadgeRequest.getApInfo(), '补查 AP 信息');
      apr = await _await<EBadgeApInfo>(
        cmd: EBadgeCmd.d2hApInfo,
        parse: EBadgeApInfo.parse,
        timeout: const Duration(seconds: 10),
        deviceFailed: deviceFailed,
        what: 'AP 信息',
      );
      if (apr is String) return apr;
    }
    final ap = apr as EBadgeApInfo;
    if (ap.proto != 0x01) {
      return '设备上报的数据面协议 proto=0x'
          '${ap.proto.toRadixString(16).padLeft(2, '0')}，只支持 0x01 裸 TCP';
    }

    // ── 4. 连热点 ──────────────────────────────────────────────────────
    _to(EBadgeStreamStage.joiningAp, '连接 ${ap.ssid}');
    final joinErr = await wifi.join(
      ssid: ap.ssid,
      password: ap.password,
      timeout: const Duration(seconds: 60),
    );
    if (joinErr != null) return '连接设备热点失败：$joinErr';
    link.logInfo('已连上设备热点 ${ap.ssid}',
        detail: '${ap.ipv4}:${ap.port} '
            '${ap.isOpen ? "Open" : "WPA2-PSK"} ch=${ap.channel}');

    // ── 5. TCP(§6.5 限 10 s)──────────────────────────────────────────
    final tcpErr = await tcp.connect(
      ip: ap.ipv4,
      port: ap.port,
      timeout: const Duration(seconds: 10),
    );
    if (tcpErr != null) return tcpErr;
    return null;
  }

  /// 推流途中出错:立刻拆会话并报到 failed。与 [stop] 的区别只是终态不同 ——
  /// 清理动作必须一模一样,否则会漏解绑网络。
  void _abort(String reason) {
    if (_stage == EBadgeStreamStage.failed) return;
    _cleanup().then((_) => _fail(reason));
  }

  Future<void> _cleanup() async {
    _ticker?.cancel();
    _ticker = null;
    await _failSub?.cancel();
    _failSub = null;
    await tcp.close();
    // 不解绑进程网络,App 之后所有请求都会往一张已消失的网上发 —— 表现是「突然
    // 完全没网」,且和本功能看不出关联。
    await wifi.leave();
  }

  String _fail(String msg) {
    link.logError('同屏预览中止', detail: msg);
    _to(EBadgeStreamStage.failed, msg);
    return msg;
  }

  /// 等一个 D→H 帧。三方竞速:目标帧、设备 0x16 FAIL、超时。与
  /// [EBadgeTransferSession._await] 同构 —— 抽公共基类要把 stage 枚举也参数化,
  /// 反而更绕,两处各 25 行是更好的取舍。
  Future<Object> _await<T>({
    required int cmd,
    required T? Function(EBadgeFrame) parse,
    required Duration timeout,
    required Future<EBadgeTransferFail> deviceFailed,
    required String what,
  }) async {
    final got = Completer<T>();
    final sub = link.frames.where((f) => f.cmd == cmd).listen((f) {
      final v = parse(f);
      if (v != null && !got.isCompleted) got.complete(v);
    });
    try {
      return await Future.any<Object>([
        got.future.then<Object>((v) => v as Object),
        deviceFailed.then<Object>((f) => '设备报告失败：'
            '${EBadgeXferError.name(f.reason)}'
            '${f.detail == null ? "" : " (${f.detail})"}'),
      ]).timeout(
        timeout,
        onTimeout: () => '等待$what超时（${timeout.inSeconds}s）',
      );
    } finally {
      await sub.cancel();
    }
  }
}
