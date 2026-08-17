/// eBadge 设备通讯协议 V1.3 —— 纯编解码层。
///
/// 依据 `D:\DocDev\ebadge\新帕元\eBadge设备通讯协议_v1.3.md`(文档编号
/// eBadge-PROT-001,V1.3 定稿)。
///
/// **V1.2 → V1.3 的两处不兼容改动**,升级固件/App 时必须同步,否则症状很隐蔽:
///
/// 1. §2.5 通用结果码 **0x00 与 0x01 对调**:V1.2 是 0=失败 1=成功,V1.3 改成
///    0=成功 1=失败,并新增 0x02 未就绪 / 0x03 忙。方向搞反的表现是「成功显示
///    为失败」,而不是报错,所以读 V1.2 时期的旧日志要按旧含义解释。
/// 2. §4.7(原 §4.5)传图交互:设备**不再弹窗等用户点**,而是自查存储/内存/忙
///    后自动回 0x11 同意或拒绝。「App 必须先 0x19 GET_STORAGE」从硬性前置降级
///    为建议(设备侧自己会复检)。
///
/// V1.3 另新增 §6 同屏预览:0x08/0x09 命令 + 14 字节流帧头(见
/// [EBadgeStreamHeader])。它与 §5 壁纸传图共用 'EBXF' magic,仅靠头长和会话
/// 类型区分。
///
/// **本文件与现有 HoneyBox L1/L2 协议栈完全解耦**,这不是洁癖而是必需 ——
/// 两套协议在字节层根本不兼容:
///
/// | 项      | HoneyBox (l1_engine / ble_cmd_registry) | eBadge (本文件)          |
/// | ------- | --------------------------------------- | ------------------------ |
/// | GATT    | FFC1 write / FFC2 notify                | f48affc1 / f48affc2      |
/// | 字节序  | 大端 (BE)                               | **小端 (LE)**            |
/// | 分层    | L1 (CRC + ACK + seq) 包裹 L2            | **无 L1**,裸帧直写       |
/// | 帧头    | `[cmd, 0x00, key, vlen_hi, vlen_lo]`    | `[ver, cmd, 0x80, len_lo, len_hi]` |
/// | TLV len | 无(key 定长语义)                      | uint16 LE                |
///
/// 因此 eBadge 的 cmd 字节**不进** `BleCmd` 中心表:那张表的前提是「CMD 值
/// 在 HoneyBox 协议内全局唯一」,而 eBadge 的 0x02/0x03/0x10 等与 HoneyBox 的
/// watchTime/watchBind/fileTransfer 数值相撞。两者跑在不同 service 上,是两个
/// 独立命名空间,混进同一张表只会制造假冲突。
///
/// 纯函数 + 常量,不含任何 BLE 依赖,可直接单测(见
/// `test/services/ebadge_protocol_test.dart`)。
library;

import 'dart:convert';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// GATT (§2.2)
// ---------------------------------------------------------------------------

/// eBadge 私有服务与收发特征。注意 RX/TX 是**站在设备视角**命名的(协议原文
/// 如此):RX 是设备的接收端 = app 要写的那根;TX 是设备的发送端 = app 订阅
/// notify 的那根。
class EBadgeGatt {
  EBadgeGatt._();

  static const String service = 'f48affc0-f69a-11e8-8eb2-f2801f1b9fd1';

  /// H→D:app 写入(Write / Write Without Response)。
  static const String rxWrite = 'f48affc1-f69a-11e8-8eb2-f2801f1b9fd1';

  /// D→H:app 订阅 notify。连接后**必须**使能(§2.2 CCC 一行)。
  static const String txNotify = 'f48affc2-f69a-11e8-8eb2-f2801f1b9fd1';
}

// ---------------------------------------------------------------------------
// 帧结构常量 (§2.3)
// ---------------------------------------------------------------------------

/// 协议版本字节。§4.1 释义把该字节写成 "svc=01",与 §2.3 的字段表(ver)
/// 冲突;此处依 §2.3 的正式字段表取 ver。两种叫法在线缆上都是同一个 0x01。
const int kEBadgeVersion = 0x01;

/// 帧头第 3 字节固定量 TLV_PARAMS_LENGTH。它只是「随后 2 字节为参数区长度」
/// 的标记,**本身不算参数区内的业务 TLV**(§2.3 注意条)。
const int kEBadgeParamsLengthMarker = 0x80;

/// 帧头长度:ver(1) + cmd(1) + 0x80(1) + params_len(2)。
const int kEBadgeHeaderLength = 5;

// ---------------------------------------------------------------------------
// 命令表 (§3)
// ---------------------------------------------------------------------------

/// eBadge 命令字节。`h2d` = App 写 RX,`d2h` = 设备 TX Notify。
class EBadgeCmd {
  EBadgeCmd._();

  static const int h2dSetTime = 0x01;
  static const int h2dSendFile = 0x02;
  static const int h2dSendMsg = 0x03;
  static const int d2hResult = 0x04;

  /// 0x08/0x09:V1.3 新增的同屏预览(JPEG 流)握手,见 §4.5 / §4.6 / §6。
  static const int h2dJpgStreamOffer = 0x08;
  static const int d2hJpgStreamDecision = 0x09;

  static const int h2dTransferOffer = 0x10;
  static const int d2hTransferDecision = 0x11;
  static const int h2dGetApInfo = 0x12;
  static const int d2hApInfo = 0x13;
  static const int d2hTransferProgress = 0x14;
  static const int d2hTransferDone = 0x15;
  static const int d2hTransferFail = 0x16;
  static const int h2dGetBattery = 0x17;
  static const int d2hBattery = 0x18;
  static const int h2dGetStorage = 0x19;
  static const int d2hStorageInfo = 0x1A;

  /// 0x05–0x07、0x0A–0x0F、0x1B–0x2F 为协议保留段,未定义前禁止使用(§3 末行)。
  /// V1.2 的保留段是连续的 0x05–0x0F,V1.3 从中挖走 0x08/0x09 给同屏预览。
  static bool isReserved(int cmd) =>
      (cmd >= 0x05 && cmd <= 0x07) ||
      (cmd >= 0x0A && cmd <= 0x0F) ||
      (cmd >= 0x1B && cmd <= 0x2F);

  static String name(int cmd) => switch (cmd) {
        h2dSetTime => 'SET_TIME',
        h2dSendFile => 'SEND_FILE',
        h2dSendMsg => 'SEND_MSG',
        d2hResult => 'RESULT',
        h2dJpgStreamOffer => 'JPG_STREAM_OFFER',
        d2hJpgStreamDecision => 'JPG_STREAM_DECISION',
        h2dTransferOffer => 'TRANSFER_OFFER',
        d2hTransferDecision => 'TRANSFER_DECISION',
        h2dGetApInfo => 'GET_AP_INFO',
        d2hApInfo => 'AP_INFO',
        d2hTransferProgress => 'TRANSFER_PROGRESS',
        d2hTransferDone => 'TRANSFER_DONE',
        d2hTransferFail => 'TRANSFER_FAIL',
        h2dGetBattery => 'GET_BATTERY',
        d2hBattery => 'BATTERY',
        h2dGetStorage => 'GET_STORAGE',
        d2hStorageInfo => 'STORAGE_INFO',
        _ => isReserved(cmd) ? 'RESERVED' : 'UNKNOWN',
      };
}

// ---------------------------------------------------------------------------
// TLV type 表 —— 按命令上下文分组
// ---------------------------------------------------------------------------
//
// §2.4 明确:type 在**该命令上下文**内解释,不同命令可复用相同 type 号。
// 所以这里刻意按命令分类,不做全局 type 表 —— 全局表会把「0x01 在 SET_TIME
// 是日期、在 BATTERY 是电量百分比」这件事抹平,是错误建模。

/// 0x01 SET_TIME (§4.1)
abstract class EBadgeTlvSetTime {
  static const int dateTime = 0x01; // len=8, vs_date_time
}

/// 0x02 SEND_FILE (§4.2)
abstract class EBadgeTlvSendFile {
  static const int fileName = 0x01;
  static const int fileType = 0x02;
  static const int fileDate = 0x03;
  static const int fileLength = 0x04; // uint32 LE
}

/// 0x03 SEND_MSG (§4.3)
abstract class EBadgeTlvSendMsg {
  static const int appName = 0x01;
  static const int title = 0x02;
  static const int text = 0x03;
  static const int date = 0x04;
}

/// 0x04 RESULT (§4.4)
abstract class EBadgeTlvResult {
  static const int resultCmd = 0x01; // 原 cmd_id
  static const int resultCode = 0x02; // §2.5
}

