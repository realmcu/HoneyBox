import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ebadge_link_provider.dart';
import '../../services/ebadge_link.dart';
import '../../services/ebadge_protocol.dart';
import '../../services/ebadge_transfer_session.dart';
import '../../services/ebadge_wifi_transport.dart';
import '../../theme/app_theme.dart';

/// eBadge 协议调试页。
///
/// 布局按需求固定成两段:**上半是冻结的日志区**(自己内部滚动,不随下方内容
/// 移动),**下半是各 CMD 快捷命令**。用 `Column` + 定高日志区 + `Expanded`
/// 命令区实现 —— 不用 `CustomScrollView`/`SliverAppBar`,那种「吸顶」在下滑时
/// 仍会收缩高度,不是真冻结。
///
/// **配色注意**:本页所有次要文字一律用 [AppTheme.textSecondary] /
/// [AppTheme.textPrimary],**不要用 `cs.outline`** —— 那是主题里的描边/分割线
/// 色(#DADCE0),在近白底上对比度只有 1.4:1,当文字色会看不清。日志是本页的
/// 主要内容而非装饰,时间戳和 hex 同样要读得清。
class EBadgeDebugPage extends ConsumerStatefulWidget {
  const EBadgeDebugPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  final String deviceName;
  final String deviceId;

  @override
  ConsumerState<EBadgeDebugPage> createState() => _EBadgeDebugPageState();
}

class _EBadgeDebugPageState extends ConsumerState<EBadgeDebugPage> {
  final _logScroll = ScrollController();
  StreamSubscription<void>? _logSub;
  StreamSubscription<EBadgeFrame>? _frameSub;

  /// 设备信息区的最新值 —— 由 0x18 / 0x1A / 0x13 的应答填充。
  EBadgeBattery? _battery;
  EBadgeStorageInfo? _storage;
  EBadgeApInfo? _apInfo;

  bool _attaching = true;
  bool _autoScroll = true;

  /// 传图会话状态。设备侧只允许单会话(§5.7 非 Idle 收到新 Offer 回 BUSY),
  /// 所以按钮期间要禁用,不能靠用户自觉不连点。
  bool _xferBusy = false;
  EBadgeXferStage _xferStage = EBadgeXferStage.idle;
  String? _xferDetail;

  /// 日志区占屏高比例。0.42 是权衡出来的:再高命令区就装不下两行按钮,
  /// 再低日志一次只能看三四条,来回滚反而更慢。
  static const double _logHeightFactor = 0.42;

  EBadgeLink get _link => ref.read(
        eBadgeLinkProvider(
          EBadgeLinkArgs(
            deviceId: widget.deviceId,
            deviceName: widget.deviceName,
          ),
        ),
      );

  @override
  void initState() {
    super.initState();
    // provider 的读取要等 widget 挂载完 —— initState 里 ref.read 对
    // autoDispose family 是安全的,但订阅回调里会 setState,所以放到帧后。
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final link = _link;

    _logSub = link.onLogChanged.listen((_) {
      if (!mounted) return;
      setState(() {});
      if (_autoScroll) _scrollToBottom();
    });

    _frameSub = link.frames.listen((f) {
      if (!mounted) return;
      switch (f.cmd) {
        case EBadgeCmd.d2hBattery:
          final b = EBadgeBattery.parse(f);
          if (b != null) setState(() => _battery = b);
        case EBadgeCmd.d2hStorageInfo:
          final s = EBadgeStorageInfo.parse(f);
          if (s != null) setState(() => _storage = s);
        case EBadgeCmd.d2hApInfo:
          final a = EBadgeApInfo.parse(f);
          if (a != null) setState(() => _apInfo = a);
      }
    });

    await link.attach();
    if (mounted) setState(() => _attaching = false);
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _frameSub?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // 等这一帧的列表长度生效后再滚,否则 maxScrollExtent 还是旧值。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScroll.hasClients) return;
      _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  // ── 命令动作 ────────────────────────────────────────────────────────

  Future<void> _send(Uint8List frame, String label) async {
    await _link.send(frame, label);
  }

  Future<void> _reattach() async {
    setState(() => _attaching = true);
    await _link.attach();
    if (mounted) setState(() => _attaching = false);
  }

  void _copyLog() {
    final text = _link.log.map((e) => e.toPlainText()).join('\n');
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制'), duration: Duration(seconds: 1)),
    );
  }

