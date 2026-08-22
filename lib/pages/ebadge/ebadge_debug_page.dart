import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ebadge_link_provider.dart';
import '../../services/ebadge_link.dart';
import '../../services/ebadge_protocol.dart';
import '../../services/ebadge_stream_session.dart';
import '../../services/ebadge_transfer_session.dart';
import '../../services/ebadge_wifi_transport.dart';
import '../../services/image_jpeg.dart';
import '../../services/raster.dart';
import '../../theme/app_theme.dart';
import 'ebadge_stream_demo_frames.dart';

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

  /// 传图正文是否套那 16 字节设备图片头(`8B gui header + 4B 长度 + 4B 对齐`)。
  ///
  /// 做成开关而不是写死,是因为「设备到底要不要这层头」目前只能靠实测定论:图片页
  /// 走的是带头那条路且显示正常,但调试页早先发裸 JFIF 时设备收下了却不显示。留一个
  /// 开关,同一张图、同一份 JPEG 字节,两种封装各传一次就能把结论钉死 —— 改代码重编
  /// 再传对比,中间变量太多。
  ///
  /// 默认带头:与图片页(`image_page`,quality<100)发出去的字节结构一致。
  bool _xferWithHeader = true;

  /// 同屏预览(§6)会话状态。与传图共用「设备只允许单会话」这条约束(§6.7),
  /// 但两者是**不同的会话**:推流期间不能发传图 Offer,反之亦然,所以两个按钮
  /// 互相禁用(见 [_busy])。
  ///
  /// `_stream` 非 null 就表示会话还活着 —— 推流没有「跑完」这个终点,靠这个引用
  /// 才能在用户点「停止」时找到它。
  EBadgeStreamSession? _stream;
  EBadgeStreamStage _streamStage = EBadgeStreamStage.idle;
  String? _streamDetail;
  bool _streamStarting = false;

  /// 推流帧游标。§6 的载荷由 App 提供,这里按 tick 轮转四张固定测试帧。
  int _streamFrame = 0;

  /// 任一会话在跑 —— BLE 控制面就那一条,两条链路的握手混在一起,日志会乱到
  /// 没法看,设备也会回 BUSY。
  bool get _busy => _xferBusy || _streamStarting || _stream != null;

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
    // 退页面必须停推流:Timer 和 TCP 连接都不属于 widget 树,不停的话会一直往
    // 设备推帧,而且进程网络还绑在那张无外网的热点上 —— 表现是「退出调试页后
    // 全 App 没网」。stop() 内部会解绑。
    _stream?.stop();
    _stream = null;
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
        detail: '协议 §4.7 建议先 GET_STORAGE 校验容量,再发 Offer',
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
  /// **传的是示例图转出的 466×466 JPEG**,按设备图片格式封装(16B 头 + 裸 JFIF,
  /// 见 [_demoPayload]),不选相册 —— 调试台要的是可重复的基准:同一张图、同一档
  /// 质量,编码结果逐字节一致,CRC32 固定,设备回 XFER_ERR_VERIFY 就一定是链路问题
  /// 而非文件问题。用真 JPEG 而不是合成字节,是因为设备收下之后还要解码上屏 ——
  /// 递增字节能过 CRC 但解不出图,那样这条链路只测到一半。
  ///
  /// **副作用要知道**:连上设备热点期间原生侧会 `bindProcessToNetwork`,本进程所
  /// 有网络请求都改走这张无外网的热点,检查更新之类会失败;会话结束(含失败)会
  /// 自动解绑。这也是本按钮做成一次一会话、不允许并发的原因。
  Future<void> _wifiTransfer() async {
    if (_busy) return;

    // 编码要几百毫秒,先把按钮禁掉再去编 —— 否则这段时间里还能连点。
    setState(() {
      _xferBusy = true;
      _xferStage = EBadgeXferStage.idle;
      _xferDetail = '正在编码 $_demoImageSize×$_demoImageSize JPEG…';
    });

    final Uint8List body;
    try {
      body = await _demoPayload();
    } catch (e) {
      _link.logError('测试图编码失败', detail: '$e');
      if (mounted) {
        setState(() {
          _xferBusy = false;
          _xferStage = EBadgeXferStage.failed;
          _xferDetail = '测试图编码失败：$e';
        });
      }
      return;
    }
    if (!mounted) return;

    final storage = _storage;
    if (storage != null && !storage.canFit(body.length)) {
      _link.logError(
        '本地前置校验失败,未发起传图',
        detail: '协议 §2.9 要求 free ≥ size + ${EBadgeLimits.fsMargin};'
            '当前 free=${storage.free} size=${body.length}',
      );
      setState(() => _xferBusy = false);
      return;
    }
    if (storage == null) {
      _link.logInfo(
        '提示:尚未获取存储信息',
        detail: 'V1.3 §4.7 起这不再是硬性前置,设备收 Offer 会自己复检容量;'
            '先查一次只是能提前给出「空间不足」的提示',
      );
    }

    _link.logInfo(
      '测试图已就绪',
      detail: '$_demoFileName ${body.length}B ${_payloadShape(body)} '
          'file_type=${EBadgeFileType.name(_demoFileType)}',
    );

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
        type: _demoFileType,
        body: body,
      );
      if (!mounted) return;
      // 失败文本现在是「原因 + 已传字节数」两行,SnackBar 默认只给一行、3 秒就走。
      // 完整内容留在上方的 _XferProgress 里(可选中复制),这里只给一句提示 + 更长
      // 的停留时间,免得人还没读完就消失了。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err == null ? '传图完成' : '传图失败,详情见上方进度框'),
          duration: Duration(seconds: err == null ? 3 : 5),
          backgroundColor:
              err == null ? null : Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _xferBusy = false);
    }
  }

  /// 把即将上传的测试图正文导出到本地，用于在电脑上验证「转换对不对」。
  ///
  /// 导出的是 [_demoPayload] 的**同一份字节**（同一个缓存实例），不是重新编一次
  /// —— 重编虽然结果相同，但那就变成「验证另一份数据」了，万一编码器有不确定性
  /// 就正好漏掉。日志里同时记下长度和 CRC32，和传图时 Offer/EBXF 用的是同一个
  /// 数：文件的 CRC 与日志对得上，才能断定电脑上打开的就是设备收到的那份。
  Future<void> _saveDemoPayload() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);

    final Uint8List body;
    try {
      body = await _demoPayload();
    } catch (e) {
      _link.logError('测试图编码失败', detail: '$e');
      messenger.showSnackBar(SnackBar(content: Text('编码失败：$e')));
      return;
    }

    final crc = eBadgeCrc32(body);
    final crcHex = '0x${crc.toRadixString(16).padLeft(8, '0')}';
    _link.logInfo(
      '导出测试图正文',
      detail: '$_demoFileName ${body.length}B crc32=$crcHex '
          '${_payloadShape(body)}',
    );

    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出 Wi-Fi 传图测试正文',
        fileName: _demoFileName,
        bytes: body,
      );
      if (path == null) {
        messenger.showSnackBar(const SnackBar(content: Text('已取消导出')));
        return;
      }
      // Android/iOS 下 file_picker 自己落盘并返回路径；桌面端只给路径，要自己写。
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(body, flush: true);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('已导出 $_demoFileName（${body.length}B）')),
      );
    } catch (e) {
      _link.logError('导出测试图失败', detail: '$e');
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  /// 文件名跟着封装走:带头时正文是设备的 `.bin` 容器(与图片页、`file_cache.dart`
  /// 的 `image.bin` 一致),不带头时才是真正的 `.jpg` 文件。
  String get _demoFileName =>
      _xferWithHeader ? 'wifi_demo.bin' : 'wifi_demo.jpg';

  /// Offer / EBXF 头里报的 file_type,同样跟着封装走。
  ///
  /// 带头时报 [EBadgeFileType.bin]:正文外面套了 gui header,已经不是一个 JFIF
  /// 文件,报 jpeg(0x01) 等于让设备按裸 JPEG 去解最前面那 16 字节。不带头时正文
  /// 就是 JFIF,报 jpeg 才名副其实。
  ///
  /// **这个对应关系待与固件确认** —— 如果固件是靠 file_type=0x01 把文件路由给图片
  /// 解码器(而不是看容器里 offset 1 的 type),那带头时也得报 jpeg。传图日志里会
  /// 原样打出当前用的值,两种组合都能试。
  int get _demoFileType =>
      _xferWithHeader ? EBadgeFileType.bin : EBadgeFileType.jpeg;

  /// 测试图的边长。466 是设备圆屏的物理分辨率(见图片页的 `_sizePresets`),
  /// 传别的尺寸设备还得自己缩放,那就把「缩放对不对」也混进这条链路的变量里了。
  static const int _demoImageSize = 466;

  /// JPEG 质量。60 = 项目里各发送页统一的「MED / 一般画质」档(见轮播页和视频页的
  /// `_qualityPresets`),调试台跟着用同一个数,好让这里测出来的体积和画质与实际
  /// 业务发送路径可比。
  static const int _demoJpegQuality = 60;

  /// 正文结构的一行描述,传图和导出共用。
  ///
  /// 把「带没带头」写进日志是必须的:两种封装的字节数只差 16,单看长度分不出来,
  /// 而排查时最要紧的恰恰是「这一次发的到底是哪种」。
  String _payloadShape(Uint8List body) {
    const spec = '$_demoImageSize×$_demoImageSize q=$_demoJpegQuality '
        'baseline 4:2:0';
    if (!_xferWithHeader) return '= 裸 JFIF($spec),无 16B 头';
    return '= 16B 头 + ${body.length - kJpegHeaderBytes}B JPEG($spec)';
  }

  static const String _demoImageAsset =
      'assets/example/img/badge-preset-image-1.png';

  /// 编码好的**裸 JFIF** 正文缓存(不含 16B 头)。
  ///
  /// 缓存的是裸流而不是整包:带头/不带头两种封装共用同一份 JPEG 字节,切换开关只是
  /// 套不套那 16 字节,不用重跑 DCT。这既省掉几百毫秒,更重要的是保证两次传输比的
  /// 是**同一张图**,否则「换了封装就好了」有可能只是因为重编出了别的字节。
  ///
  /// 必须缓存:[encodeBaselineJpegYuv420] 是纯 Dart 的 DCT,466×466 要跑几百毫秒,
  /// 每次点按钮都重编会让 UI 明显卡一下,而且**每次编码结果都一样** —— 调试台要的
  /// 就是这个可重复性:CRC32 固定,设备回 XFER_ERR_VERIFY 就一定是链路问题,不是
  /// 文件问题。
  Uint8List? _demoJpeg;

  /// 取(必要时先生成)测试用的 466×466 图片正文。
  ///
  /// [_xferWithHeader] 为真时返回 [buildImageJpegBin] 那种**带 16 字节设备头的
  /// 容器**,和图片页(`image_page`,quality<100 那条路)发给设备的字节结构一致:
  ///
  ///   0..7    8B gui header(offset 1 = 0x0C 标记 JPEG,2..5 是宽高 LE)
  ///   8..11   JPEG 数据长度(uint32 LE)
  ///   12..15  对齐字节(全 0)
  ///   16..    baseline 4:2:0 裸 JFIF 字节
  ///
  /// 为假时只返回上面第 16 字节往后的那段,即裸 JFIF(SOI…EOI)。
  ///
  /// 两种都留着是因为协议 §5.2 只说 payload 是「原始文件字节」,没说清「原始文件」
  /// 指裸 JPEG 还是设备自己那套 `.bin` 容器 —— 固件按 offset 1 的 type 分支找
  /// RGB565 还是 JPEG,那就该带头;但这一点未与固件对齐前,实测比推断可靠。
  Future<Uint8List> _demoPayload() async {
    final jpeg = _demoJpeg ??= await _encodeDemoJpeg();
    if (!_xferWithHeader) return jpeg;
    return wrapImageJpegBin(jpeg, _demoImageSize, _demoImageSize);
  }

  /// 把示例图编成 466×466 的裸 JFIF。只在首次(或改了尺寸/质量后)跑一次。
  Future<Uint8List> _encodeDemoJpeg() async {
    final bytes = await DefaultAssetBundle.of(context).load(_demoImageAsset);
    final src = await decodeUiImage(bytes.buffer.asUint8List());
    try {
      // cover 居中裁切:示例图不是正方形,拉伸会让圆屏上的画面变形。
      final rgba = await cropResizeToRgba(
        src,
        targetW: _demoImageSize,
        targetH: _demoImageSize,
      );
      return encodeBaselineJpegYuv420(
        rgba.rgba,
        _demoImageSize,
        _demoImageSize,
        quality: _demoJpegQuality,
      );
    } finally {
      src.dispose();
    }
  }

  // ── §6 同屏预览(备用能力,仅协议调试)────────────────────────────────

  /// 期望帧率。10 fps:够看出画面在动,又给协议时序留足余量 —— §6.4 的帧超时是
  /// 3 s,10 fps 下每帧只占 100 ms 预算,不会因为本机慢而误触发设备侧清理。
  /// 设备可以回 decision=2 协商成更低的值,会话会照它给的走。
  static const int _streamFps = 10;
  static const String _streamName = 'stream_demo.jpg';

  /// 0x08 起一条 §6 同屏预览会话。
  ///
  /// **与拍照投屏(`/stream` 那条路径)没有任何关系**,不要混:
  ///
  /// | | 握手 | 帧头 | 画面来源 |
  /// | --- | --- | --- | --- |
  /// | 拍照投屏 | 自己那套 BLE 命令 | `0xA5 0xA9` 6B | 摄像头 + 原生编码器 |
  /// | 本按钮(§6) | 0x08 / 0x09 | 'EBXF' 14B | 内嵌的四张固定测试帧 |
  ///
  /// 本按钮**不开摄像头、不碰原生编码器**。碰了就会和拍照投屏抢 GL 上下文和编码
  /// 器实例,而调试台要的恰恰是「排除画面来源这个变量」——画面固定,设备上看到的
  /// 任何异常都能归因到协议实现。
  ///
  /// 推流是**没有终点的状态**,所以本方法只负责起会话;停止走 [_streamStop]。
  Future<void> _streamStart() async {
    if (_busy) return;

    setState(() {
      _streamStarting = true;
      _streamStage = EBadgeStreamStage.idle;
      _streamDetail = null;
      _streamFrame = 0;
    });

    final session = EBadgeStreamSession(
      link: _link,
      wifi: EBadgeWifiTransport(),
      onStage: (s, detail) {
        if (!mounted) return;
        setState(() {
          _streamStage = s;
          _streamDetail = detail;
          // 会话自己走到终态(设备报错、连接断)时要把引用清掉,否则按钮会一直
          // 停在「停止推流」,而背后已经没有会话可停了。
          if (s == EBadgeStreamStage.failed || s == EBadgeStreamStage.stopped) {
            _stream = null;
          }
        });
      },
    );

    final err = await session.start(
      name: _streamName,
      requestedFps: _streamFps,
      nextFrame: () => EBadgeStreamDemoFrames.at(_streamFrame++),
    );

    if (!mounted) return;
    setState(() {
      _streamStarting = false;
      // 握手失败时 onStage 已经把 _stream 清成 null 了;成功才留住引用。
      _stream = err == null ? session : null;
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), duration: const Duration(seconds: 3)),
      );
    }
  }

  /// 停推流。§6.4 的正常收尾就是 App 侧关 TCP —— 协议没有「结束推流」的 BLE 命令,
  /// 设备靠 3 s 帧超时或连接断开自行回 Idle。
  Future<void> _streamStop() async {
    final s = _stream;
    if (s == null) return;
    await s.stop();
    if (mounted) setState(() => _stream = null);
  }

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

  /// 0xFF DEBUG —— 私有调试命令,参数由弹窗现填。
  ///
  /// 做成表单而不是一格一个固定 subcmd 的按钮:subcmd 的含义是固件私下定的,
  /// 今天 0x01 是「进工厂模式」,换一版可能就变了。写死成按钮等于把一份会过期
  /// 的映射表刻进 App;让人当场填,反倒永远不会过期。
  Future<void> _sendDebug() async {
    final form = await showDialog<_DebugForm>(
      context: context,
      builder: (_) => const _DebugCmdDialog(),
    );
    if (form == null) return;
    try {
      await _send(
        EBadgeRequest.debug(form.subcmd, values: form.values),
        'subcmd=0x${form.subcmd.toRadixString(16).toUpperCase().padLeft(2, '0')}'
        '${form.values.isEmpty ? "(无载荷)" : "，${form.values.length} 条载荷"}',
      );
    } on ArgumentError catch (e) {
      _link.logError('DEBUG 参数非法', detail: e.message.toString());
    }
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
            enabled: !_busy,
            onTap: _wifiTransfer,
          ),
          _XferSaveButton(
            enabled: !_busy,
            onTap: _saveDemoPayload,
          ),
        ]),
        _XferHeaderToggle(
          withHeader: _xferWithHeader,
          enabled: !_busy,
          onChanged: (v) => setState(() => _xferWithHeader = v),
        ),
        if (_xferStage != EBadgeXferStage.idle || _xferBusy)
          _XferProgress(stage: _xferStage, detail: _xferDetail),
        const _Hint(
          '按 §5.4 完整时序跑:0x10 Offer → 0x11 同意 → 0x13 AP_INFO → '
          '连设备热点 → TCP 推 EBXF(40B 头)+ 正文 → 收 EBXR → 等 0x15 DONE。'
          '传的是示例图转出的 $_demoImageSize×$_demoImageSize baseline 4:2:0 JPEG'
          '(q=$_demoJpegQuality)。上面的开关决定正文封装:带头 = 8B gui header + '
          '4B JPEG 长度 + 4B 对齐 + 裸 JFIF(与图片页一致,file_type 报 BIN);'
          '不带头 = 只发裸 JFIF(file_type 报 JPEG)。两种共用同一份 JPEG 字节,'
          '切换不会重编,所以两次传输比的是同一张图。'
          '首次点按要先编码,约几百毫秒;之后复用同一份,CRC32 每次一致。'
          '「导出测试图」存的就是当前开关下要发的那份字节 —— 带头时在电脑上看图'
          '要先跳过前 16 字节。'
          '注意:连热点期间本机所有网络请求都走设备热点(无外网),会话结束自动恢复。',
        ),
        const SizedBox(height: 16),
        const _SectionLabel('同屏预览(§6 全链路,V1.3 新增)'),
        _CmdGrid(children: [
          _StreamButton(
            starting: _streamStarting,
            streaming: _stream != null,
            enabled: !_busy || _stream != null,
            onStart: _streamStart,
            onStop: _streamStop,
          ),
        ]),
        if (_streamStage != EBadgeStreamStage.idle || _streamStarting)
          _StreamProgress(stage: _streamStage, detail: _streamDetail),
        const _Hint(
          '按 §6.4 时序跑:0x08 OFFER(fps=$_streamFps)→ 0x09 DECISION → '
          '0x13 AP_INFO → 连热点 → TCP 连续推「14B 流头 + JPEG」直到手动停止。'
          '与 §5 的区别:流头只有 14 字节且不带文件名,EBXR 应答是可选的,'
          '设备侧帧间隔超 3 s 就会自行清理会话。',
        ),
        const _Hint(
          '推的是内嵌的 ${EBadgeStreamDemoFrames.count} 张 '
          '${EBadgeStreamDemoFrames.width}×${EBadgeStreamDemoFrames.height} '
          '测试帧(白块四格轮转,便于肉眼判断卡帧/丢帧)—— '
          '本按钮不开摄像头、不碰拍照投屏的编码器,两条链路完全独立。',
        ),
        const SizedBox(height: 16),
        const _SectionLabel('私有调试(协议文档之外)'),
        _CmdGrid(children: [
          _CmdButton(
            cmd: EBadgeCmd.h2dDebug,
            name: 'DEBUG',
            icon: Icons.bug_report_outlined,
            onTap: _sendDebug,
          ),
        ]),
        const _Hint(
          '0xFF 不在协议 §3 的命令表里,是厂商私有的调试通道 —— 首个 TLV 固定为 '
          'type=0x01 / len=1 的 subcmd(从 0x01 起),后面可选跟若干条载荷 TLV,'
          'type 从 0x02 顺序递增。',
        ),
        const _Hint(
          'subcmd 的含义由固件决定,协议文档里查不到,换固件版本可能整套改变 —— '
          '所以这里不预置按钮,每次现填。设备不认的 subcmd 通常没有任何回应,'
          '不回包不代表发送失败,对照日志里的发送字节确认本机组包正确即可。',
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
/// 「带 16B 设备头」开关。
///
/// 用 [SwitchListTile] 的紧凑版而不是两个单选按钮:这是个二元选择,而且两种取值都
/// 要能一眼看出当前是哪个 —— 排查时最怕的就是不知道刚才那一发到底带没带头,所以
/// 副标题直接把两种封装的字节结构写出来,不用回头翻代码或文档。
class _XferHeaderToggle extends StatelessWidget {
  const _XferHeaderToggle({
    required this.withHeader,
    required this.enabled,
    required this.onChanged,
  });

  final bool withHeader;

  /// 会话进行中禁止切换:正文在 [EBadgeTransferSession.run] 开始前就取好了,中途
  /// 改这个开关不会影响已发出的字节,却会让界面和日志说的不是同一件事。
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SwitchListTile(
        value: withHeader,
        onChanged: enabled ? onChanged : null,
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          withHeader ? '带 16B 设备头(.bin 容器)' : '不带头(裸 JFIF)',
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          withHeader
              ? '8B gui header + 4B JPEG 长度 + 4B 对齐 + JFIF，与图片页一致；'
                  'file_type 报 BIN'
              : '只发 SOI…EOI，不套容器；file_type 报 JPEG',
          style: const TextStyle(
            fontSize: 11,
            height: 1.3,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

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
  const _XferButton({
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final bool busy;

  /// 另一条链路(同屏预览)在跑时也要禁用 —— 设备侧 §5.7 / §6.7 各自只允许单
  /// 会话,BLE 控制面又只有一条,两边握手交错只会得到一堆 BUSY。
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: enabled ? onTap : null,
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

/// 把测试图正文存到本地的按钮。
///
/// 和传图按钮并排放在一格里,是因为它验证的是同一份字节:传图失败或设备不显示时,
/// 先把这份正文导到电脑上打开看一眼 —— 图本身是好的,就说明锅在链路或设备解码器;
/// 图打不开或花屏,才是本机编码的问题。少了这一步,两边只能互相猜。
class _XferSaveButton extends StatelessWidget {
  const _XferSaveButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_outlined, size: 16),
          SizedBox(width: 7),
          Text('导出测试图', style: TextStyle(fontSize: 12)),
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

  static const _detailStyle = TextStyle(
    fontSize: 11,
    height: 1.3,
    color: AppTheme.textSecondary,
  );

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
                    // 失败时用 SelectableText:这段文本里有已发字节数、EBXR 原始
                    // 字节、协议条款号,是要贴进问题单发给固件的东西 —— 不能选中
                    // 就只能照着屏幕抄,抄错一个字节整条线索就废了。
                    child: failed
                        ? SelectableText(detail!, style: _detailStyle)
                        : Text(detail!, style: _detailStyle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 「同屏预览」按钮 —— 一个按钮承担起/停两个动作。
///
/// 不拆成两个按钮:推流没有自然终点(§6 里 App 不发结束命令,靠关 TCP 收尾),
/// 「停止」在没推流时毫无意义,常驻一个灰按钮反而让人以为功能坏了。
class _StreamButton extends StatelessWidget {
  const _StreamButton({
    required this.starting,
    required this.streaming,
    required this.enabled,
    required this.onStart,
    required this.onStop,
  });

  /// 正在跑握手(还没进推流)。这段不能中断 —— 中途取消会让设备停在 WaitSta。
  final bool starting;
  final bool streaming;
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 推流中按钮改成红色的「停止」:此时它是**破坏性**动作(拆连接、解绑网络),
    // 和「开始」共用一个主色会让人误点。
    final stop = streaming;
    return FilledButton(
      onPressed: starting ? null : (enabled ? (stop ? onStop : onStart) : null),
      style: FilledButton.styleFrom(
        backgroundColor: stop ? cs.error : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (starting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
          else
            Icon(stop ? Icons.stop_circle_outlined : Icons.cast_connected,
                size: 16),
          const SizedBox(width: 7),
          Text(
            starting
                ? '握手中…'
                : stop
                    ? '停止推流'
                    : '同屏预览(全链路)',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 同屏预览阶段条。
///
/// 与 [_XferProgress] 分开而不把两个枚举塞进一个 widget:[EBadgeStreamStage] 的
/// [EBadgeStreamStage.streaming] 是个**稳定态**(会一直停在那儿刷帧数),而传图的
/// 每一阶段都是过渡态。文案上一个要说「4/4 推流中」、一个要说「4/6」,合并后光
/// 是标号就得挂两套 if。
class _StreamProgress extends StatelessWidget {
  const _StreamProgress({required this.stage, this.detail});

  final EBadgeStreamStage stage;
  final String? detail;

  static const _labels = {
    EBadgeStreamStage.idle: '准备',
    EBadgeStreamStage.waitDecision: '1/4 等设备确认(0x09)',
    EBadgeStreamStage.waitApInfo: '2/4 等热点信息(0x13)',
    EBadgeStreamStage.joiningAp: '3/4 连接热点',
    EBadgeStreamStage.streaming: '4/4 推流中',
    EBadgeStreamStage.stopped: '已停止',
    EBadgeStreamStage.failed: '已中止',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final failed = stage == EBadgeStreamStage.failed;
    final live = stage == EBadgeStreamStage.streaming;
    final color = failed
        ? cs.error
        : live
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
                : live
                    ? Icons.sensors
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
    (EBadgeCmd.d2hJpgStreamDecision, '同屏决定'),
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

// ---------------------------------------------------------------------------
// 0xFF DEBUG 表单
// ---------------------------------------------------------------------------

class _DebugForm {
  const _DebugForm(this.subcmd, this.values);

  final int subcmd;

  /// 可选载荷,每个元素是一条 TLV 的完整 value(可为多字节)。
  final List<List<int>> values;
}

/// 0xFF DEBUG 的参数弹窗:一个 subcmd + 任意条载荷。
///
/// 载荷统一按**十六进制字节串**输入(`0A 1B` 或 `0a1b`),不提供「按十进制/
/// 字符串填」的开关:私有调试命令的参数就是一串字节,给它套上类型选择只会多一步
/// 猜测 —— 到底填的是 uint16 小端还是两个 uint8,只有固件那边知道。
class _DebugCmdDialog extends StatefulWidget {
  const _DebugCmdDialog();

  @override
  State<_DebugCmdDialog> createState() => _DebugCmdDialogState();
}

class _DebugCmdDialogState extends State<_DebugCmdDialog> {
  /// 默认 1 —— 需求里 val 从 0x1 开始,也是最常按的那一个。
  final _subcmd = TextEditingController(text: '01');

  /// 载荷输入框。初始为空:载荷是可选的,大多数 subcmd 只需要一个命令号。
  final _values = <TextEditingController>[];

  String? _error;

  @override
  void dispose() {
    _subcmd.dispose();
    for (final c in _values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 解析一段十六进制字节串。允许空格分隔或连写,大小写不限。
  /// 返回 null 表示格式不对(错误信息写进 [_error])。
  List<int>? _parseHex(String s, String field) {
    final compact = s.replaceAll(RegExp(r'[\s,]'), '');
    if (compact.isEmpty) return const [];
    if (compact.length.isOdd) {
      _error = '$field:十六进制位数为奇数,一个字节要两位';
      return null;
    }
    final out = <int>[];
    for (var i = 0; i < compact.length; i += 2) {
      final b = int.tryParse(compact.substring(i, i + 2), radix: 16);
      if (b == null) {
        _error = '$field:「${compact.substring(i, i + 2)}」不是十六进制';
        return null;
      }
      out.add(b);
    }
    return out;
  }

  void _submit() {
    setState(() => _error = null);

    final sc = _parseHex(_subcmd.text, 'subcmd');
    if (sc == null) {
      setState(() {});
      return;
    }
    if (sc.length != 1) {
      setState(() => _error = 'subcmd 固定 1 字节(len=1),当前 ${sc.length} 字节');
      return;
    }
    if (sc[0] == 0) {
      setState(() => _error = 'subcmd 从 0x01 起,不能是 0x00');
      return;
    }

    final vals = <List<int>>[];
    for (var i = 0; i < _values.length; i++) {
      final v = _parseHex(_values[i].text, '载荷 ${i + 1}');
      if (v == null) {
        setState(() {});
        return;
      }
      // 空输入框直接跳过,而不是发一条 len=0 的 TLV:用户加了框又没填,意图是
      // 「不发这条」,不是「发个空的」。
      if (v.isEmpty) continue;
      vals.add(v);
    }

    Navigator.pop(context, _DebugForm(sc[0], vals));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('0xFF DEBUG'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hexField(_subcmd, 'subcmd(type 0x01, len 1)'),
            for (var i = 0; i < _values.length; i++)
              Row(
                children: [
                  Expanded(
                    child: _hexField(
                      _values[i],
                      '载荷 ${i + 1}(type 0x'
                      '${(0x02 + i).toRadixString(16).toUpperCase().padLeft(2, '0')}'
                      ')',
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      // 删中间一条会让后面所有载荷的 type 前移一位 —— 这是刻意
                      // 的:type 由位置决定(0x02 起递增),不是输入框自带的属性。
                      _values.removeAt(i).dispose();
                    }),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _values.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('加一条载荷'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const Text(
              '按十六进制填,空格可省:0A 或 0a1b。载荷可多字节,'
              'type 按顺序从 0x02 递增。',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('发送')),
      ],
    );
  }

  Widget _hexField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          // 等宽字体:调试时要逐字节核对,变宽字体下 0 和 O 看着一样。
          style: const TextStyle(fontFamily: 'monospace'),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F\s]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}