/// 0x08 JPG_STREAM_OFFER (§4.5,V1.3 新增)
abstract class EBadgeTlvStreamOffer {
  static const int name = 0x01; // 必选,文件名 ≤23B
  static const int type = 0x02; // 必选,§2.7,不得为 0x00(同屏用 0x04)
  static const int fps = 0x03; // 必选,uint8 传输帧率
}

/// 0x09 JPG_STREAM_DECISION (§4.6,V1.3 新增)
abstract class EBadgeTlvStreamDecision {
  static const int decision = 0x01; // 0拒绝 1同意 2协商
  static const int reason = 0x02; // 可选,§2.6
  static const int fps = 0x03; // 可选,uint8 协商后的帧率
}

/// 0x10 TRANSFER_OFFER (§4.7)
abstract class EBadgeTlvOffer {
  static const int name = 0x01; // 必选
  static const int type = 0x02; // 必选,不得为 0x00
  static const int size = 0x03; // 必选,uint32 LE
  static const int crc32 = 0x04; // 必选,uint32 LE,对整个文件正文
  static const int replaceId = 0x05; // 可选,uint16 LE
}

/// 0x11 TRANSFER_DECISION (§4.8)
abstract class EBadgeTlvDecision {
  static const int decision = 0x01; // 0拒绝 1同意 2超时
  static const int reason = 0x02; // §2.6
}

/// 0x13 AP_INFO (§4.9)
abstract class EBadgeTlvApInfo {
  static const int ssid = 0x01;
  static const int password = 0x02; // 开放网络则 length=0
  static const int channel = 0x03; // uint8 1–13
  static const int ipv4 = 0x04; // 4B
  static const int port = 0x05; // uint16 LE
  static const int proto = 0x06; // 0x01 = 裸 TCP(唯一合法值)
  static const int security = 0x07; // 0=Open 1=WPA2-PSK
}

/// 0x14 TRANSFER_PROGRESS (§4.10)
abstract class EBadgeTlvProgress {
  static const int recv = 0x01; // uint32 LE
  static const int total = 0x02; // uint32 LE
}

/// 0x15 TRANSFER_DONE (§4.11)
abstract class EBadgeTlvDone {
  static const int fileId = 0x01; // uint16 LE,非 0
  static const int size = 0x02; // uint32 LE
  static const int name = 0x03; // 设备侧最终文件名
}

/// 0x16 TRANSFER_FAIL (§4.12)
abstract class EBadgeTlvFail {
  static const int reason = 0x01; // §2.6
  static const int detail = 0x02; // 可选,≤23B
}

/// 0x18 BATTERY (§4.13)
abstract class EBadgeTlvBattery {
  static const int percent = 0x01; // uint8 0..100
  static const int charge = 0x02; // 0未充 1充电中 2已满
}

/// 0x1A STORAGE_INFO (§4.14)
abstract class EBadgeTlvStorage {
  static const int total = 0x01; // uint64 LE
  static const int free = 0x02; // uint64 LE
  static const int wpCount = 0x03; // uint16 LE
  static const int wpUsed = 0x04; // uint64 LE
  static const int fsMargin = 0x05; // uint32 LE,固定回 4096
}

// ---------------------------------------------------------------------------
// 枚举与码表
// ---------------------------------------------------------------------------

/// §2.5 通用结果码(0x04 RESULT 使用)。
///
/// **V1.3 把 0x00 / 0x01 的含义对调了**:V1.2 是 0x00=FAILED、0x01=SUCCEED,
/// V1.3 改成 0x00=SUCCEED、0x01=FAILED(回到「0 表示 OK」的常规直觉),并新增
/// 0x02 未就绪、0x03 忙。这条改动**没写进修订记录**,但两份文档的 §2.5 表格
/// 确实相反 —— 以 V1.3 为准。
///
/// 读 V1.2 时期抓下来的旧日志时要按旧含义反着解释:方向错了的表现是「成功被
/// 显示为失败」,不会报任何错。
abstract class EBadgeResultCode {
  static const int succeed = 0x00;
  static const int failed = 0x01;
  static const int notReady = 0x02;
  static const int busy = 0x03;

  static String name(int v) => switch (v) {
        succeed => 'SUCCEED',
        failed => 'FAILED',
        notReady => 'NOT_READY',
        busy => 'BUSY',
        _ => 'UNKNOWN(0x${v.toRadixString(16)})',
      };
}

/// §2.6 传图错误码(decision reason / fail reason)。
abstract class EBadgeXferError {
  static const int userReject = 0x01;
  static const int userTimeout = 0x02;
  static const int storageFull = 0x03;
  static const int fmtUnsupported = 0x04;
  static const int tooLarge = 0x05;
  static const int apStart = 0x06;
  static const int staTimeout = 0x07;
  static const int ioTimeout = 0x08;
  static const int verify = 0x09;
  static const int busy = 0x0A;
  static const int cancelled = 0x0B;

  static String name(int v) => switch (v) {
        userReject => 'USER_REJECT',
        userTimeout => 'USER_TIMEOUT',
        storageFull => 'STORAGE_FULL',
        fmtUnsupported => 'FMT_UNSUPPORTED',
        tooLarge => 'TOO_LARGE',
        apStart => 'AP_START',
        staTimeout => 'STA_TIMEOUT',
        ioTimeout => 'IO_TIMEOUT',
        verify => 'VERIFY',
        busy => 'BUSY',
        cancelled => 'CANCELLED',
        _ => 'UNKNOWN(0x${v.toRadixString(16)})',
      };
}

/// §2.7 文件类型枚举。
abstract class EBadgeFileType {
  static const int unspecified = 0x00; // Offer 不得使用
  static const int jpeg = 0x01;
  static const int png = 0x02;
  static const int gif = 0x03;
  static const int jpegStream = 0x04;
  static const int video = 0x05;
  static const int bin = 0x06;
  static const int text = 0x07;

  static String name(int v) => switch (v) {
        unspecified => 'UNSPECIFIED',
        jpeg => 'JPEG',
        png => 'PNG',
        gif => 'GIF',
        jpegStream => 'JPEG_STREAM',
        video => 'VIDEO',
        bin => 'BIN',
        text => 'TEXT',
        _ => 'UNKNOWN(0x${v.toRadixString(16)})',
      };
}

/// decision 取值。0x11 传图确认(§4.8)与 0x09 同屏确认(§4.6)共用 0/1/2 三个
/// 值,但 **2 的含义按命令不同**:0x11 是「超时」,0x09 是「协商」(设备接受但
/// 要改帧率,新帧率在 TLV 0x03)。所以名字用 [name] 时要带上命令上下文,见
/// [nameForStream]。
abstract class EBadgeDecision {
  static const int reject = 0;
  static const int accept = 1;
  static const int timeout = 2;

  /// 0x09 语境下 2 叫「协商」,和 [timeout] 是同一个字节值。
  static const int negotiate = 2;

  static String name(int v) => switch (v) {
        reject => 'REJECT',
        accept => 'ACCEPT',
        timeout => 'TIMEOUT',
        _ => 'UNKNOWN($v)',
      };

  static String nameForStream(int v) => switch (v) {
        reject => 'REJECT',
        accept => 'ACCEPT',
        negotiate => 'NEGOTIATE',
        _ => 'UNKNOWN($v)',
      };
}

/// 0x18 charge 取值(§4.13)。
abstract class EBadgeChargeState {
  static const int notCharging = 0;
  static const int charging = 1;
  static const int full = 2;

  static String name(int v) => switch (v) {
        notCharging => 'NOT_CHARGING',
        charging => 'CHARGING',
        full => 'FULL',
        _ => 'UNKNOWN($v)',
      };
}

/// §2.8 长度上限。超限即协议违规,builder 会抛 [ArgumentError]。
abstract class EBadgeLimits {
  static const int fileName = 23;
  static const int dateString = 23;
  static const int msgField = 23;
  static const int apSsid = 32;
  static const int apPassword = 63;
  static const int failDetail = 23;

  /// §2.9 文件系统元数据余量,定稿固定值。
  static const int fsMargin = 4096;
}

// ---------------------------------------------------------------------------
// TLV
// ---------------------------------------------------------------------------

/// 一条业务 TLV:`type(1) + length(uint16 LE) + value(length)`(§2.4)。
class EBadgeTlv {
  const EBadgeTlv(this.type, this.value);

  final int type;
  final Uint8List value;

  /// 编码后的总字节数(含 3 字节 type+length 头)。
  int get encodedLength => 3 + value.length;

  @override
  String toString() =>
      'TLV(0x${type.toRadixString(16).padLeft(2, '0')}, ${value.length}B)';
}

// ---------------------------------------------------------------------------
// 解析结果
// ---------------------------------------------------------------------------