  /// 0x01 SET_TIME —— 用当前手机时间。
  Future<void> _setTime() async {
    final now = DateTime.now();
    final t = '${now.year}-${_two(now.month)}-${_two(now.day)} '
        '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)} '
        '周${_weekCn(now.weekday)}';
    await _send(EBadgeRequest.setTime(now), t);
  }

  /// 0x03 SEND_MSG —— 弹一个表单填四个字段。
  Future<void> _sendMsg() async {
    final result = await showDialog<_MsgForm>(
      context: context,
      builder: (_) => const _SendMsgDialog(),
    );
    if (result == null) return;
    try {
      await _send(
        EBadgeRequest.sendMsg(
          appName: result.appName,
          title: result.title,
          text: result.text,
          date: result.date.isEmpty ? null : result.date,
        ),
        '${result.appName} / ${result.title}',
      );
    } on ArgumentError catch (e) {
      _link.logError('SEND_MSG 参数超限', detail: e.message.toString());
    }
  }

  /// 0x10 TRANSFER_OFFER —— **只发 Offer**,不接后续 Wi-Fi 上传。
  ///
  /// 保留这个按钮是为了单独验证控制面握手:能看到设备弹不弹确认窗、回 0x11 还是
  /// 直接 0x16。想跑完整链路请用「WIFI 传图」按钮([_wifiTransfer])。
  ///
  /// 注意:本按钮发完就不管了,设备会停在 WaitSta 直到 §5.5 的 60s 超时,期间
  /// 再发 Offer 会被回 XFER_ERR_BUSY(§5.7)。这是预期行为,不是 bug。
  Future<void> _transferOffer() async {
    final storage = _storage;
    const size = 64 * 1024;
    if (storage != null && !storage.canFit(size)) {
      _link.logError(
        '本地前置校验失败,未发送 Offer',
        detail: '协议 §2.9 要求 free ≥ size + ${EBadgeLimits.fsMargin};'
            '当前 free=${storage.free} size=$size',
      );
      return;
    }
    if (storage == null) {
      _link.logInfo(
        '提示:尚未获取存储信息',
        detail: '协议 §4.5 建议先 GET_STORAGE 校验容量,再发 Offer',
      );
    }
    await _send(
      EBadgeRequest.transferOffer(
        name: 'debug.jpg',
        type: EBadgeFileType.jpeg,
        size: size,
        crc32: eBadgeCrc32(List<int>.filled(16, 0x41)),
      ),
      'debug.jpg JPEG ${size}B(调试假 Offer,不接上传)',
    );
  }

  /// Wi-Fi 数据面全链路传图(协议 §5.4 完整时序)。
  ///
  /// 与 [_transferOffer] 的分工:那个只发一帧 Offer 看设备怎么回,本按钮把
  /// Offer → Decision → AP_INFO → 连热点 → TCP 推 EBXF → 收 EBXR → 等 0x15 DONE
  /// 整条链路跑完,时序编排在 [EBadgeTransferSession] 里。
  ///
  /// **传的是固定的合成数据**,不选相册 —— 调试台要的是可重复的基准,固定数据下
  /// CRC32 每次都一样,设备回 XFER_ERR_VERIFY 就一定是链路问题而非文件问题。
  ///
  /// **副作用要知道**:连上设备热点期间原生侧会 `bindProcessToNetwork`,本进程所
  /// 有网络请求都改走这张无外网的热点,检查更新之类会失败;会话结束(含失败)会
  /// 自动解绑。这也是本按钮做成一次一会话、不允许并发的原因。
  Future<void> _wifiTransfer() async {
    if (_xferBusy) return;

    final storage = _storage;
    final body = _demoPayload();
    if (storage != null && !storage.canFit(body.length)) {
      _link.logError(
        '本地前置校验失败,未发起传图',
        detail: '协议 §2.9 要求 free ≥ size + ${EBadgeLimits.fsMargin};'
            '当前 free=${storage.free} size=${body.length}',
      );
      return;
    }
    if (storage == null) {
      _link.logInfo(
        '提示:尚未获取存储信息',
        detail: '协议 §4.5 要求发 Offer 前先 0x19 GET_STORAGE 校验容量',
      );
    }

    setState(() {
      _xferBusy = true;
      _xferStage = EBadgeXferStage.idle;
      _xferDetail = null;
    });

    final session = EBadgeTransferSession(
      link: _link,
      wifi: EBadgeWifiTransport(),
      onStage: (s, detail) {
        if (!mounted) return;
        setState(() {
          _xferStage = s;
          _xferDetail = detail;
        });
      },
    );

    try {
      final err = await session.run(
        name: _demoFileName,
        type: EBadgeFileType.bin,
        body: body,
      );
      if (!mounted) return;
      final msg = err ?? '传图完成';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    } finally {
      if (mounted) setState(() => _xferBusy = false);
    }
  }

