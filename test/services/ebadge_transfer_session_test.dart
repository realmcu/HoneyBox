import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ebadge_link.dart';
import 'package:honeybox/services/ebadge_protocol.dart';
import 'package:honeybox/services/ebadge_transfer_session.dart';
import 'package:honeybox/services/ebadge_wifi_transport.dart';

/// 只替掉 [EBadgeTransferSession] 真正用到的四个成员:ready / frames / send /
/// 日志。其余照原样继承 —— 日志会老老实实进那个有界列表,不用管。
class _FakeLink extends EBadgeLink {
  _FakeLink() : super(deviceId: 'fake', deviceName: 'fake');

  final _ctl = StreamController<EBadgeFrame>.broadcast();

  /// 发出去的 cmd 号,按顺序。
  final sent = <int>[];

  /// 发出去的整帧。要核 0xE0 里那四条 TLV 的内容,光有 cmd 号不够。
  final frames0 = <Uint8List>[];

  @override
  bool get ready => true;

  @override
  Stream<EBadgeFrame> get frames => _ctl.stream;

  @override
  Future<bool> send(Uint8List frame, String label) async {
    sent.add(frame[1]); // cmd
    frames0.add(frame);
    return true;
  }

  /// 最后一次发出去的那一帧,解好的。
  EBadgeFrame get lastFrame => EBadgeCodec.decode(frames0.last).frame!;

  /// 模拟设备 Notify 一帧上来。
  void push(Uint8List raw) => _ctl.add(EBadgeCodec.decode(raw).frame!);

  void close() => _ctl.close();
}

/// 数据面整段短路成「一次就成」—— 这个文件测的是 BLE 侧的时序,把 TCP 也拉进来
/// 只会让失败原因变多。
class _FakeWifi extends EBadgeWifiTransport {
  int joins = 0;
  int uploads = 0;

  /// 会话交给数据面的那几个值。它们要和 Offer 里的逐个对上 —— §5.2 校验规则第 3 条
  /// 要求两处的 CRC32 相同,而 type 不一致设备会直接 close。
  String? sawName;
  int? sawFileType;
  int? sawCrc32;
  int? sawLength;

  @override
  Future<String?> join({
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    joins++;
    return null;
  }

  @override
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
    uploads++;
    sawName = name;
    sawFileType = fileType;
    sawCrc32 = crc32;
    sawLength = body.length;
    onProgress?.call(body.length, body.length);
    return EBadgeWifiResult.ok(
      const EBadgeXferAck(status: 0x01, reason: 0x00),
      bytesSent: body.length,
      totalBytes: body.length,
      headerSent: true,
    );
  }

  @override
  Future<void> leave() async {}
}

Uint8List _apInfo() => EBadgeCodec.encode(EBadgeCmd.d2hApInfo, [
      EBadgeTlv(EBadgeTlvApInfo.ssid, EBadgeCodec.str('EBadge-AP', 32, 'ssid')),
      EBadgeTlv(
          EBadgeTlvApInfo.password, EBadgeCodec.str('12345678', 64, 'pw')),
      EBadgeTlv(EBadgeTlvApInfo.channel, EBadgeCodec.u8(6)),
      EBadgeTlv(EBadgeTlvApInfo.ipv4, Uint8List.fromList([192, 168, 4, 1])),
      EBadgeTlv(EBadgeTlvApInfo.port, EBadgeCodec.u16le(9000)),
      EBadgeTlv(EBadgeTlvApInfo.proto, EBadgeCodec.u8(0x01)),
      EBadgeTlv(EBadgeTlvApInfo.security, EBadgeCodec.u8(1)),
    ]);

// 0x11/0xE1、0x14/0xE4、0x16/0xE6 三对的参数区逐号一致(见 [EBadgeTlvOtaDecision]
// 那几张表),所以每对共用一个构造器、只换 cmd —— 造两份一模一样的字节没有意义,
// 而「号不同、内容相同」正是这套私有命令要钉住的事实。