/// 解析成功的一帧控制 PDU。
class EBadgeFrame {
  EBadgeFrame({
    required this.ver,
    required this.cmd,
    required this.params,
    required this.tlvs,
    required this.raw,
  });

  final int ver;
  final int cmd;

  /// 参数区原始字节(不含 5 字节帧头)。
  final Uint8List params;

  /// 顺序解出的业务 TLV。允许重复 type —— 协议没禁止,原样保留由调用方决定。
  final List<EBadgeTlv> tlvs;

  /// 整帧原始字节,供日志十六进制回显。
  final Uint8List raw;

  String get cmdName => EBadgeCmd.name(cmd);

  /// 取第一条 type 匹配的 TLV,没有则 null。
  Uint8List? value(int type) {
    for (final t in tlvs) {
      if (t.type == type) return t.value;
    }
    return null;
  }

  @override
  String toString() => 'EBadgeFrame(ver=$ver, cmd=0x'
      '${cmd.toRadixString(16).padLeft(2, '0')} $cmdName, ${tlvs.length} TLV)';
}

/// 帧解析失败原因 —— 调试页要区分「还没收够」和「真的坏了」:前者继续等,
/// 后者要在日志里红字告警。
enum EBadgeParseError {
  /// 字节数不足一个完整帧,继续等后续 notify。
  incomplete,

  /// ver 不是 0x01。
  badVersion,

  /// 帧头第 3 字节不是 0x80。
  badMarker,

  /// 某条 TLV 的 length 越过了参数区边界。
  tlvOverflow,
}

/// [EBadgeCodec.decode] 的返回:要么拿到帧,要么给出原因。
class EBadgeDecodeResult {
  const EBadgeDecodeResult.ok(this.frame, this.consumed) : error = null;
  const EBadgeDecodeResult.fail(this.error, this.consumed) : frame = null;

  final EBadgeFrame? frame;
  final EBadgeParseError? error;

  /// 本次从缓冲区消耗掉的字节数。[EBadgeParseError.incomplete] 时为 0。
  final int consumed;

  bool get isOk => frame != null;
}

// ---------------------------------------------------------------------------
// 编解码核心
// ---------------------------------------------------------------------------

/// 帧与 TLV 的编解码。所有多字节整数一律小端(§2.1)。
class EBadgeCodec {
  EBadgeCodec._();

  // ── 小端读写原语 ────────────────────────────────────────────────────

  static Uint8List u8(int v) => Uint8List.fromList([v & 0xFF]);

  static Uint8List u16le(int v) =>
      Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF]);

  static Uint8List u32le(int v) => Uint8List.fromList([
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ]);

  /// uint64 LE。Dart 的 int 是 64 位有符号,协议里的容量字段实际远小于
  /// 2^63,所以直接位移安全。
  static Uint8List u64le(int v) => Uint8List.fromList([
        for (var i = 0; i < 8; i++) (v >> (8 * i)) & 0xFF,
      ]);

  static int readU16le(Uint8List b, [int o = 0]) => b[o] | (b[o + 1] << 8);

  static int readU32le(Uint8List b, [int o = 0]) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  static int readU64le(Uint8List b, [int o = 0]) {
    var v = 0;
    for (var i = 7; i >= 0; i--) {
      v = (v << 8) | b[o + i];
    }
    return v;
  }

  /// UTF-8 编码并校验长度上限。length 按**字节数**算(§2.1),中文一个字 3B,
  /// 所以 23B 上限对中文只有 7 个字 —— 这里如实按字节拦截,不做静默截断:
  /// 截断会让设备端收到半个 UTF-8 序列。
  static Uint8List str(String s, int maxBytes, String field) {
    final bytes = Uint8List.fromList(utf8.encode(s));
    if (bytes.length > maxBytes) {
      throw ArgumentError.value(
        s,
        field,
        '${bytes.length} 字节超过协议上限 $maxBytes 字节(UTF-8 按字节计)',
      );
    }
    return bytes;
  }

  // ── 帧编码 ──────────────────────────────────────────────────────────

  /// 按 §2.3 拼一帧:`[ver, cmd, 0x80, params_len LE] + 顺序拼接的 TLV`。
  static Uint8List encode(int cmd, List<EBadgeTlv> tlvs) {
    var paramsLen = 0;
    for (final t in tlvs) {
      paramsLen += t.encodedLength;
    }
    if (paramsLen > 0xFFFF) {
      throw ArgumentError.value(
        paramsLen,
        'paramsLen',
        'params_len 是 uint16,最大 65535',
      );
    }

    final out = Uint8List(kEBadgeHeaderLength + paramsLen);
    out[0] = kEBadgeVersion;
    out[1] = cmd & 0xFF;
    out[2] = kEBadgeParamsLengthMarker;
    out[3] = paramsLen & 0xFF;
    out[4] = (paramsLen >> 8) & 0xFF;

    var o = kEBadgeHeaderLength;
    for (final t in tlvs) {
      out[o++] = t.type & 0xFF;
      out[o++] = t.value.length & 0xFF;
      out[o++] = (t.value.length >> 8) & 0xFF;
      out.setRange(o, o + t.value.length, t.value);
      o += t.value.length;
    }
    return out;
  }

  // ── 帧解码 ──────────────────────────────────────────────────────────

  /// 从 [buf] 起始处尝试解出一帧。
  ///
  /// 未识别的 TLV **不**导致失败 —— §2.1 要求接收方按 length 跳过。这里的做法
  /// 是原样收进 [EBadgeFrame.tlvs],让上层(调试页)照样能十六进制显示出来:
  /// 对协议调试而言,「设备发了一条我不认识的 TLV」正是最该看见的信息。
  static EBadgeDecodeResult decode(Uint8List buf) {
    if (buf.length < kEBadgeHeaderLength) {
      return const EBadgeDecodeResult.fail(EBadgeParseError.incomplete, 0);
    }
    if (buf[0] != kEBadgeVersion) {
      // 丢 1 字节重新找同步 —— 比整段丢弃更容错。
      return const EBadgeDecodeResult.fail(EBadgeParseError.badVersion, 1);
    }
    if (buf[2] != kEBadgeParamsLengthMarker) {
      return const EBadgeDecodeResult.fail(EBadgeParseError.badMarker, 1);
    }

    final paramsLen = buf[3] | (buf[4] << 8);
    final total = kEBadgeHeaderLength + paramsLen;
    if (buf.length < total) {
      return const EBadgeDecodeResult.fail(EBadgeParseError.incomplete, 0);
    }

    final params = Uint8List.sublistView(buf, kEBadgeHeaderLength, total);
    final tlvs = <EBadgeTlv>[];
    var o = 0;
    while (o < params.length) {
      // type(1) + length(2) 至少 3 字节
      if (o + 3 > params.length) {
        return EBadgeDecodeResult.fail(EBadgeParseError.tlvOverflow, total);
      }
      final type = params[o];
      final len = params[o + 1] | (params[o + 2] << 8);
      if (o + 3 + len > params.length) {
        return EBadgeDecodeResult.fail(EBadgeParseError.tlvOverflow, total);
      }
      tlvs.add(EBadgeTlv(
        type,
        Uint8List.fromList(
          Uint8List.sublistView(params, o + 3, o + 3 + len),
        ),
      ));
      o += 3 + len;
    }

    return EBadgeDecodeResult.ok(
      EBadgeFrame(
        ver: buf[0],
        cmd: buf[1],
        params: Uint8List.fromList(params),
        tlvs: tlvs,
        raw: Uint8List.fromList(Uint8List.sublistView(buf, 0, total)),
      ),
      total,
    );
  }

  /// 十六进制回显,大写空格分隔 —— 与协议文档示例排版一致,方便肉眼对照。
  static String hex(Uint8List b, {int? max}) {
    final limit = max ?? b.length;
    final shown = b.length <= limit ? b : Uint8List.sublistView(b, 0, limit);
    final s = shown
        .map((x) => x.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(' ');
    return b.length <= limit ? s : '$s … (共 ${b.length}B)';
  }
}

// ---------------------------------------------------------------------------
// H→D 组包器
// ---------------------------------------------------------------------------

/// App → 设备 的命令组包。每个方法返回可直接写入 [EBadgeGatt.rxWrite] 的整帧。
class EBadgeRequest {
  EBadgeRequest._();