  static const String _demoFileName = 'wifi_demo.bin';

  /// 固定的测试载荷。
  ///
  /// 用递增字节而非全零:全零的数据一旦被截断或错位,CRC32 仍可能凑巧对得上,
  /// 而递增序列任何一段错位都会立刻反映在校验值上。16 KiB 也刻意大于
  /// [EBadgeWifiTransport.upload] 默认的 8 KiB 分块,好让进度回调真的走两次
  /// 以上 —— 只走一次的话,分块逻辑坏了也看不出来。
  Uint8List _demoPayload() =>
      Uint8List.fromList(List.generate(16 * 1024, (i) => i & 0xFF));

  /// 0x02 SEND_FILE —— 固定数据的小文件直传模拟(§4.2)。
  ///
  /// 发的就是协议文档 §4.2 那个示例本身:`a.bin` / type=JPEG(0x01) / 4 字节
  /// 正文 `DE AD BE EF`。刻意不做成可填参数的表单 —— 调试台上最有用的是一条
  /// **字节可预期**的基准:元数据帧应当逐字节等于
  /// `01 02 80 13 00 | 01 05 00 61 2E 62 69 6E | 02 01 00 01 | 04 04 00 04 00 00 00`,
  /// 对不上就是本机组包错了,不用怀疑设备。
  ///
  /// 注意文档示例本身把 `.bin` 标成了 JPEG 类型 —— 这里照抄不改,因为基准的
  /// 价值在于和文档逐字节一致。
  ///
  /// 和 0x10 TRANSFER_OFFER 的分工:Offer 走 Wi-Fi 数据面传大图(要 AP、TCP、
  /// 分片、进度上报),本命令是**纯 BLE 直传**,元数据 TLV 之后在同一条 RX 流
  /// 上紧跟正文,没有确认交互也没有进度 Notify,只有一个 0x04 RESULT 回来。
  /// §4.2 明确禁止用它传壁纸大图。
  Future<void> _sendFileDemo() async {
    const name = 'a.bin';
    final body = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);

    final meta = EBadgeRequest.sendFileMeta(
      name: name,
      type: EBadgeFileType.jpeg,
      length: body.length,
    );

