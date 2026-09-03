import 'dart:async';
import 'dart:typed_data';

import 'ebadge_link.dart';
import 'ebadge_protocol.dart';
import 'ebadge_wifi_transport.dart';

/// 传图会话所处的阶段。调试页据此显示进度,也决定失败时该清理什么。
///
/// 下面注释里的 cmd 号写的是 §5 传图那一组;OTA 走的是平移出来的 0xE0/0xE1/0xE4/
/// 0xE5/0xE6,阶段本身一模一样(见 [EBadgeXferKind])。
enum EBadgeXferStage {
  idle,

  /// 已发 0x10 Offer，等 0x11 DECISION（§5.5 限 30 s）。
  waitDecision,

  /// 已同意，等 0x13 AP_INFO。设备在 AP 就绪后会主动 Notify。
  waitApInfo,

  /// 正在连设备 SoftAP（§5.5 限 60 s）。
  joiningAp,

  /// TCP 已连，正在推 EBXF 头 + 正文（§5.5 限 120 s）。
  uploading,

  /// 正文已传完，等 BLE 0x15 DONE / 0x16 FAIL —— TCP 的 EBXR 不算业务完成依据。
  waitDone,

  done,
  failed,
}

/// 这条会话传的是什么东西 —— 说到底**只影响用哪一组 cmd 号**,以及日志措辞。
///
/// 时序(Offer → Decision → AP_INFO → 连热点 → TCP → Done/Fail)、参数区结构、
/// 数据面封装(§5.2 的 40 字节 EBXF 头 + 正文 → 8 字节 EBXR)、六个阶段、四个
/// 超时、本机与设备的字节对账、中途 FAIL 的回滚 —— 两者**完全一致**。OTA 那套
/// 0xE0/0xE1/0xE4/0xE5/0xE6 是照 §5 的 0x10/0x11/0x14/0x15/0x16 整段平移出来的
/// 私有号段(见 [EBadgeCmd.h2dOtaOffer]),所以差别只剩:
///
/// 1. 五个 cmd 号(下面五个字段),AP_INFO 那两条 0x12/0x13 **共用**;
/// 2. Offer 的构造:壁纸的 type/replace_id 由调用方给,OTA 恒为 bin、没有
///    replace_id(见 [EBadgeRequest.otaOffer]);
/// 3. 放行条件:壁纸只认 0xE1 的对应物 0x11,OTA 额外容忍「设备跳过 0xE1 直接报
///    0x13 AP_INFO」(见 `_awaitGo`);
/// 4. DONE 的解析:0xE5 的 file_id 是可选的(见 [EBadgeOtaDone])。
///
/// 因此这里用一个 kind 参数而不是复制一个 OTA 会话类:必须保持同步的部分恰好是
/// 上面那一长串共用的,复制出去只会让它们各自漂移 —— 而把号码做成字段,新增一种
/// 传输就只是再加一个枚举值。
enum EBadgeXferKind {
  wallpaper(
    '传图',
    decisionCmd: EBadgeCmd.d2hTransferDecision,
    progressCmd: EBadgeCmd.d2hTransferProgress,
    doneCmd: EBadgeCmd.d2hTransferDone,
    failCmd: EBadgeCmd.d2hTransferFail,
  ),
  ota(
    'OTA',
    decisionCmd: EBadgeCmd.d2hOtaDecision,
    progressCmd: EBadgeCmd.d2hOtaProgress,
    doneCmd: EBadgeCmd.d2hOtaDone,
    failCmd: EBadgeCmd.d2hOtaFail,
  );

  const EBadgeXferKind(
    this.label, {
    required this.decisionCmd,
    required this.progressCmd,
    required this.doneCmd,
    required this.failCmd,
  });

  /// 日志与失败文本里的自称。调试台上两条链路的日志是混在一起的,不区分会看不出
  /// 「传图中止」到底是哪一次。
  final String label;