  /// 0x01 SET_TIME(§4.1)。
  ///
  /// [when] 的星期按协议重映射:协议要 **1=周一 … 7=周日**,而 Dart 的
  /// `DateTime.weekday` 恰好也是 1=Monday…7=Sunday,所以可直接用 —— 但这份
  /// 巧合值得写下来,免得日后有人"顺手改成 `weekday % 7`"而引入错位。
  static Uint8List setTime(DateTime when) {
    if (when.year < 1582 || when.year > 9999) {
      throw ArgumentError.value(when.year, 'year', '协议范围 1582–9999');
    }
    final v = Uint8List(8);
    v[0] = when.year & 0xFF;
    v[1] = (when.year >> 8) & 0xFF;
    v[2] = when.month;
    v[3] = when.day;
    v[4] = when.hour;
    v[5] = when.minute;
    v[6] = when.second;
    v[7] = when.weekday; // 1=周一 … 7=周日
    return EBadgeCodec.encode(
      EBadgeCmd.h2dSetTime,
      [EBadgeTlv(EBadgeTlvSetTime.dateTime, v)],
    );
  }

  /// 0x02 SEND_FILE 的**元数据帧**(§4.2)。
  ///
  /// 正文不在这里 —— 协议要求元数据 TLV 之后,在**同一 BLE RX 流**紧跟
  /// `fileLength` 字节裸正文。调用方发完本帧再把正文写过去。
  /// 仅供调试 / 小配置文件;壁纸大图禁走此路(§4.2 用途栏)。
  static Uint8List sendFileMeta({
    required String name,
    required int type,
    required int length,
    String? date,
  }) {
    return EBadgeCodec.encode(EBadgeCmd.h2dSendFile, [
      EBadgeTlv(EBadgeTlvSendFile.fileName,
          EBadgeCodec.str(name, EBadgeLimits.fileName, 'name')),
      EBadgeTlv(EBadgeTlvSendFile.fileType, EBadgeCodec.u8(type)),
      if (date != null)
        EBadgeTlv(EBadgeTlvSendFile.fileDate,
            EBadgeCodec.str(date, EBadgeLimits.dateString, 'date')),
      EBadgeTlv(EBadgeTlvSendFile.fileLength, EBadgeCodec.u32le(length)),
    ]);
  }

  /// 0x03 SEND_MSG(§4.3)。
  static Uint8List sendMsg({
    required String appName,
    required String title,
    required String text,
    String? date,
  }) {
    return EBadgeCodec.encode(EBadgeCmd.h2dSendMsg, [
      EBadgeTlv(EBadgeTlvSendMsg.appName,
          EBadgeCodec.str(appName, EBadgeLimits.msgField, 'appName')),
      EBadgeTlv(EBadgeTlvSendMsg.title,
          EBadgeCodec.str(title, EBadgeLimits.msgField, 'title')),
      EBadgeTlv(EBadgeTlvSendMsg.text,
          EBadgeCodec.str(text, EBadgeLimits.msgField, 'text')),
      if (date != null)
        EBadgeTlv(EBadgeTlvSendMsg.date,
            EBadgeCodec.str(date, EBadgeLimits.msgField, 'date')),
    ]);
  }

  /// 0x08 JPG_STREAM_OFFER(§4.5,V1.3 新增)—— 同屏预览握手。
  ///
  /// 与 0x10 TRANSFER_OFFER 的关键差别:**不带 size / crc32**。同屏是持续推多
  /// 帧,总长在握手时根本不存在;每帧自己的长度和校验放在 §6.2 的 14 字节流头里
  /// (见 [EBadgeStreamHeader])。
  ///
  /// [fps] 是期望帧率,设备可以回 decision=2(协商)带一个更低的值。
  static Uint8List jpgStreamOffer({
    required String name,
    int type = EBadgeFileType.jpegStream,
    required int fps,
  }) {
    if (type == EBadgeFileType.unspecified) {
      throw ArgumentError.value(type, 'type', 'Offer 的 file_type 不得为 0x00');
    }
    if (fps < 1 || fps > 0xFF) {
      throw ArgumentError.value(fps, 'fps', 'fps 是 uint8,取值 1–255');
    }
    return EBadgeCodec.encode(EBadgeCmd.h2dJpgStreamOffer, [
      EBadgeTlv(EBadgeTlvStreamOffer.name,
          EBadgeCodec.str(name, EBadgeLimits.fileName, 'name')),
      EBadgeTlv(EBadgeTlvStreamOffer.type, EBadgeCodec.u8(type)),
      EBadgeTlv(EBadgeTlvStreamOffer.fps, EBadgeCodec.u8(fps)),
    ]);
  }

  /// 0x10 TRANSFER_OFFER(§4.7)。
  ///
  /// V1.3 起「必须先 0x19 GET_STORAGE」不再是硬性前置 —— 设备收到 Offer 会自己
  /// 复检 `free_bytes >= size + 4096`(§2.9),不够就直接回 0x16 STORAGE_FULL。
  /// App 侧先查一次仍然值得做:能在发包前就给出「空间不足」的提示,省掉一轮
  /// BLE 往返。本函数只拦 [type] == 0x00 这条协议硬约束。
  static Uint8List transferOffer({
    required String name,
    required int type,
    required int size,
    required int crc32,
    int? replaceId,
  }) {
    if (type == EBadgeFileType.unspecified) {
      throw ArgumentError.value(type, 'type', 'Offer 的 file_type 不得为 0x00');
    }
    return EBadgeCodec.encode(EBadgeCmd.h2dTransferOffer, [
      EBadgeTlv(EBadgeTlvOffer.name,
          EBadgeCodec.str(name, EBadgeLimits.fileName, 'name')),
      EBadgeTlv(EBadgeTlvOffer.type, EBadgeCodec.u8(type)),
      EBadgeTlv(EBadgeTlvOffer.size, EBadgeCodec.u32le(size)),
      EBadgeTlv(EBadgeTlvOffer.crc32, EBadgeCodec.u32le(crc32)),
      if (replaceId != null)
        EBadgeTlv(EBadgeTlvOffer.replaceId, EBadgeCodec.u16le(replaceId)),
    ]);
  }

  /// 0x12 GET_AP_INFO(§4.9)—— 无业务参数,params_len=0。
  static Uint8List getApInfo() =>
      EBadgeCodec.encode(EBadgeCmd.h2dGetApInfo, const []);

  /// 0x17 GET_BATTERY(§4.13)—— 无参数。
  static Uint8List getBattery() =>
      EBadgeCodec.encode(EBadgeCmd.h2dGetBattery, const []);

  /// 0x19 GET_STORAGE(§4.14)—— 无参数。
  static Uint8List getStorage() =>
      EBadgeCodec.encode(EBadgeCmd.h2dGetStorage, const []);
}

// ---------------------------------------------------------------------------
// D→H 解包器
// ---------------------------------------------------------------------------

/// 0x04 RESULT
class EBadgeResult {
  const EBadgeResult({required this.cmd, required this.code});
  final int cmd;
  final int code;

  bool get succeed => code == EBadgeResultCode.succeed;

  static EBadgeResult? parse(EBadgeFrame f) {
    final c = f.value(EBadgeTlvResult.resultCmd);
    final r = f.value(EBadgeTlvResult.resultCode);
    if (c == null || c.isEmpty || r == null || r.isEmpty) return null;
    return EBadgeResult(cmd: c[0], code: r[0]);
  }
}

/// 0x11 TRANSFER_DECISION
class EBadgeTransferDecision {
  const EBadgeTransferDecision({required this.decision, this.reason});
  final int decision;
  final int? reason;

  bool get accepted => decision == EBadgeDecision.accept;

  static EBadgeTransferDecision? parse(EBadgeFrame f) {
    final d = f.value(EBadgeTlvDecision.decision);
    if (d == null || d.isEmpty) return null;
    final r = f.value(EBadgeTlvDecision.reason);
    return EBadgeTransferDecision(
      decision: d[0],
      reason: (r != null && r.isNotEmpty) ? r[0] : null,
    );
  }
}

/// 0x09 JPG_STREAM_DECISION(§4.6,V1.3 新增)
///
/// 与 [EBadgeTransferDecision] 分开建模而不加个字段复用:两者的 decision=2
/// 含义不同(这里是协商、那里是超时),而且本命令多一个协商帧率。塞进同一个类
/// 会逼调用方每次都判断「我这条是哪个 cmd 来的」。
class EBadgeStreamDecision {
  const EBadgeStreamDecision({required this.decision, this.reason, this.fps});

  final int decision;
  final int? reason;

  /// 设备协商后的帧率。decision=2 时必看;decision=1 时设备也可以带上,表示
  /// 「同意,并且就按这个帧率来」。
  final int? fps;

  bool get accepted => decision == EBadgeDecision.accept;
  bool get negotiated => decision == EBadgeDecision.negotiate;

  /// 实际该用的帧率:设备给了就听设备的,没给就沿用 [requested]。
  int effectiveFps(int requested) => fps ?? requested;