Uint8List _decision(int d, {int cmd = EBadgeCmd.d2hTransferDecision}) =>
    EBadgeCodec.encode(cmd, [
      EBadgeTlv(EBadgeTlvDecision.decision, EBadgeCodec.u8(d)),
    ]);

Uint8List _otaDecision(int d) => _decision(d, cmd: EBadgeCmd.d2hOtaDecision);

Uint8List _fail(int reason, {int cmd = EBadgeCmd.d2hTransferFail}) =>
    EBadgeCodec.encode(cmd, [
      EBadgeTlv(EBadgeTlvFail.reason, EBadgeCodec.u8(reason)),
    ]);

Uint8List _otaFail(int reason) => _fail(reason, cmd: EBadgeCmd.d2hOtaFail);

Uint8List _progress(int recv, int total,
        {int cmd = EBadgeCmd.d2hTransferProgress}) =>
    EBadgeCodec.encode(cmd, [
      EBadgeTlv(EBadgeTlvProgress.recv, EBadgeCodec.u32le(recv)),
      EBadgeTlv(EBadgeTlvProgress.total, EBadgeCodec.u32le(total)),
    ]);

Uint8List _done(int size) => EBadgeCodec.encode(EBadgeCmd.d2hTransferDone, [
      EBadgeTlv(EBadgeTlvDone.fileId, EBadgeCodec.u16le(7)),
      EBadgeTlv(EBadgeTlvDone.size, EBadgeCodec.u32le(size)),
      EBadgeTlv(EBadgeTlvDone.name, EBadgeCodec.str('fw.bin', 23, 'name')),
    ]);

/// 0xE5。**file_id 默认不带** —— 固件包没有「入库成了第几张壁纸」这回事,真固件
/// 大概率就是这个形状,所以默认形态就该是它。
Uint8List _otaDone(int size, {int? fileId}) =>
    EBadgeCodec.encode(EBadgeCmd.d2hOtaDone, [
      if (fileId != null)
        EBadgeTlv(EBadgeTlvOtaDone.fileId, EBadgeCodec.u16le(fileId)),
      EBadgeTlv(EBadgeTlvOtaDone.size, EBadgeCodec.u32le(size)),
    ]);