  /// 设备的同意/拒绝。0x11 / 0xE1。
  final int decisionCmd;

  /// 设备上报的已收字节数。0x14 / 0xE4。
  final int progressCmd;

  /// 设备报成功。0x15 / 0xE5。
  final int doneCmd;

  /// 设备报失败,整个会话期间都盯着。0x16 / 0xE6。
  final int failCmd;
}

/// 协议 §5.4 的完整传图时序编排：Offer → Decision → AP_INFO → 连热点 → TCP 上传
/// → EBXR → BLE DONE。
///
/// **为什么要单独一个类**：这条链路横跨两条物理通道（BLE 控制面 + Wi-Fi 数据面）、
/// 六个阶段、四个超时，且任一步失败都要回滚（解绑网络、关 socket）。写在页面里会
/// 让 UI 代码里塞满时序状态机；写在 [EBadgeLink] 里又会让传输层依赖 Wi-Fi。放在
/// 这里，两边都只依赖它，它依赖两边。
///
/// 会话是**一次性**的：一个实例跑一次 [run]。设备侧同样只允许单会话（§5.7 非 Idle
/// 收到新 Offer 直接回 BUSY），复用实例只会让状态更难对齐。
class EBadgeTransferSession {
  EBadgeTransferSession({
    required this.link,
    required this.wifi,
    this.onStage,
    this.kind = EBadgeXferKind.wallpaper,
  });

  final EBadgeLink link;
  final EBadgeWifiTransport wifi;

  /// 传的是壁纸还是固件包。默认壁纸 —— 已有调用方和测试不必改。
  final EBadgeXferKind kind;

  /// 阶段变化回调。第二个参数是给人看的补充说明（进度、失败原因等）。
  final void Function(EBadgeXferStage stage, String? detail)? onStage;

  EBadgeXferStage _stage = EBadgeXferStage.idle;
  EBadgeXferStage get stage => _stage;

  /// 本机通过 TCP 写出的正文字节数 / 正文总长。失败时要靠它答「到底传了多少」。
  int _sent = 0;
  int _total = 0;

  /// 设备通过 BLE 0x14 PROGRESS 说它自己收到的字节数。null = 一次都没报过。
  ///
  /// 单独记设备侧的数,是因为**两个数字的差**才是这类故障最有诊断力的事实:
  /// 本机写完 16K 而设备只认 4K,说明后面的数据丢在 Wi-Fi 或设备的接收缓冲上;
  /// 两边都是 16K 却还失败,那就是 CRC/入库的问题,和链路无关。只看一边永远分不出。
  int? _deviceRecv;

  /// 上传阶段的进度摘要,失败时原样带进失败文本 —— [_fail] 不能把它覆盖掉。
  String get progressText {
    if (_total <= 0) return '未开始传输正文';
    final pct = (_sent / _total * 100).toStringAsFixed(1);
    final mine = '本机已发 $_sent/$_total B（$pct%）';
    final dev = _deviceRecv;
    if (dev == null) return '$mine；设备未上报 0x14 进度';
    if (dev == _sent) return '$mine；设备确认收到 $dev B';
    return '$mine；设备只确认收到 $dev B（差 ${_sent - dev} B）';
  }

  void _to(EBadgeXferStage s, [String? detail]) {
    _stage = s;
    onStage?.call(s, detail);
  }