  static EBadgeStreamDecision? parse(EBadgeFrame f) {
    final d = f.value(EBadgeTlvStreamDecision.decision);
    if (d == null || d.isEmpty) return null;
    final r = f.value(EBadgeTlvStreamDecision.reason);
    final p = f.value(EBadgeTlvStreamDecision.fps);
    return EBadgeStreamDecision(
      decision: d[0],
      reason: (r != null && r.isNotEmpty) ? r[0] : null,
      fps: (p != null && p.isNotEmpty) ? p[0] : null,
    );
  }
}

/// 0x13 AP_INFO
class EBadgeApInfo {
  const EBadgeApInfo({
    required this.ssid,
    required this.password,
    required this.channel,
    required this.ipv4,
    required this.port,
    required this.proto,
    required this.security,
  });

  final String ssid;
  final String password;
  final int channel;
  final String ipv4;
  final int port;
  final int proto;
  final int security;

  bool get isOpen => security == 0;

  static EBadgeApInfo? parse(EBadgeFrame f) {
    final ssid = f.value(EBadgeTlvApInfo.ssid);
    final pwd = f.value(EBadgeTlvApInfo.password);
    final ch = f.value(EBadgeTlvApInfo.channel);
    final ip = f.value(EBadgeTlvApInfo.ipv4);
    final port = f.value(EBadgeTlvApInfo.port);
    final proto = f.value(EBadgeTlvApInfo.proto);
    final sec = f.value(EBadgeTlvApInfo.security);
    if (ssid == null ||
        pwd == null ||
        ch == null ||
        ch.isEmpty ||
        ip == null ||
        ip.length < 4 ||
        port == null ||
        port.length < 2 ||
        proto == null ||
        proto.isEmpty ||
        sec == null ||
        sec.isEmpty) {
      return null;
    }
    return EBadgeApInfo(
      ssid: utf8.decode(ssid, allowMalformed: true),
      password: utf8.decode(pwd, allowMalformed: true),
      channel: ch[0],
      ipv4: '${ip[0]}.${ip[1]}.${ip[2]}.${ip[3]}',
      port: EBadgeCodec.readU16le(port),
      proto: proto[0],
      security: sec[0],
    );
  }
}

/// 0x14 TRANSFER_PROGRESS
class EBadgeProgress {
  const EBadgeProgress({required this.recv, required this.total});
  final int recv;
  final int total;

  double get fraction => total == 0 ? 0 : recv / total;

  static EBadgeProgress? parse(EBadgeFrame f) {
    final r = f.value(EBadgeTlvProgress.recv);
    final t = f.value(EBadgeTlvProgress.total);
    if (r == null || r.length < 4 || t == null || t.length < 4) return null;
    return EBadgeProgress(
      recv: EBadgeCodec.readU32le(r),
      total: EBadgeCodec.readU32le(t),
    );
  }
}

/// 0x15 TRANSFER_DONE
class EBadgeTransferDone {
  const EBadgeTransferDone({
    required this.fileId,
    required this.size,
    required this.name,
  });
  final int fileId;
  final int size;
  final String name;

  static EBadgeTransferDone? parse(EBadgeFrame f) {
    final id = f.value(EBadgeTlvDone.fileId);
    final sz = f.value(EBadgeTlvDone.size);
    final nm = f.value(EBadgeTlvDone.name);
    if (id == null || id.length < 2 || sz == null || sz.length < 4) return null;
    return EBadgeTransferDone(
      fileId: EBadgeCodec.readU16le(id),
      size: EBadgeCodec.readU32le(sz),
      name: nm == null ? '' : utf8.decode(nm, allowMalformed: true),
    );
  }
}

/// 0x16 TRANSFER_FAIL
class EBadgeTransferFail {
  const EBadgeTransferFail({required this.reason, this.detail});
  final int reason;
  final String? detail;

  static EBadgeTransferFail? parse(EBadgeFrame f) {
    final r = f.value(EBadgeTlvFail.reason);
    if (r == null || r.isEmpty) return null;
    final d = f.value(EBadgeTlvFail.detail);
    return EBadgeTransferFail(
      reason: r[0],
      detail: d == null ? null : utf8.decode(d, allowMalformed: true),
    );
  }
}

/// 0x18 BATTERY
class EBadgeBattery {
  const EBadgeBattery({required this.percent, required this.charge});
  final int percent;
  final int charge;

  static EBadgeBattery? parse(EBadgeFrame f) {
    final p = f.value(EBadgeTlvBattery.percent);
    final c = f.value(EBadgeTlvBattery.charge);
    if (p == null || p.isEmpty || c == null || c.isEmpty) return null;
    return EBadgeBattery(percent: p[0], charge: c[0]);
  }
}

/// 0x1A STORAGE_INFO
class EBadgeStorageInfo {
  const EBadgeStorageInfo({
    required this.total,
    required this.free,
    required this.wpCount,
    required this.wpUsed,
    required this.fsMargin,
  });

  final int total;
  final int free;
  final int wpCount;
  final int wpUsed;
  final int fsMargin;

  /// §4.14 定稿判定:`free < need + margin` 即禁止发起 Offer。
  bool canFit(int needBytes) => free >= needBytes + fsMargin;

  static EBadgeStorageInfo? parse(EBadgeFrame f) {
    final t = f.value(EBadgeTlvStorage.total);
    final fr = f.value(EBadgeTlvStorage.free);
    final c = f.value(EBadgeTlvStorage.wpCount);
    final u = f.value(EBadgeTlvStorage.wpUsed);
    final m = f.value(EBadgeTlvStorage.fsMargin);
    if (t == null ||
        t.length < 8 ||
        fr == null ||
        fr.length < 8 ||
        c == null ||
        c.length < 2 ||
        u == null ||
        u.length < 8 ||
        m == null ||
        m.length < 4) {
      return null;
    }
    return EBadgeStorageInfo(
      total: EBadgeCodec.readU64le(t),
      free: EBadgeCodec.readU64le(fr),
      wpCount: EBadgeCodec.readU16le(c),
      wpUsed: EBadgeCodec.readU64le(u),
      fsMargin: EBadgeCodec.readU32le(m),
    );
  }
}

// ---------------------------------------------------------------------------
// 人类可读摘要 —— 调试页日志区直接用
// ---------------------------------------------------------------------------

/// 把一帧翻成一行中文摘要。放在协议层(而非 UI 层)是为了可单测:摘要里的
/// 数值就是解包结果,写错了测试会抓到。
String eBadgeDescribe(EBadgeFrame f) {
  switch (f.cmd) {
    case EBadgeCmd.d2hResult:
      final r = EBadgeResult.parse(f);
      if (r == null) return 'RESULT(参数缺失)';
      return 'RESULT ← cmd 0x${r.cmd.toRadixString(16).padLeft(2, '0')}'
          ' ${EBadgeCmd.name(r.cmd)}:${EBadgeResultCode.name(r.code)}';

    case EBadgeCmd.d2hTransferDecision:
      final d = EBadgeTransferDecision.parse(f);
      if (d == null) return 'DECISION(参数缺失)';
      final reason =
          d.reason == null ? '' : ',reason=${EBadgeXferError.name(d.reason!)}';
      return 'DECISION:${EBadgeDecision.name(d.decision)}$reason';

    case EBadgeCmd.d2hJpgStreamDecision:
      final s = EBadgeStreamDecision.parse(f);
      if (s == null) return 'STREAM_DECISION(参数缺失)';
      final reason =
          s.reason == null ? '' : ',reason=${EBadgeXferError.name(s.reason!)}';
      final fps = s.fps == null ? '' : ',fps=${s.fps}';
      return 'STREAM_DECISION:${EBadgeDecision.nameForStream(s.decision)}'
          '$reason$fps';

    case EBadgeCmd.d2hApInfo:
      final a = EBadgeApInfo.parse(f);
      if (a == null) return 'AP_INFO(参数缺失)';
      final sec = a.security == 0 ? 'Open' : 'WPA2-PSK';
      final proto = a.proto == 0x01
          ? '裸TCP'
          : '未知(0x'
              '${a.proto.toRadixString(16)})';
      return 'AP_INFO:SSID=${a.ssid} 密码=${a.password} ch=${a.channel} '
          '${a.ipv4}:${a.port} $proto $sec';

    case EBadgeCmd.d2hTransferProgress:
      final p = EBadgeProgress.parse(f);
      if (p == null) return 'PROGRESS(参数缺失)';
      final pct = (p.fraction * 100).toStringAsFixed(1);
      return 'PROGRESS:${p.recv}/${p.total} ($pct%)';

    case EBadgeCmd.d2hTransferDone:
      final d = EBadgeTransferDone.parse(f);
      if (d == null) return 'DONE(参数缺失)';
      return 'DONE:file_id=${d.fileId} size=${d.size} name=${d.name}';

    case EBadgeCmd.d2hTransferFail:
      final x = EBadgeTransferFail.parse(f);
      if (x == null) return 'FAIL(参数缺失)';
      final detail =
          (x.detail == null || x.detail!.isEmpty) ? '' : ' — ${x.detail}';
      return 'FAIL:${EBadgeXferError.name(x.reason)}$detail';

    case EBadgeCmd.d2hBattery:
      final b = EBadgeBattery.parse(f);
      if (b == null) return 'BATTERY(参数缺失)';
      return 'BATTERY:${b.percent}% ${EBadgeChargeState.name(b.charge)}';

    case EBadgeCmd.d2hStorageInfo:
      final s = EBadgeStorageInfo.parse(f);
      if (s == null) return 'STORAGE(参数缺失)';
      String mib(int b) => '${(b / 1048576).toStringAsFixed(2)}MiB';
      return 'STORAGE:总 ${mib(s.total)} 可用 ${mib(s.free)} '
          '壁纸 ${s.wpCount} 张占 ${mib(s.wpUsed)} margin=${s.fsMargin}';

    default:
      return '${f.cmdName}:${f.tlvs.length} 条 TLV';
  }
}