/// 让出足够多轮事件循环,好让会话推进到下一个 await 并订阅上。
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  final body = Uint8List.fromList(List<int>.filled(64, 0xA5));
  final bodyCrc = eBadgeCrc32(body);

  ({
    _FakeLink link,
    _FakeWifi wifi,
    EBadgeTransferSession s,
    Map<EBadgeXferStage, String?> detail,
  }) mk(EBadgeXferKind kind) {
    final link = _FakeLink();
    final wifi = _FakeWifi();
    final detail = <EBadgeXferStage, String?>{};
    return (
      link: link,
      wifi: wifi,
      detail: detail,
      s: EBadgeTransferSession(
        link: link,
        wifi: wifi,
        kind: kind,
        onStage: (stage, d) => detail[stage] = d,
      ),
    );
  }

  group('OTA:0xE0 → 0xE1 → 0x13 → TCP → 0xE5', () {
    test('整条走通,和传图同一套阶段', () async {
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      expect(t.link.sent, [EBadgeCmd.h2dOtaOffer]); // 第一帧是 0xE0
      t.link.push(_otaDecision(EBadgeDecision.accept));

      await _settle();
      t.link.push(_apInfo()); // 热点那两条共用 0x12/0x13

      await _settle();
      t.link.push(_otaDone(body.length)); // 0xE5

      expect(await fut, isNull);
      expect(t.s.stage, EBadgeXferStage.done);
      expect(t.wifi.joins, 1);
      expect(t.wifi.uploads, 1);
      // 已经拿到 AP 信息就不该再补发 0x12 去问一遍。
      expect(t.link.sent, isNot(contains(EBadgeCmd.h2dGetApInfo)));
      t.link.close();
    });

    test('0xE0 的四条 TLV 和数据面头里的是同一份;type 被强制成 BIN', () async {
      final t = mk(EBadgeXferKind.ota);
      // 调用方故意报 JPEG:§5.2 要求 Offer 和 EBXF 头里的 type 一致,而 OTA 恒为
      // BIN —— 会话必须把它盖掉,而不是把一个矛盾的组合送上线(设备会直接 close,
      // 现场表现只是「连上就断」)。
      final fut =
          t.s.run(name: 'fw.bin', type: EBadgeFileType.jpeg, body: body);

      await _settle();
      final offer = t.link.lastFrame;
      expect(offer.cmd, EBadgeCmd.h2dOtaOffer);
      expect(offer.value(EBadgeTlvOtaOffer.type)!.single, EBadgeFileType.bin);
      expect(EBadgeCodec.readU32le(offer.value(EBadgeTlvOtaOffer.size)!),
          body.length);
      expect(EBadgeCodec.readU32le(offer.value(EBadgeTlvOtaOffer.crc32)!),
          bodyCrc);

      t.link.push(_otaDecision(EBadgeDecision.accept));
      await _settle();
      t.link.push(_apInfo());
      await _settle();
      t.link.push(_otaDone(body.length));

      expect(await fut, isNull);
      expect(t.wifi.sawName, 'fw.bin');
      expect(t.wifi.sawFileType, EBadgeFileType.bin);
      expect(t.wifi.sawCrc32, bodyCrc); // 整份包只算一次 CRC,两处共用
      expect(t.wifi.sawLength, body.length);
      t.link.close();
    });

    test('0xE5 不带 file_id 也算成功 —— 固件包没有「第几张壁纸」', () async {
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      t.link.push(_otaDecision(EBadgeDecision.accept));
      await _settle();
      t.link.push(_apInfo());
      await _settle();
      t.link.push(_otaDone(body.length)); // 只有 size

      expect(await fut, isNull);
      expect(t.s.stage, EBadgeXferStage.done);
      // 阶段线上要能看到对账用的那个数,而不是一句空话。
      expect(t.detail[EBadgeXferStage.done], 'size=64B');
      t.link.close();
    });

    test('0xE5 带了 file_id / name 就一并显示', () async {
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      t.link.push(_otaDecision(EBadgeDecision.accept));
      await _settle();
      t.link.push(_apInfo());
      await _settle();
      t.link.push(_otaDone(body.length, fileId: 7));

      expect(await fut, isNull);
      expect(t.detail[EBadgeXferStage.done], 'size=64B file_id=7');
      t.link.close();
    });

    test('传图那一组的 0x15 / 0x16 不动 OTA 会话', () async {
      // 号分开的意义就在这:两条链路的帧在同一条 BLE 上混着来,谁的完成/失败是谁的
      // 不能靠猜 —— 认错一次,轻则误报失败,重则把别人的成功当成自己的。
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      t.link.push(_fail(EBadgeXferError.busy)); // 0x16
      await _settle();
      expect(t.s.stage, EBadgeXferStage.waitDecision); // 一步都没动

      t.link.push(_otaDecision(EBadgeDecision.accept));
      await _settle();
      t.link.push(_apInfo());
      await _settle();
      t.link.push(_done(body.length)); // 0x15:也不是 OTA 的完成信号
      await _settle();
      expect(t.s.stage, EBadgeXferStage.waitDone);

      t.link.push(_otaDone(body.length));
      expect(await fut, isNull);
      expect(t.s.stage, EBadgeXferStage.done);
      t.link.close();
    });

    test('0xE4 的进度进对账文本,0x14 的不采信', () async {
      // 两个数字的**差**才是这类故障最有诊断力的事实,所以设备侧那个数必须是从自己
      // 这条链路上收来的 —— 掺进传图那条的,差值就成了假的。
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      t.link.push(_otaDecision(EBadgeDecision.accept));
      await _settle();
      t.link.push(_apInfo());
      await _settle();
      t.link.push(_progress(48, 64)); // 0x14,不该被采信
      t.link.push(_progress(32, 64, cmd: EBadgeCmd.d2hOtaProgress));
      await _settle();
      t.link.push(_otaFail(EBadgeXferError.verify));

      final err = await fut;
      expect(err, contains('设备只确认收到 32 B'));
      expect(err, isNot(contains('48')));
      t.link.close();
    });

    test('0xE1 回拒绝 → 直接失败,不去连热点', () async {
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      t.link.push(_otaDecision(EBadgeDecision.reject));

      expect(await fut, contains('设备未同意OTA'));
      expect(t.s.stage, EBadgeXferStage.failed);
      expect(t.wifi.joins, 0);
      t.link.close();
    });

    test('0xE6 FAIL 整个会话期间都能中断', () async {
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      t.link.push(_otaFail(EBadgeXferError.storageFull));

      expect(await fut, contains('设备报告OTA失败'));
      expect(t.s.stage, EBadgeXferStage.failed);
      expect(t.wifi.joins, 0);
      t.link.close();
    });

    test('设备跳过 0xE1 直接报 0x13,仍按同意放行(兼容那版固件)', () async {
      // 这条容忍只在 0xE1 一直没来时生效:守着一个这版固件不会发的帧等满 35 s 再判
      // 失败,是拿一次本来能成的升级去换时序上的洁癖。
      final t = mk(EBadgeXferKind.ota);
      final fut = t.s.run(name: 'fw.bin', type: EBadgeFileType.bin, body: body);

      await _settle();
      expect(t.link.sent, [EBadgeCmd.h2dOtaOffer]);
      t.link.push(_apInfo()); // 全程没有 0xE1

      await _settle();
      t.link.push(_otaDone(body.length));

      expect(await fut, isNull);
      expect(t.s.stage, EBadgeXferStage.done);
      expect(t.wifi.joins, 1);
      expect(t.wifi.uploads, 1);
      expect(t.link.sent, isNot(contains(EBadgeCmd.h2dGetApInfo)));
      t.link.close();
    });
  });

  group('传图:必须等到 0x11,先来的 0x13 不算同意', () {
    test('只来 AP_INFO 不会放行 —— §5.4 规定它得先回 DECISION', () async {
      final t = mk(EBadgeXferKind.wallpaper);
      final fut = t.s.run(name: 'a.jpg', type: EBadgeFileType.jpeg, body: body);

      await _settle();
      expect(t.link.sent, [EBadgeCmd.h2dTransferOffer]);
      t.link.push(_apInfo());
      await _settle();

      // 还停在等确认,一步都没往下走。
      expect(t.s.stage, EBadgeXferStage.waitDecision);
      expect(t.wifi.joins, 0);

      // 推一条 0x16 把会话收干净,免得留一个 35 s 的定时器在后台。
      t.link.push(_fail(EBadgeXferError.busy));
      expect(await fut, contains('设备报告传图失败'));
      t.link.close();
    });

    test('type 只在 OTA 上被盖成 BIN,壁纸照调用方给的走', () async {
      final t = mk(EBadgeXferKind.wallpaper);
      final fut = t.s.run(name: 'a.jpg', type: EBadgeFileType.jpeg, body: body);

      await _settle();
      expect(t.link.lastFrame.value(EBadgeTlvOffer.type)!.single,
          EBadgeFileType.jpeg);
      t.link.push(_decision(EBadgeDecision.accept));
      await _settle();
      t.link.push(_apInfo());
      await _settle();
      t.link.push(_done(body.length));

      expect(await fut, isNull);
      expect(t.wifi.sawFileType, EBadgeFileType.jpeg);
      expect(t.wifi.sawCrc32, bodyCrc);
      expect(t.detail[EBadgeXferStage.done], contains('file_id=7'));
      t.link.close();
    });
  });
}