  /// 跑完一次传图。返回 null 表示成功，否则是失败原因（已同时写进 link 日志）。
  ///
  /// [name] / [type] / [body] 描述要传的文件。CRC32 在这里算一次，同时用于 Offer
  /// 的 TLV_XFER_CRC32 和 EBXF 头 —— §5.2 校验规则第 3 条要求两处必须相同，算两次
  /// 就给了它们不一致的机会。
  ///
  /// [type] 和 [replaceId] 在 OTA 上**都被忽略**：升级包恒为 bin，也没有「替换第几
  /// 张壁纸」这回事（见 [EBadgeRequest.otaOffer]）。
  Future<String?> run({
    required String name,
    required int type,
    required Uint8List body,
    int? replaceId,
  }) async {
    if (!link.ready) {
      final msg = 'BLE 通道未就绪，无法发起${kind.label}';
      link.logError(msg);
      _to(EBadgeXferStage.failed, msg);
      return msg;
    }

    // 设备失败会走 0x16 / 0xE6 FAIL 而不是在某个 await 上超时,所以整个会话期间都要
    // 盯着它。放在最外层订阅,任何阶段收到都能立刻中断。
    //
    // 两条 cmd 的参数区逐号一致(见 [EBadgeTlvOtaFail]),所以解析器共用一个;号码
    // 从 kind 上取,别写死 —— 写死的那一天,OTA 失败会一路等到超时才报,原因还丢了。
    final failed = Completer<EBadgeTransferFail>();
    final failSub = link.frames
        .where((f) => f.cmd == kind.failCmd)
        .map(EBadgeTransferFail.parse)
        .where((f) => f != null)
        .cast<EBadgeTransferFail>()
        .listen((f) {
      if (!failed.isCompleted) failed.complete(f);
    });

    // 0x14 / 0xE4 PROGRESS 同样整个会话期间都订阅:设备可能在 TCP 写完之后、入库
    // 阶段才补报,也可能在写到一半时就停止上报。只在 uploading 阶段订阅会漏掉这两
    // 种,而它们恰恰是最需要这个数字的场景。
    final progSub = link.frames
        .where((f) => f.cmd == kind.progressCmd)
        .map(EBadgeProgress.parse)
        .where((p) => p != null)
        .cast<EBadgeProgress>()
        .listen((p) {
      _deviceRecv = p.recv;
      // 设备报的 total 更权威(它按 Offer 里的 size 算),但只在本机还没开始记账时
      // 才采信 —— 上传中途拿它覆盖会让百分比来回跳。
      if (_total <= 0 && p.total > 0) _total = p.total;
      if (_stage == EBadgeXferStage.uploading) {
        _to(EBadgeXferStage.uploading, progressText);
      }
    });

    try {
      final crc = eBadgeCrc32(body);
      return await _run(
        name: name,
        // OTA 的类型不由调用方定:0xE0 的 TLV_TYPE 恒为 bin,而 §5.2 要求 EBXF 头里
        // 的 type 和 Offer 里的**必须是同一个值**。让调用方传就多出一条「帧里写
        // jpeg、头里写 bin」的失败路径,而它在链路上的表现只是设备默默丢包。
        type: kind == EBadgeXferKind.ota ? EBadgeFileType.bin : type,
        body: body,
        crc: crc,
        replaceId: replaceId,
        deviceFailed: failed.future,
      );
    } finally {
      await failSub.cancel();
      await progSub.cancel();
      // 无论成功失败都要解绑进程网络。漏掉这一步,App 之后所有网络请求都会往一张
      // 已经消失的网上发 —— 表现为「突然完全没网」,且和本功能看不出关联。
      await wifi.leave();
    }
  }

