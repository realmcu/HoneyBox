import 'dart:async';
import 'dart:typed_data';

import 'ebadge_link.dart';
import 'ebadge_protocol.dart';
import 'ebadge_wifi_transport.dart';

/// 传图会话所处的阶段。调试页据此显示进度,也决定失败时该清理什么。
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
  });

  final EBadgeLink link;
  final EBadgeWifiTransport wifi;

  /// 阶段变化回调。第二个参数是给人看的补充说明（进度、失败原因等）。
  final void Function(EBadgeXferStage stage, String? detail)? onStage;

  EBadgeXferStage _stage = EBadgeXferStage.idle;
  EBadgeXferStage get stage => _stage;

  void _to(EBadgeXferStage s, [String? detail]) {
    _stage = s;
    onStage?.call(s, detail);
  }

  /// 跑完一次传图。返回 null 表示成功，否则是失败原因（已同时写进 link 日志）。
  ///
  /// [name] / [type] / [body] 描述要传的文件。CRC32 在这里算一次，同时用于 Offer
  /// 的 TLV_XFER_CRC32 和 EBXF 头 —— §5.2 校验规则第 3 条要求两处必须相同，算两次
  /// 就给了它们不一致的机会。
  Future<String?> run({
    required String name,
    required int type,
    required Uint8List body,
    int? replaceId,
  }) async {
    if (!link.ready) {
      const msg = 'BLE 通道未就绪，无法发起传图';
      link.logError(msg);
      _to(EBadgeXferStage.failed, msg);
      return msg;
    }

    // 设备失败会走 0x16 FAIL 而不是在某个 await 上超时,所以整个会话期间都要盯着
    // 它。放在最外层订阅,任何阶段收到都能立刻中断。
    final failed = Completer<EBadgeTransferFail>();
    final failSub = link.frames
        .where((f) => f.cmd == EBadgeCmd.d2hTransferFail)
        .map(EBadgeTransferFail.parse)
        .where((f) => f != null)
        .cast<EBadgeTransferFail>()
        .listen((f) {
      if (!failed.isCompleted) failed.complete(f);
    });

    try {
      final crc = eBadgeCrc32(body);
      return await _run(
        name: name,
        type: type,
        body: body,
        crc: crc,
        replaceId: replaceId,
        deviceFailed: failed.future,
      );
    } finally {
      await failSub.cancel();
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
    _to(EBadgeXferStage.waitDecision, '等待用户在设备上确认');
    final offer = EBadgeRequest.transferOffer(
      name: name,
      type: type,
      size: body.length,
      crc32: crc,
      replaceId: replaceId,
    );
    if (!await link.send(
      offer,
      '$name ${EBadgeFileType.name(type)} ${body.length}B '
      'crc32=0x${crc.toRadixString(16).padLeft(8, '0')}',
    )) {
      return _fail('Offer 发送失败');
    }

    // ── 2. Decision（§5.5 限 30 s）────────────────────────────────────
    final decision = await _await<EBadgeTransferDecision>(
      cmd: EBadgeCmd.d2hTransferDecision,
      parse: EBadgeTransferDecision.parse,
      timeout: const Duration(seconds: 35), // 比设备的 30s 略宽,让它先超时
      deviceFailed: deviceFailed,
      what: '传图确认',
    );
    if (decision is String) return _fail(decision);
    final d = decision as EBadgeTransferDecision;
    if (!d.accepted) {
      final why = d.reason == null
          ? EBadgeDecision.name(d.decision)
          : '${EBadgeDecision.name(d.decision)} / '
              '${EBadgeXferError.name(d.reason!)}';
      return _fail('设备未同意传图：$why');
    }

    // ── 3. AP_INFO ─────────────────────────────────────────────────────
    // §4.7:设备在同意且 AP 就绪后应主动 Notify 0x13。它没主动发时我们补一发
    // 0x12 去问 —— 协议允许,且比直接判失败更宽容。
    _to(EBadgeXferStage.waitApInfo, '等待设备上报热点信息');
    var apResult = await _await<EBadgeApInfo>(
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
    final ap = apResult as EBadgeApInfo;
    if (ap.proto != 0x01) {
      // §4.7:TLV_AP_PROTO 在 V1.2 只有 0x01 合法。继续传下去也没意义。
      return _fail('设备上报的数据面协议 proto=0x'
          '${ap.proto.toRadixString(16).padLeft(2, '0')}，V1.2 只支持 0x01 裸 TCP');
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
    _to(EBadgeXferStage.uploading, '0 / ${body.length}B');
    final up = await wifi.upload(
      ip: ap.ipv4,
      port: ap.port,
      name: name,
      fileType: type,
      body: body,
      crc32: crc,
      onProgress: (sent, total) =>
          _to(EBadgeXferStage.uploading, '$sent / $total B'),
    );
    link.logInfo('TCP 上传结束', detail: up.describe());
    if (!up.succeed) return _fail('数据面上传失败：${up.describe()}');

    // ── 6. 等 BLE DONE ─────────────────────────────────────────────────
    // §5.3 明确:TCP status=成功**不替代** BLE 0x15 DONE,业务完成以 BLE 为准。
    _to(EBadgeXferStage.waitDone, '等待设备入库');
    final doneResult = await _await<EBadgeTransferDone>(
      cmd: EBadgeCmd.d2hTransferDone,
      parse: EBadgeTransferDone.parse,
      timeout: const Duration(seconds: 20),
      deviceFailed: deviceFailed,
      what: '入库结果',
    );
    if (doneResult is String) return _fail(doneResult);
    final done = doneResult as EBadgeTransferDone;
    _to(EBadgeXferStage.done,
        'file_id=${done.fileId} ${done.size}B ${done.name}');
    return null;
  }

  String _fail(String msg) {
    link.logError('传图中止', detail: msg);
    _to(EBadgeXferStage.failed, msg);
    return msg;
  }

  /// 等一个 D→H 帧。三方竞速：目标帧到了、设备回了 0x16 FAIL、或超时。
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
        deviceFailed.then<Object>((f) => '设备报告传图失败：'
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