// ---------------------------------------------------------------------------
// 合规校验 —— 调试页据此把违规帧标红
// ---------------------------------------------------------------------------

/// 一条协议违规。[hint] 写明**依据的章节**,因为调试台上看到红字的人第一反应
/// 是「凭什么说我错」,给出条款号才能自证。
class EBadgeViolation {
  const EBadgeViolation(this.hint);

  final String hint;

  @override
  String toString() => hint;
}

/// 检查一帧是否符合 V1.3 的硬性约束,返回全部违规项(空表示合规)。
///
/// **只查协议明文规定的硬约束**,不查「看起来不对」的东西:
/// 误报会让红字失去意义 —— 一旦调试的人开始习惯性忽略红色,真正的违规也就
/// 看不见了。所以这里每条判定都对得上一个章节号,拿不准的一律放过。
///
/// 与 [EBadgeParseError] 的分工:那个枚举管**结构性**解析失败(帧同步不上、
/// TLV 越界),在 decode 阶段就报;本函数管**语义**违规 —— 帧结构合法、解得
/// 出来,但内容不符合协议。两者互补,都要在日志里标红。
List<EBadgeViolation> eBadgeValidate(EBadgeFrame f) {
  final out = <EBadgeViolation>[];

  // ── 帧级 ──
  if (f.ver != kEBadgeVersion) {
    out.add(EBadgeViolation('ver=0x${_hx(f.ver)},协议要求 0x01(§2.3)'));
  }
  if (EBadgeCmd.isReserved(f.cmd)) {
    out.add(EBadgeViolation(
      'cmd=0x${_hx(f.cmd)} 落在保留段 0x05–0x07 / 0x0A–0x0F / 0x1B–0x2F,'
      '未定义前禁止使用(§3)',
    ));
  } else if (EBadgeCmd.name(f.cmd) == 'UNKNOWN') {
    out.add(EBadgeViolation('cmd=0x${_hx(f.cmd)} 不在 §3 命令表内'));
  }

  // 重复 type:协议没明令禁止,但同一命令里出现两条同 type 时,接收方取哪条
  // 是未定义的 —— 这是实打实的互操作隐患,值得提示。
  final seen = <int>{};
  for (final t in f.tlvs) {
    if (!seen.add(t.type)) {
      out.add(EBadgeViolation(
        'TLV type 0x${_hx(t.type)} 重复出现,接收方取值未定义(§2.4)',
      ));
    }
  }

  // ── 命令级 ──
  switch (f.cmd) {
    case EBadgeCmd.h2dSetTime:
      _need(out, f, EBadgeTlvSetTime.dateTime, 'TLV_DATE_TIME', '§4.1');
      final dt = f.value(EBadgeTlvSetTime.dateTime);
      if (dt != null && dt.length != 8) {
        out.add(EBadgeViolation('TLV_DATE_TIME 长度 ${dt.length}B,应为 8B(§4.1)'));
      } else if (dt != null) {
        final year = dt[0] | (dt[1] << 8);
        if (year < 2000 || year > 2099) {
          out.add(EBadgeViolation('year=$year 越界,应在 2000–2099(§4.1)'));
        }
        if (dt[2] < 1 || dt[2] > 12) {
          out.add(EBadgeViolation('month=${dt[2]} 越界(§4.1)'));
        }
        if (dt[3] < 1 || dt[3] > 31) {
          out.add(EBadgeViolation('day=${dt[3]} 越界(§4.1)'));
        }
        if (dt[4] > 23) out.add(EBadgeViolation('hour=${dt[4]} 越界(§4.1)'));
        if (dt[5] > 59) out.add(EBadgeViolation('minute=${dt[5]} 越界(§4.1)'));
        if (dt[6] > 59) out.add(EBadgeViolation('second=${dt[6]} 越界(§4.1)'));
        if (dt[7] < 1 || dt[7] > 7) {
          out.add(EBadgeViolation(
            'day_of_week=${dt[7]} 越界,应为 1(周一)–7(周日)(§4.1)',
          ));
        }
      }

    case EBadgeCmd.h2dSendMsg:
      _need(out, f, EBadgeTlvSendMsg.appName, 'TLV_APP_NAME', '§4.3');
      _need(out, f, EBadgeTlvSendMsg.title, 'TLV_TITLE', '§4.3');
      _need(out, f, EBadgeTlvSendMsg.text, 'TLV_TEXT', '§4.3');
      _cap(out, f, EBadgeTlvSendMsg.appName, 'TLV_APP_NAME',
          EBadgeLimits.msgField);
      _cap(out, f, EBadgeTlvSendMsg.title, 'TLV_TITLE', EBadgeLimits.msgField);
      _cap(out, f, EBadgeTlvSendMsg.text, 'TLV_TEXT', EBadgeLimits.msgField);
      _cap(out, f, EBadgeTlvSendMsg.date, 'TLV_DATE', EBadgeLimits.dateString);

    case EBadgeCmd.h2dSendFile:
      _need(out, f, EBadgeTlvSendFile.fileName, 'TLV_FILE_NAME', '§4.2');
      _need(out, f, EBadgeTlvSendFile.fileType, 'TLV_FILE_TYPE', '§4.2');
      _need(out, f, EBadgeTlvSendFile.fileLength, 'TLV_FILE_LENGTH', '§4.2');
      _cap(out, f, EBadgeTlvSendFile.fileName, 'TLV_FILE_NAME',
          EBadgeLimits.fileName);
      _cap(out, f, EBadgeTlvSendFile.fileDate, 'TLV_FILE_DATE',
          EBadgeLimits.dateString);
      _len(out, f, EBadgeTlvSendFile.fileLength, 'TLV_FILE_LENGTH', 4, '§4.2');

    case EBadgeCmd.h2dJpgStreamOffer:
      _need(out, f, EBadgeTlvStreamOffer.name, 'TLV_XFER_NAME', '§4.5');
      _need(out, f, EBadgeTlvStreamOffer.type, 'TLV_XFER_TYPE', '§4.5');
      _need(out, f, EBadgeTlvStreamOffer.fps, 'TLV_XFER_FPS', '§4.5');
      _cap(out, f, EBadgeTlvStreamOffer.name, 'TLV_XFER_NAME',
          EBadgeLimits.fileName);
      _len(out, f, EBadgeTlvStreamOffer.fps, 'TLV_XFER_FPS', 1, '§4.5');
      final st = f.value(EBadgeTlvStreamOffer.type);
      if (st != null && st.isNotEmpty) {
        if (st[0] == EBadgeFileType.unspecified) {
          out.add(const EBadgeViolation(
            'TLV_XFER_TYPE=0x00,Offer 不得使用 UNSPECIFIED(§4.5)',
          ));
        } else if (st[0] > EBadgeFileType.text) {
          out.add(EBadgeViolation(
            'TLV_XFER_TYPE=0x${_hx(st[0])} 不在 §2.7 文件类型表内',
          ));
        }
      }
      // fps=0 语法上合法(uint8),语义上是「一帧都不发」,推流握手里没有意义。
      final sf = f.value(EBadgeTlvStreamOffer.fps);
      if (sf != null && sf.isNotEmpty && sf[0] == 0) {
        out.add(const EBadgeViolation('fps=0,推流帧率至少为 1(§4.5)'));
      }

    case EBadgeCmd.d2hJpgStreamDecision:
      _need(out, f, EBadgeTlvStreamDecision.decision, 'TLV_XFER_DECISION',
          '§4.6');
      _len(out, f, EBadgeTlvStreamDecision.fps, 'TLV_XFER_FPS', 1, '§4.6');
      final sd = f.value(EBadgeTlvStreamDecision.decision);
      if (sd != null && sd.isNotEmpty && sd[0] > EBadgeDecision.negotiate) {
        out.add(EBadgeViolation(
          'decision=${sd[0]},§4.6 只定义 0(拒绝)/ 1(同意)/ 2(协商)',
        ));
      }
      // 拒绝要给原因,协商要给新帧率 —— 否则 App 无从下一步。
      if (sd != null && sd.isNotEmpty) {
        if (sd[0] == EBadgeDecision.reject &&
            f.value(EBadgeTlvStreamDecision.reason) == null) {
          out.add(const EBadgeViolation(
              'decision=REJECT 却缺 TLV_XFER_REASON(§4.6)'));
        }
        if (sd[0] == EBadgeDecision.negotiate &&
            f.value(EBadgeTlvStreamDecision.fps) == null) {
          out.add(const EBadgeViolation(
            'decision=NEGOTIATE 却缺 TLV_XFER_FPS,协商不出帧率(§4.6)',
          ));
        }
      }

    case EBadgeCmd.h2dTransferOffer:
      _need(out, f, EBadgeTlvOffer.name, 'TLV_XFER_NAME', '§4.7');
      _need(out, f, EBadgeTlvOffer.type, 'TLV_XFER_TYPE', '§4.7');
      _need(out, f, EBadgeTlvOffer.size, 'TLV_XFER_SIZE', '§4.7');
      _need(out, f, EBadgeTlvOffer.crc32, 'TLV_XFER_CRC32', '§4.7');
      _cap(out, f, EBadgeTlvOffer.name, 'TLV_XFER_NAME', EBadgeLimits.fileName);
      _len(out, f, EBadgeTlvOffer.size, 'TLV_XFER_SIZE', 4, '§4.7');
      _len(out, f, EBadgeTlvOffer.crc32, 'TLV_XFER_CRC32', 4, '§4.7');
      _len(out, f, EBadgeTlvOffer.replaceId, 'TLV_XFER_REPLACE_ID', 2, '§4.7');
      final ft = f.value(EBadgeTlvOffer.type);
      if (ft != null && ft.isNotEmpty) {
        if (ft[0] == EBadgeFileType.unspecified) {
          out.add(const EBadgeViolation(
            'TLV_XFER_TYPE=0x00,Offer 不得使用 UNSPECIFIED(§4.7)',
          ));
        } else if (ft[0] > EBadgeFileType.text) {
          out.add(EBadgeViolation(
            'TLV_XFER_TYPE=0x${_hx(ft[0])} 不在 §2.7 文件类型表内',
          ));
        }
      }

    case EBadgeCmd.d2hResult:
      _need(out, f, EBadgeTlvResult.resultCmd, 'TLV_RESULT_CMD', '§4.4');
      _need(out, f, EBadgeTlvResult.resultCode, 'TLV_RESULT_CODE', '§4.4');
      final rc = f.value(EBadgeTlvResult.resultCode);
      if (rc != null && rc.isNotEmpty && rc[0] > EBadgeResultCode.busy) {
        out.add(EBadgeViolation(
          'result_code=0x${_hx(rc[0])},§2.5 只定义 0x00(成功)/ 0x01(失败)/ '
          '0x02(未就绪)/ 0x03(忙)',
        ));
      }

    case EBadgeCmd.d2hTransferDecision:
      _need(out, f, EBadgeTlvDecision.decision, 'TLV_DECISION', '§4.8');
      final d = f.value(EBadgeTlvDecision.decision);
      if (d != null && d.isNotEmpty && d[0] > EBadgeDecision.timeout) {
        out.add(EBadgeViolation(
          'decision=${d[0]},§4.8 只定义 0(拒绝)/ 1(同意)/ 2(超时)',
        ));
      }
      // 拒绝/超时必须带原因,否则上层无法给用户解释为什么失败。
      if (d != null &&
          d.isNotEmpty &&
          d[0] != EBadgeDecision.accept &&
          f.value(EBadgeTlvDecision.reason) == null) {
        out.add(const EBadgeViolation('decision 非 ACCEPT 却缺 TLV_REASON(§4.8)'));
      }

    case EBadgeCmd.d2hApInfo:
      _need(out, f, EBadgeTlvApInfo.ssid, 'TLV_SSID', '§4.9');
      _need(out, f, EBadgeTlvApInfo.channel, 'TLV_CHANNEL', '§4.9');
      _need(out, f, EBadgeTlvApInfo.ipv4, 'TLV_IPV4', '§4.9');
      _need(out, f, EBadgeTlvApInfo.port, 'TLV_PORT', '§4.9');
      _cap(out, f, EBadgeTlvApInfo.ssid, 'TLV_SSID', EBadgeLimits.apSsid);
      _cap(out, f, EBadgeTlvApInfo.password, 'TLV_PASSWORD',
          EBadgeLimits.apPassword);
      _len(out, f, EBadgeTlvApInfo.ipv4, 'TLV_IPV4', 4, '§4.9');
      _len(out, f, EBadgeTlvApInfo.port, 'TLV_PORT', 2, '§4.9');
      final ch = f.value(EBadgeTlvApInfo.channel);
      if (ch != null && ch.isNotEmpty && (ch[0] < 1 || ch[0] > 13)) {
        out.add(EBadgeViolation('channel=${ch[0]} 越界,应在 1–13(§4.9)'));
      }
      final proto = f.value(EBadgeTlvApInfo.proto);
      if (proto != null && proto.isNotEmpty && proto[0] != 0x01) {
        out.add(EBadgeViolation(
          'proto=0x${_hx(proto[0])},唯一合法值是 0x01 裸 TCP(§4.9)',
        ));
      }
      final sec = f.value(EBadgeTlvApInfo.security);
      if (sec != null && sec.isNotEmpty && sec[0] > 1) {
        out.add(EBadgeViolation(
            'security=${sec[0]},只定义 0=Open / 1=WPA2-PSK(§4.9)'));
      }
      // 非开放网络必须给密码,否则 app 连不上热点。
      final pwd = f.value(EBadgeTlvApInfo.password);
      if (sec != null && sec.isNotEmpty && sec[0] == 1) {
        if (pwd == null || pwd.isEmpty) {
          out.add(const EBadgeViolation('security=WPA2-PSK 却没给密码(§4.9)'));
        } else if (pwd.length < 8) {
          out.add(EBadgeViolation('WPA2-PSK 密码只有 ${pwd.length}B,至少 8B(§4.9)'));
        }
      }

    case EBadgeCmd.d2hTransferProgress:
      _need(out, f, EBadgeTlvProgress.recv, 'TLV_RECV', '§4.10');
      _need(out, f, EBadgeTlvProgress.total, 'TLV_TOTAL', '§4.10');
      _len(out, f, EBadgeTlvProgress.recv, 'TLV_RECV', 4, '§4.10');
      _len(out, f, EBadgeTlvProgress.total, 'TLV_TOTAL', 4, '§4.10');
      final p = EBadgeProgress.parse(f);
      if (p != null && p.recv > p.total) {
        out.add(EBadgeViolation('recv=${p.recv} > total=${p.total},进度不可能超过总量'));
      }

    case EBadgeCmd.d2hTransferDone:
      _need(out, f, EBadgeTlvDone.fileId, 'TLV_FILE_ID', '§4.11');
      _need(out, f, EBadgeTlvDone.size, 'TLV_SIZE', '§4.11');
      _len(out, f, EBadgeTlvDone.fileId, 'TLV_FILE_ID', 2, '§4.11');
      _len(out, f, EBadgeTlvDone.size, 'TLV_SIZE', 4, '§4.11');
      _cap(out, f, EBadgeTlvDone.name, 'TLV_NAME', EBadgeLimits.fileName);
      final id = f.value(EBadgeTlvDone.fileId);
      if (id != null && id.length >= 2 && EBadgeCodec.readU16le(id) == 0) {
        out.add(const EBadgeViolation('file_id=0,协议要求非 0(§4.11)'));
      }

    case EBadgeCmd.d2hTransferFail:
      _need(out, f, EBadgeTlvFail.reason, 'TLV_REASON', '§4.12');
      _cap(out, f, EBadgeTlvFail.detail, 'TLV_DETAIL', EBadgeLimits.failDetail);
      final rs = f.value(EBadgeTlvFail.reason);
      if (rs != null &&
          rs.isNotEmpty &&
          (rs[0] < EBadgeXferError.userReject ||
              rs[0] > EBadgeXferError.cancelled)) {
        out.add(EBadgeViolation('reason=0x${_hx(rs[0])} 不在 §2.6 错误码表内'));
      }

    case EBadgeCmd.d2hBattery:
      _need(out, f, EBadgeTlvBattery.percent, 'TLV_PERCENT', '§4.13');
      _need(out, f, EBadgeTlvBattery.charge, 'TLV_CHARGE', '§4.13');
      final pc = f.value(EBadgeTlvBattery.percent);
      if (pc != null && pc.isNotEmpty && pc[0] > 100) {
        out.add(EBadgeViolation('percent=${pc[0]},应在 0–100(§4.13)'));
      }
      final cg = f.value(EBadgeTlvBattery.charge);
      if (cg != null && cg.isNotEmpty && cg[0] > EBadgeChargeState.full) {
        out.add(EBadgeViolation(
          'charge=${cg[0]},只定义 0(未充)/ 1(充电中)/ 2(已满)(§4.13)',
        ));
      }

    case EBadgeCmd.d2hStorageInfo:
      _need(out, f, EBadgeTlvStorage.total, 'TLV_TOTAL', '§4.14');
      _need(out, f, EBadgeTlvStorage.free, 'TLV_FREE', '§4.14');
      _len(out, f, EBadgeTlvStorage.total, 'TLV_TOTAL', 8, '§4.14');
      _len(out, f, EBadgeTlvStorage.free, 'TLV_FREE', 8, '§4.14');
      _len(out, f, EBadgeTlvStorage.wpCount, 'TLV_WP_COUNT', 2, '§4.14');
      _len(out, f, EBadgeTlvStorage.wpUsed, 'TLV_WP_USED', 8, '§4.14');
      _len(out, f, EBadgeTlvStorage.fsMargin, 'TLV_FS_MARGIN', 4, '§4.14');
      final s = EBadgeStorageInfo.parse(f);
      if (s != null) {
        if (s.free > s.total) {
          out.add(EBadgeViolation('free=${s.free} > total=${s.total}'));
        }
        if (s.fsMargin != EBadgeLimits.fsMargin) {
          out.add(EBadgeViolation(
            'fs_margin=${s.fsMargin},§2.9 定稿固定回 ${EBadgeLimits.fsMargin}',
          ));
        }
      }

    // 无参数查询命令:多带 TLV 说明双方对协议的理解已经分叉。
    case EBadgeCmd.h2dGetApInfo:
    case EBadgeCmd.h2dGetBattery:
    case EBadgeCmd.h2dGetStorage:
      if (f.tlvs.isNotEmpty) {
        out.add(EBadgeViolation(
          '${f.cmdName} 是无参数命令,却带了 ${f.tlvs.length} 条 TLV(§4)',
        ));
      }
  }

  return out;
}