  Future<String?> _run({
    required String name,
    required int type,
    required Uint8List body,
    required int crc,
    required int? replaceId,
    required Future<EBadgeTransferFail> deviceFailed,
  }) async {
    // ── 1. Offer ────────────────────────────────────────────────────────
    // V1.3 §4.7:设备不再弹窗等人点,而是自查存储/内存/忙后自动回 0x11。所以这
    // 一步的等待通常是毫秒级,只有设备卡住才会走到 §5.5 的 30 s 上限。
    _to(
      EBadgeXferStage.waitDecision,
      kind == EBadgeXferKind.ota ? '等待设备自检并回复（0xE1，或直接 0x13）' : '等待设备自检并回复',
    );
    // 两条 Offer 的字段是同一套(name/type/size/crc32),只有构造入口不同 —— 0xE0 的
    // type 是写死的、没有 replace_id,所以签名对不上,不能合成一次调用。
    //
    // size 和 crc32 两边都取自这里的同一个 body：Offer 报的数和 EBXF 头写的数必须是
    // 一个数（§5.2 校验规则第 3 条），从外部接体积等于给它们一次不一致的机会。
    final offer = switch (kind) {
      EBadgeXferKind.wallpaper => EBadgeRequest.transferOffer(
          name: name,
          type: type,
          size: body.length,
          crc32: crc,
          replaceId: replaceId,
        ),
      EBadgeXferKind.ota => EBadgeRequest.otaOffer(
          name: name,
          size: body.length,
          crc32: crc,
        ),
    };
    // 这一行是出问题时和设备侧对账的唯一依据:四个字段既进了帧,也进了 40B EBXF 头。
    final label = '$name ${EBadgeFileType.name(type)} ${body.length}B '
        'crc32=0x${crc.toRadixString(16).padLeft(8, '0')}';
    if (!await link.send(offer, label)) {
      return _fail('Offer 发送失败');
    }

    // ── 2. Decision（§5.5 限 30 s）────────────────────────────────────
    // 三态返回:失败原因(String)、0x11/0xE1 DECISION、或 OTA 时跳着来的 0x13
    // AP_INFO（见 [_awaitGo]）。
    final gate = await _awaitGo(deviceFailed: deviceFailed);
    if (gate is String) return _fail(gate);

    // OTA 跳过 0xE1 直接回 AP_INFO 时当同意。那一帧**必须在这里就留下**:设备只主动
    // 发一次,放过去之后第 3 步再订阅是订不到的。
    final EBadgeApInfo? earlyAp = gate is EBadgeApInfo ? gate : null;
    if (gate is EBadgeTransferDecision && !gate.accepted) {
      final why = gate.reason == null
          ? EBadgeDecision.name(gate.decision)
          : '${EBadgeDecision.name(gate.decision)} / '
              '${EBadgeXferError.name(gate.reason!)}';
      return _fail('设备未同意${kind.label}：$why');
    }

    // ── 3. AP_INFO ─────────────────────────────────────────────────────
    // §4.9:设备在同意且 AP 就绪后应主动 Notify 0x13。它没主动发时我们补一发
    // 0x12 去问 —— 协议允许,且比直接判失败更宽容。
    Object apResult;
    if (earlyAp != null) {
      // 已经拿到了,一步都不用等。仍然把阶段过一遍:调试台上那条阶段线是按顺序读的,
      // 跳号会让人以为漏了一步。
      _to(EBadgeXferStage.waitApInfo, '热点信息已替代同意一并收到');
      apResult = earlyAp;
    } else {
      _to(EBadgeXferStage.waitApInfo, '等待设备上报热点信息');
      apResult = await _await<EBadgeApInfo>(
        cmd: EBadgeCmd.d2hApInfo,
        parse: EBadgeApInfo.parse,
        timeout: const Duration(seconds: 10),
        deviceFailed: deviceFailed,
        what: 'AP 信息',
      );
      if (apResult is String) {
        link.logInfo('未收到主动上报的 AP_INFO，补发 0x12 查询');
        await link.send(EBadgeRequest.getApInfo(), '补查 AP 信息');
        apResult = await _await<EBadgeApInfo>(
          cmd: EBadgeCmd.d2hApInfo,
          parse: EBadgeApInfo.parse,
          timeout: const Duration(seconds: 10),
          deviceFailed: deviceFailed,
          what: 'AP 信息',
        );
        if (apResult is String) return _fail(apResult);
      }
    }
    final ap = apResult as EBadgeApInfo;
    if (ap.proto != 0x01) {
      // §4.9:TLV_AP_PROTO 只有 0x01 合法。继续传下去也没意义。
      return _fail('设备上报的数据面协议 proto=0x'
          '${ap.proto.toRadixString(16).padLeft(2, '0')}，只支持 0x01 裸 TCP');
    }

    // ── 4. 连热点（§5.5 限 60 s）──────────────────────────────────────
    _to(EBadgeXferStage.joiningAp, '连接 ${ap.ssid}');
    final joinErr = await wifi.join(
      ssid: ap.ssid,
      password: ap.password,
      timeout: const Duration(seconds: 60),
    );
    if (joinErr != null) return _fail('连接设备热点失败：$joinErr');
    link.logInfo('已连上设备热点 ${ap.ssid}',
        detail: '${ap.ipv4}:${ap.port} '
            '${ap.isOpen ? "Open" : "WPA2-PSK"} ch=${ap.channel}');

    // ── 5. TCP 上传（§5.5 限 120 s）────────────────────────────────────
    _total = body.length;
    _to(EBadgeXferStage.uploading, progressText);
    final up = await wifi.upload(
      ip: ap.ipv4,
      port: ap.port,
      name: name,
      fileType: type,
      body: body,
      crc32: crc,
      // 数据面两者一模一样:40 字节 EBXF 头 + 正文 → 8 字节 EBXR。头里的 name/type/
      // size/crc32 和上面那条 Offer 是同一份值(§5.2 校验规则第 3 条)。
      onProgress: (sent, total) {
        _sent = sent;
        _total = total;
        _to(EBadgeXferStage.uploading, progressText);
      },
    );
    link.logInfo('TCP 上传结束', detail: up.describe());
    // up.describe() 里已经带了 40B 头是否发出、正文写了多少;这里再拼上设备侧的
    // 0x14 数字,两边一对照才能定位是「没发出去」还是「发出去了设备没收到」。
    if (!up.succeed) return _fail('数据面上传失败：${up.describe()}');

    // ── 6. 等 BLE DONE ─────────────────────────────────────────────────
    // §5.3 明确:TCP status=成功**不替代** BLE 0x15 DONE,业务完成以 BLE 为准。OTA
    // 同理 —— 0xE5/0xE6 才是设备刷完之后给的结论,EBXR 只说明「字节收全了」。
    _to(
      EBadgeXferStage.waitDone,
      kind == EBadgeXferKind.ota ? '等待设备校验并升级' : '等待设备入库',
    );
    // 解析器按 kind 分:0xE5 的 file_id 可选,拿 0x15 那个严格解析器去解,固件不带
    // file_id 就会解出 null —— 一次**已经刷完的升级**会被等到 20 s 超时报成失败
    // (见 [EBadgeOtaDone])。两个返回类型不同,所以这里等 Object,String 仍然只可能
    // 是失败原因(两个 parse 都不会返回 String)。
    final doneResult = await _await<Object>(
      cmd: kind.doneCmd,
      parse: kind == EBadgeXferKind.ota
          ? EBadgeOtaDone.parse
          : EBadgeTransferDone.parse,
      timeout: const Duration(seconds: 20),
      deviceFailed: deviceFailed,
      what: kind == EBadgeXferKind.ota ? '升级结果' : '入库结果',
    );
    if (doneResult is String) return _fail(doneResult);
    _to(
      EBadgeXferStage.done,
      switch (doneResult) {
        EBadgeOtaDone d => d.summary,
        EBadgeTransferDone d => 'file_id=${d.fileId} ${d.size}B ${d.name}',
        _ => '$doneResult',
      },
    );
    return null;
  }