    // 元数据没写成功就别发正文 —— 设备此时不知道要收多少字节,裸的 DE AD BE EF
    // 会被当成下一帧的帧头去解析,后面所有帧都跟着错位。
    if (!await _link.send(meta, '$name JPEG ${body.length}B(§4.2 固定示例)')) {
      return;
    }
    await _link.sendRaw(body, '$name 正文(§4.2 固定示例)');
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _weekCn(int weekday) =>
      const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];

  // ── 构建 ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 依赖 provider,让 autoDispose 在本页存活期间保持 link 不被回收。
    ref.watch(eBadgeLinkProvider(
      EBadgeLinkArgs(deviceId: widget.deviceId, deviceName: widget.deviceName),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('协议调试'),
        actions: [
          IconButton(
            tooltip: '复制日志',
            onPressed: _copyLog,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: '清空日志',
            onPressed: () {
              _link.clearLog();
              setState(() {});
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 冻结区:设备信息 + 日志 ──
          SizedBox(
            height: MediaQuery.sizeOf(context).height * _logHeightFactor,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                // 纯白底而非半透明灰:日志是要逐字读的正文,底色越干净字越清楚。
                color: AppTheme.surface,
                border: Border(
                  bottom: BorderSide(color: cs.outline, width: 1),
                ),
              ),
              child: Column(
                children: [
                  _DeviceInfoBar(
                    deviceName: widget.deviceName,
                    deviceId: widget.deviceId,
                    ready: _link.ready,
                    attaching: _attaching,
                    mtu: _link.mtu,
                    battery: _battery,
                    storage: _storage,
                    apInfo: _apInfo,
                    onRetry: _reattach,
                  ),
                  Divider(height: 1, color: cs.outline),
                  const _ColorLegend(),
                  Expanded(child: _buildLogList()),
                  _LogToolbar(
                    count: _link.log.length,
                    violationCount:
                        _link.log.where((e) => e.hasViolation).length,
                    autoScroll: _autoScroll,
                    onAutoScrollChanged: (v) {
                      setState(() => _autoScroll = v);
                      if (v) _scrollToBottom();
                    },
                  ),
                ],
              ),
            ),
          ),
          // ── 滚动区:CMD 快捷命令 ──
          Expanded(child: _buildCommandArea()),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    final entries = _link.log;
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          '暂无收发记录',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      controller: _logScroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: entries.length,
      itemBuilder: (_, i) => _LogRow(entry: entries[i]),
    );
  }

  Widget _buildCommandArea() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionLabel('查询类(无参数)'),
        _CmdGrid(children: [
          _CmdButton(
            cmd: EBadgeCmd.h2dGetBattery,
            name: 'GET_BATTERY',
            icon: Icons.battery_charging_full_outlined,
            onTap: () => _send(EBadgeRequest.getBattery(), '查询电量'),
          ),
          _CmdButton(
            cmd: EBadgeCmd.h2dGetStorage,
            name: 'GET_STORAGE',
            icon: Icons.sd_storage_outlined,
            onTap: () => _send(EBadgeRequest.getStorage(), '查询存储'),
          ),
          _CmdButton(
            cmd: EBadgeCmd.h2dGetApInfo,
            name: 'GET_AP_INFO',
            icon: Icons.wifi_tethering,
            onTap: () => _send(EBadgeRequest.getApInfo(), '查询热点信息'),
          ),
        ]),
        const SizedBox(height: 16),
        const _SectionLabel('设置类'),
        _CmdGrid(children: [
          _CmdButton(
            cmd: EBadgeCmd.h2dSetTime,
            name: 'SET_TIME',
            icon: Icons.schedule,
            onTap: _setTime,
          ),
          _CmdButton(
            cmd: EBadgeCmd.h2dSendMsg,
            name: 'SEND_MSG',
            icon: Icons.notifications_active_outlined,
            onTap: _sendMsg,
          ),
        ]),
        const SizedBox(height: 16),
        const _SectionLabel('文件类'),
        _CmdGrid(children: [
          _CmdButton(
            cmd: EBadgeCmd.h2dSendFile,
            name: 'SEND_FILE',
            icon: Icons.insert_drive_file_outlined,
            onTap: _sendFileDemo,
          ),
          _CmdButton(
            cmd: EBadgeCmd.h2dTransferOffer,
            name: 'TRANSFER_OFFER',
            icon: Icons.upload_file_outlined,
            onTap: _transferOffer,
          ),
        ]),
        // 两个文件类命令都发固定假数据,按下去会往设备里真写东西 —— 这一点必须
        // 写在界面上,不能只留在代码注释里。
        const _Hint(
          'SEND_FILE 发 §4.2 文档示例:a.bin / JPEG / 正文 DE AD BE EF,'
          '经 BLE 直传落到 <FAT_ROOT>/a.bin,应答为 0x04 RESULT。'
          '大图壁纸禁走此路,须用 TRANSFER_OFFER 走 Wi-Fi 数据面。',
        ),
        const SizedBox(height: 16),
        const _SectionLabel('Wi-Fi 数据面(§5 全链路)'),
        _CmdGrid(children: [
          _XferButton(
            busy: _xferBusy,
            onTap: _wifiTransfer,
          ),
        ]),
        if (_xferStage != EBadgeXferStage.idle || _xferBusy)
          _XferProgress(stage: _xferStage, detail: _xferDetail),
        const _Hint(
          '按 §5.4 完整时序跑:0x10 Offer → 0x11 同意 → 0x13 AP_INFO → '
          '连设备热点 → TCP 推 EBXF(40B 头)+ 正文 → 收 EBXR → 等 0x15 DONE。'
          '固定传 16 KiB 递增字节,文件名 $_demoFileName。'
          '注意:连热点期间本机所有网络请求都走设备热点(无外网),会话结束自动恢复。',
        ),
        const SizedBox(height: 16),
        const _SectionLabel('设备上报(只读,由设备主动发起)'),
        const _D2hLegend(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 设备信息条
// ---------------------------------------------------------------------------

class _DeviceInfoBar extends StatelessWidget {
  const _DeviceInfoBar({
    required this.deviceName,
    required this.deviceId,
    required this.ready,
    required this.attaching,
    required this.mtu,
    required this.battery,
    required this.storage,
    required this.apInfo,
    required this.onRetry,
  });

  final String deviceName;
  final String deviceId;
  final bool ready;
  final bool attaching;
  final int mtu;
  final EBadgeBattery? battery;
  final EBadgeStorageInfo? storage;
  final EBadgeApInfo? apInfo;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final statusColor = attaching
        ? AppTheme.textSecondary
        : ready
            ? Colors.green.shade600
            : cs.error;
    final statusText = attaching
        ? '挂载中…'
        : ready
            ? '通道就绪'
            : '通道未就绪';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$deviceName · $statusText · MTU $mtu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(color: statusColor),
                ),
              ),
              if (!ready && !attaching)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('重试'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              _kv('ID', deviceId.isEmpty ? '—' : deviceId, tt),
              if (battery != null)
                _kv(
                  '电量',
                  '${battery!.percent}% '
                      '${EBadgeChargeState.name(battery!.charge)}',
                  tt,
                ),
              if (storage != null)
                _kv(
                  '存储',
                  '${_mib(storage!.free)}/${_mib(storage!.total)} 可用 · '
                      '壁纸 ${storage!.wpCount} 张',
                  tt,
                ),
              if (apInfo != null)
                _kv('热点', '${apInfo!.ssid} → ${apInfo!.ipv4}:${apInfo!.port}',
                    tt),
            ],
          ),
        ],
      ),
    );
  }

  static String _mib(int b) => '${(b / 1048576).toStringAsFixed(1)}M';

  /// 标签用 textSecondary、值用 textPrimary —— 让「电量」和「87%」拉开层次靠
  /// 深浅差,而不是把标签压到看不见。
  Widget _kv(String k, String v, TextTheme tt) => Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$k ',
            style: tt.bodySmall
                ?.copyWith(color: AppTheme.textSecondary, fontSize: 11),
          ),
          TextSpan(
            text: v,
            style: tt.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------
// 日志
// ---------------------------------------------------------------------------

/// 日志一行。配色承担两件事:**方向**(发=蓝、收=青)和**合规**(违规=红)。
/// 两者冲突时红色优先 —— 方向随时能从箭头看出来,而「这帧不合协议」是唯一
/// 需要被立刻注意到的信息。
class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final EBadgeLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (dirColor, arrow) = switch (entry.kind) {
      // 蓝 = H→D,与 AppBar 主色同源,视觉上"这是我发的"。
      EBadgeLogKind.send => (cs.primary, '→'),
      // 青 = D→H;shade800 而非 shade700,收方向的字要在浅底上足够沉。
      EBadgeLogKind.recv => (Colors.teal.shade800, '←'),
      EBadgeLogKind.info => (AppTheme.textSecondary, 'ⓘ'),
      EBadgeLogKind.error => (cs.error, '✗'),
    };

    // 违规帧整行改红,并把箭头换成叹号:色觉障碍用户靠形状也能分辨,不能让
    // 「哪帧有问题」只编码在颜色里。
    final bad = entry.hasViolation;
    final color = bad ? cs.error : dirColor;
    final mark = bad ? '!' : arrow;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      // 红字之外再给一层浅红底 + 左侧红条,让违规行在快速滚动的日志里也能被
      // 余光扫到。
      decoration: bad
          ? BoxDecoration(
              color: cs.error.withValues(alpha: 0.06),
              border: Border(left: BorderSide(color: cs.error, width: 2.5)),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(3),
              ),
            )
          : null,
      padding: bad ? const EdgeInsets.fromLTRB(5, 3, 3, 3) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.timeText,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                  height: 1.25,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                mark,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                    height: 1.2),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: color,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (entry.detail != null && entry.detail!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: bad ? 61 : 66, top: 1),
              child: Text(
                entry.detail!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
          if (entry.hex != null)
            Padding(
              padding: EdgeInsets.only(left: bad ? 61 : 66, top: 1),
              child: Text(
                entry.hex!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                  height: 1.3,
                ),
              ),
            ),
          // 逐条列出违规原因(带章节号)。只标红不说理由的话,调试的人还得回去
          // 翻协议文档才知道哪儿错了。
          for (final v in entry.violations)
            Padding(
              padding: EdgeInsets.only(left: bad ? 61 : 66, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 12, color: cs.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      v.hint,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.error,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LogToolbar extends StatelessWidget {
  const _LogToolbar({
    required this.count,
    required this.violationCount,
    required this.autoScroll,
    required this.onAutoScrollChanged,
  });

  final int count;

  /// 含协议违规的条数。日志滚上去之后红行会看不见,所以在这里给个常驻计数。
  final int violationCount;
  final bool autoScroll;
  final ValueChanged<bool> onAutoScrollChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 30,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text('$count 条',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          if (violationCount > 0) ...[
            const SizedBox(width: 8),
            Icon(Icons.error_outline, size: 13, color: cs.error),
            const SizedBox(width: 3),
            Text(
              '$violationCount 条违规',
              style: TextStyle(
                fontSize: 11,
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          const Text('自动滚动',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: autoScroll,
              onChanged: onAutoScrollChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 命令按钮
// ---------------------------------------------------------------------------

/// 日志配色图例。颜色编码的含义必须写在界面上 —— 只在代码注释里解释,用的人
/// 看不到。
class _ColorLegend extends StatelessWidget {
  const _ColorLegend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <(Color, String, String)>[
      (cs.primary, '→', '发送 H→D'),
      (Colors.teal.shade800, '←', '接收 D→H'),
      (cs.error, '!', '协议违规'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 14,
        runSpacing: 2,
        children: [
          for (final (c, mark, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mark,
                  style: TextStyle(
                    fontSize: 12,
                    color: c,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: c,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

/// 命令区里的一段说明文字。按钮名(SEND_FILE)说不清「按下去会发生什么」,
/// 而这里的命令都会真往设备里写数据,后果得先讲明白。
class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CmdGrid extends StatelessWidget {
  const _CmdGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _CmdButton extends StatelessWidget {
  const _CmdButton({
    required this.cmd,
    required this.name,
    required this.icon,
    required this.onTap,
  });

  final int cmd;
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hex = '0x${cmd.toRadixString(16).toUpperCase().padLeft(2, '0')}';
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(hex,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppTheme.textSecondary,
              )),
          const SizedBox(width: 4),
          Text(name,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

/// 「WIFI 传图」按钮。
///
/// 单独写一个而不复用 [_CmdButton]:那个按钮一格对一条 cmd,而全链路传图要发
/// 0x10/0x12 两条、收四条,标不上单一 cmd 号;它还需要一个 [_CmdButton] 没有的
/// 「进行中禁用」态 —— 设备侧 §5.7 只允许单会话,连点第二次必然被回 BUSY。
class _XferButton extends StatelessWidget {
  const _XferButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
          else
            const Icon(Icons.wifi_tethering, size: 16),
          const SizedBox(width: 7),
          Text(busy ? '传图中…' : 'WIFI 传图(全链路)',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// 传图阶段条。
///
/// 只显示当前阶段而不做成六格进度条:阶段之间的耗时差了两个数量级(等用户确认
/// 可能 30 s,推 16 KiB 是毫秒级),等宽的六格反而会让人以为卡住了。
class _XferProgress extends StatelessWidget {
  const _XferProgress({required this.stage, this.detail});

  final EBadgeXferStage stage;
  final String? detail;

  static const _labels = {
    EBadgeXferStage.idle: '准备',
    EBadgeXferStage.waitDecision: '1/6 等设备确认',
    EBadgeXferStage.waitApInfo: '2/6 等热点信息',
    EBadgeXferStage.joiningAp: '3/6 连接热点',
    EBadgeXferStage.uploading: '4/6 TCP 上传',
    EBadgeXferStage.waitDone: '5/6 等设备入库',
    EBadgeXferStage.done: '6/6 完成',
    EBadgeXferStage.failed: '已中止',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final failed = stage == EBadgeXferStage.failed;
    final done = stage == EBadgeXferStage.done;
    final color = failed
        ? cs.error
        : done
            ? AppTheme.secondary
            : cs.primary;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed
                ? Icons.error_outline
                : done
                    ? Icons.check_circle_outline
                    : Icons.sync,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labels[stage] ?? '$stage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail!,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 设备上报命令一览。这些是 D→H 方向,app 发不了,列出来是为了对照日志里
/// 收到的 cmd 号 —— 调试时最常问的就是「设备回的这个 0x16 是什么」。
class _D2hLegend extends StatelessWidget {
  const _D2hLegend();

  static const _items = [
    (EBadgeCmd.d2hResult, '通用结果'),
    (EBadgeCmd.d2hTransferDecision, '传图决定'),
    (EBadgeCmd.d2hApInfo, '热点信息'),
    (EBadgeCmd.d2hTransferProgress, '传输进度'),
    (EBadgeCmd.d2hTransferDone, '传输完成'),
    (EBadgeCmd.d2hTransferFail, '传输失败'),
    (EBadgeCmd.d2hBattery, '电量'),
    (EBadgeCmd.d2hStorageInfo, '存储信息'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (cmd, cn) in _items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '0x${cmd.toRadixString(16).toUpperCase().padLeft(2, '0')} '
              '${EBadgeCmd.name(cmd)} · $cn',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SEND_MSG 表单
// ---------------------------------------------------------------------------

class _MsgForm {
  const _MsgForm(this.appName, this.title, this.text, this.date);
  final String appName;
  final String title;
  final String text;
  final String date;
}

class _SendMsgDialog extends StatefulWidget {
  const _SendMsgDialog();

  @override
  State<_SendMsgDialog> createState() => _SendMsgDialogState();
}

class _SendMsgDialogState extends State<_SendMsgDialog> {
  final _app = TextEditingController(text: 'WeChat');
  final _title = TextEditingController(text: 'HoneyBox');
  final _text = TextEditingController(text: 'hello ebadge');
  final _date = TextEditingController();

  @override
  void dispose() {
    _app.dispose();
    _title.dispose();
    _text.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('0x03 SEND_MSG'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 每字段 ≤23 字节(协议 §2.8)。中文按 UTF-8 一字 3 字节算,所以
            // maxLength 只能当粗提示,真正的拦截在 EBadgeCodec.str。
            _field(_app, 'app_name'),
            _field(_title, 'title'),
            _field(_text, 'text'),
            _field(_date, 'date(可选)'),
            const SizedBox(height: 4),
            const Text(
              '每字段上限 23 字节(UTF-8);中文一字算 3 字节',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _MsgForm(_app.text, _title.text, _text.text, _date.text),
          ),
          child: const Text('发送'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}