String _hx(int v) => v.toRadixString(16).toUpperCase().padLeft(2, '0');

/// 必选 TLV 缺失。
void _need(
  List<EBadgeViolation> out,
  EBadgeFrame f,
  int type,
  String label,
  String ref,
) {
  if (f.value(type) == null) {
    out.add(EBadgeViolation('缺必选 $label(type 0x${_hx(type)})($ref)'));
  }
}

/// 定长 TLV 长度不符。TLV 不存在时不报 —— 缺失由 [_need] 负责,避免一处错误
/// 刷出两条红字。
void _len(
  List<EBadgeViolation> out,
  EBadgeFrame f,
  int type,
  String label,
  int expect,
  String ref,
) {
  final v = f.value(type);
  if (v != null && v.length != expect) {
    out.add(EBadgeViolation('$label 长度 ${v.length}B,应为 ${expect}B($ref)'));
  }
}

/// 变长 TLV 超出 §2.8 字节上限。注意比的是**字节数**而非字符数:23B 只装得下
/// 7 个中文,按字符判会漏报。
void _cap(
  List<EBadgeViolation> out,
  EBadgeFrame f,
  int type,
  String label,
  int max,
) {
  final v = f.value(type);
  if (v != null && v.length > max) {
    out.add(EBadgeViolation('$label ${v.length}B 超出上限 ${max}B(§2.8)'));
  }
}