  /// 记日志 + 切到 failed,返回失败原因。
  ///
  /// **一旦开始传正文就把进度拼进去**:原来这里直接把 [_to] 的 detail 覆盖成一句
  /// 错误文本,而上一条 detail 恰好是「已发多少字节」—— 最有用的线索正好在最需要
  /// 它的时刻被擦掉,页面上只剩「未应答 EBXR」。
  String _fail(String msg) {
    final full = _total > 0 ? '$msg\n$progressText' : msg;
    link.logError('${kind.label}中止', detail: full);
    _to(EBadgeXferStage.failed, full);
    return full;
  }

  /// 等「可以往下走」的信号。返回 [EBadgeTransferDecision]、[EBadgeApInfo] 或
  /// [String]（失败原因）三态。
  ///
  /// **传图只认 0x11**：§5.4 规定设备同意后才起热点报 0x13，先来 0x13 属于固件时序
  /// 出错，在这里替它兜着只会把问题推到更靠后、更难归因的阶段。
  ///
  /// **OTA 认 0xE1，也容忍设备跳过它直接报 0x13**：0xE1 是这套私有号段里正式的一步，
  /// 正常路径就走它；但固件那侧先前的实现是「自检过了就把热点起起来、报 AP_INFO」，
  /// 压根不发确认。而 0x13 的信息量本来就比 decision=1 更足 —— 热点已经就绪，能连了。
  /// 守着一个这版固件不会发的帧等满 35 s 再判失败，是拿一次本来能成的升级去换时序上
  /// 的洁癖。这条容忍**只在 0xE1 一直没来时才生效**，不影响正常路径。
  ///
  /// 两者都仍然盯着 0x16 / 0xE6 FAIL：设备拒绝时走的是那条路，和这里认哪一帧无关。
  Future<Object> _awaitGo({
    required Future<EBadgeTransferFail> deviceFailed,
  }) async {
    final apMeansYes = kind == EBadgeXferKind.ota;
    const timeout = Duration(seconds: 35); // 比设备的 30s 略宽,让它先超时
    final got = Completer<Object>();
    final sub = link.frames.listen((f) {
      if (got.isCompleted) return;
      if (f.cmd == kind.decisionCmd) {
        // 0x11 和 0xE1 的参数区逐号一致(见 [EBadgeTlvOtaDecision]),共用解析器。
        final v = EBadgeTransferDecision.parse(f);
        if (v != null) got.complete(v);
      } else if (apMeansYes && f.cmd == EBadgeCmd.d2hApInfo) {
        final v = EBadgeApInfo.parse(f);
        if (v != null) {
          link.logInfo('设备跳过 0xE1 直接回了 AP_INFO，按同意处理',
              detail: '热点已就绪即视为自检通过；若固件会发 0xE1，正常路径不会走到这里');
          got.complete(v);
        }
      }
    });
    try {
      return await Future.any<Object>([
        got.future,
        deviceFailed.then<Object>((f) => '设备报告${kind.label}失败：'
            '${EBadgeXferError.name(f.reason)}'
            '${f.detail == null ? "" : " (${f.detail})"}'),
      ]).timeout(
        timeout,
        onTimeout: () => apMeansYes
            ? '等待${kind.label}确认超时（${timeout.inSeconds}s）：'
                '既没收到 0xE1，也没收到 0x13'
            : '等待${kind.label}确认超时（${timeout.inSeconds}s）',
      );
    } finally {
      await sub.cancel();
    }
  }

  /// 等一个 D→H 帧。三方竞速：目标帧到了、设备回了 0x16 / 0xE6 FAIL、或超时。
  ///
  /// 返回目标类型表示成功，返回 [String] 表示失败原因 —— 用返回值而不是抛异常，
  /// 是因为这三种「结果」在调用处都要走同一条汇报路径，异常反而要各写一遍 catch。
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
      final r = await Future.any<Object>([
        got.future.then<Object>((v) => v as Object),
        deviceFailed.then<Object>((f) => '设备报告${kind.label}失败：'
            '${EBadgeXferError.name(f.reason)}'
            '${f.detail == null ? "" : " (${f.detail})"}'),
      ]).timeout(
        timeout,
        onTimeout: () => '等待$what超时（${timeout.inSeconds}s）',
      );
      return r;
    } finally {
      await sub.cancel();
    }
  }
}