// ---------------------------------------------------------------------------
// Wi-Fi 数据面 (§5.2 / §5.3 / §6.2)
// ---------------------------------------------------------------------------

/// §5.2 TCP 上传固定头。
///
/// 头长 **40 字节**:§5.2 正文小标题写的「固定头 32 字节」与自己的字段表
/// (偏移 0…39)和结尾「固定头总长 40 字节」矛盾,取 40 —— 修订记录 V1.2
/// 也写明「EBXF 40B 头」,三处对二处,40 是对的。
abstract class EBadgeXferHeader {
  static const int length = 40;
  static const int nameFieldLength = 24;

  /// magic 'EBXF'
  static const List<int> magic = [0x45, 0x42, 0x58, 0x46];

  static Uint8List build({
    required int fileType,
    required String name,
    required int size,
    required int crc32,
  }) {
    final nameBytes = EBadgeCodec.str(name, EBadgeLimits.fileName, 'name');
    final h = Uint8List(length);
    h.setRange(0, 4, magic);
    h[4] = kEBadgeVersion;
    h[5] = fileType & 0xFF;
    h[6] = nameBytes.length;
    h[7] = 0x00; // reserved
    h.setRange(8, 12, EBadgeCodec.u32le(size));
    h.setRange(12, 16, EBadgeCodec.u32le(crc32));
    // 16..40 = name,前 name_len 有效,其余保持 0x00 填充
    h.setRange(16, 16 + nameBytes.length, nameBytes);
    return h;
  }
}

/// §6.2 同屏预览的 TCP 流帧头(**14 字节**,V1.3 新增)。
///
/// 与 [EBadgeXferHeader] 的 magic **完全相同**('EBXF'),仅靠头长区分:
/// 40B = §5 壁纸单文件,14B = §6 同屏多帧。所以收发两侧必须按会话类型
/// (0x10 Offer 还是 0x08 Offer)决定用哪个头去解 —— 拿 magic 判断不出来。
/// 这是协议本身的设计,不是这里的实现取巧。
///
/// 字段上的差别:没有 name / name_len / reserved,`size` 与 `crc32` 是**本帧
/// payload** 的长度和校验(不是整个流的),因为流没有总长。
abstract class EBadgeStreamHeader {
  static const int length = 14;

  /// magic 'EBXF' —— 与 §5.2 同一个。
  static const List<int> magic = EBadgeXferHeader.magic;

  static Uint8List build({
    int fileType = EBadgeFileType.jpegStream,
    required int size,
    required int crc32,
  }) {
    final h = Uint8List(length);
    h.setRange(0, 4, magic);
    h[4] = kEBadgeVersion;
    h[5] = fileType & 0xFF;
    h.setRange(6, 10, EBadgeCodec.u32le(size));
    h.setRange(10, 14, EBadgeCodec.u32le(crc32));
    return h;
  }

  /// 解回 (fileType, size, crc32);magic/version 不符或长度不足返回 null。
  /// 调试页要能把自己发出去的头再读一遍核对,所以 build 之外也给个 parse。
  static ({int fileType, int size, int crc32})? parse(Uint8List b) {
    if (b.length < length) return null;
    for (var i = 0; i < 4; i++) {
      if (b[i] != magic[i]) return null;
    }
    if (b[4] != kEBadgeVersion) return null;
    return (
      fileType: b[5],
      size: EBadgeCodec.readU32le(b, 6),
      crc32: EBadgeCodec.readU32le(b, 10),
    );
  }
}

/// §5.3 TCP 应答帧(8 字节)。
class EBadgeXferAck {
  const EBadgeXferAck({required this.status, required this.reason});

  final int status; // 0x00 失败 0x01 成功
  final int reason; // 失败时为 §2.6 错误码

  bool get succeed => status == 0x01;

  static const int length = 8;

  /// magic 'EBXR'
  static const List<int> magic = [0x45, 0x42, 0x58, 0x52];

  static EBadgeXferAck? parse(Uint8List b) {
    if (b.length < length) return null;
    for (var i = 0; i < 4; i++) {
      if (b[i] != magic[i]) return null;
    }
    return EBadgeXferAck(status: b[4], reason: b[5]);
  }
}

/// IEEE 802.3 CRC32(反射多项式 0xEDB88320)—— Offer 的 TLV_XFER_CRC32 与
/// EBXF 头的 crc32 都用它,且两处**必须一致**(§5.2 校验规则第 3 条)。
int eBadgeCrc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b & 0xFF;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
