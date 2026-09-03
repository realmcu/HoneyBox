import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ebadge_protocol.dart';

/// 断言用:把 '01 01 80 0B 00' 这样的文档示例转成字节。
Uint8List h(String s) => Uint8List.fromList(
      s
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .map((t) => int.parse(t, radix: 16))
          .toList(),
    );

String hexOf(Uint8List b) => EBadgeCodec.hex(b);

void main() {
  group('帧编码 (§2.3)', () {
    test('无参数命令 params_len=0 —— GET_AP_INFO 文档示例', () {
      // §4.9:01 12 80 00 00
      expect(hexOf(EBadgeRequest.getApInfo()), hexOf(h('01 12 80 00 00')));
    });

    test('无参数命令 —— GET_BATTERY / GET_STORAGE 文档示例', () {
      expect(hexOf(EBadgeRequest.getBattery()), hexOf(h('01 17 80 00 00')));
      expect(hexOf(EBadgeRequest.getStorage()), hexOf(h('01 19 80 00 00')));
    });

    test('params_len 是小端 uint16', () {
      // 300 字节参数区 → 0x012C → 线缆上 2C 01
      final frame = EBadgeCodec.encode(
        0x02,
        [EBadgeTlv(0x01, Uint8List(297))], // 3 + 297 = 300
      );
      expect(frame[3], 0x2C);
      expect(frame[4], 0x01);
      expect(frame.length, kEBadgeHeaderLength + 300);
    });

    test('TLV length 也是小端 uint16', () {
      final frame = EBadgeCodec.encode(0x02, [EBadgeTlv(0x07, Uint8List(258))]);
      // TLV 头在偏移 5:type=07, len=0x0102 → 02 01
      expect(frame[5], 0x07);
      expect(frame[6], 0x02);
      expect(frame[7], 0x01);
    });
  });

  group('0x01 SET_TIME (§4.1)', () {
    test('完全复现文档 hex 示例:2026-08-11 15:30:00 周二', () {
      // 文档示例:01 01 80 0B 00 | 01 08 00 EA 07 08 0B 0F 1E 00 02
      // year 2026 = 0x07EA → LE 为 EA 07;day_of_week=02 表示周二。
      final frame = EBadgeRequest.setTime(DateTime(2026, 8, 11, 15, 30, 0));
      expect(
        hexOf(frame),
        hexOf(h('01 01 80 0B 00 01 08 00 EA 07 08 0B 0F 1E 00 02')),
      );
    });

    test('星期映射:周一=1 … 周日=7', () {
      // 2026-08-10 是周一,2026-08-16 是周日。
      Uint8List dow(DateTime d) => EBadgeRequest.setTime(d);
      // 参数区偏移:帧头5 + TLV头3 + 7 = 15 是 day_of_week
      expect(dow(DateTime(2026, 8, 10))[15], 1);
      expect(dow(DateTime(2026, 8, 16))[15], 7);
    });

    test('年份越界抛异常', () {
      expect(
        () => EBadgeRequest.setTime(DateTime(1000)),
        throwsArgumentError,
      );
    });
  });

  group('0x02 SEND_FILE (§4.2)', () {
    test('完全复现文档 hex 示例:a.bin / JPEG / 4B', () {
      // 文档 §4.2:params_len=0x0013=19
      //   01 02 80 13 00
      //   01 05 00 61 2E 62 69 6E   name "a.bin"
      //   02 01 00 01               type JPEG
      //   04 04 00 04 00 00 00      length=4(uint32 LE)
      // 这是调试页 SEND_FILE 按钮发的那一帧,两边必须逐字节一致 —— 界面上
      // 看到的 hex 对不上文档就说明组包坏了。
      final frame = EBadgeRequest.sendFileMeta(
        name: 'a.bin',
        type: EBadgeFileType.jpeg,
        length: 4,
      );
      expect(
        hexOf(frame),
        hexOf(h('01 02 80 13 00 '
            '01 05 00 61 2E 62 69 6E '
            '02 01 00 01 '
            '04 04 00 04 00 00 00')),
      );
    });

    test('元数据帧只带元数据 —— 正文不在帧内', () {
      // §4.2 要求正文在元数据 TLV 之后、同一 BLE RX 流上裸发,
      // 所以 length=4 的帧长度不该因正文而变。
      final frame = EBadgeRequest.sendFileMeta(
        name: 'a.bin',
        type: EBadgeFileType.jpeg,
        length: 4,
      );
      expect(frame.length, 5 + 19);
    });

    test('date 省略时不发 0x03 TLV,给了就带上', () {
      final without = EBadgeCodec.decode(EBadgeRequest.sendFileMeta(
        name: 'a.bin',
        type: EBadgeFileType.bin,
        length: 1,
      )).frame!;
      expect(without.tlvs.map((t) => t.type), [0x01, 0x02, 0x04]);

      final with_ = EBadgeCodec.decode(EBadgeRequest.sendFileMeta(
        name: 'a.bin',
        type: EBadgeFileType.bin,
        length: 1,
        date: '2026-08-14',
      )).frame!;
      expect(with_.tlvs.map((t) => t.type), [0x01, 0x02, 0x03, 0x04]);
      expect(
          utf8.decode(with_.value(EBadgeTlvSendFile.fileDate)!), '2026-08-14');
    });

    test('length 是小端 uint32', () {
      final f = EBadgeCodec.decode(EBadgeRequest.sendFileMeta(
        name: 'a.bin',
        type: EBadgeFileType.bin,
        length: 0x00012345,
      )).frame!;
      expect(
        EBadgeCodec.readU32le(f.value(EBadgeTlvSendFile.fileLength)!),
        0x00012345,
      );
    });

    test('文件名超 23 字节抛异常', () {
      expect(
        () => EBadgeRequest.sendFileMeta(
          name: 'x' * 24,
          type: EBadgeFileType.bin,
          length: 1,
        ),
        throwsArgumentError,
      );
    });

    test('文档示例帧过校验器无违规', () {
      final f = EBadgeCodec.decode(EBadgeRequest.sendFileMeta(
        name: 'a.bin',
        type: EBadgeFileType.jpeg,
        length: 4,
      )).frame!;
      expect(eBadgeValidate(f), isEmpty);
    });
  });

  group('0x03 SEND_MSG (§4.3)', () {
    test('四个 TLV 按 app/title/text/date 顺序排列', () {
      final frame = EBadgeRequest.sendMsg(
        appName: 'WeChat',
        title: 'Tom',
        text: 'hi',
        date: '08-11 15:30',
      );
      final r = EBadgeCodec.decode(frame);
      expect(r.isOk, isTrue);
      final tlvs = r.frame!.tlvs;
      expect(tlvs.map((t) => t.type), [0x01, 0x02, 0x03, 0x04]);
      expect(utf8.decode(tlvs[0].value), 'WeChat');
      expect(utf8.decode(tlvs[3].value), '08-11 15:30');
    });

    test('date 省略时不发该 TLV', () {
      final frame = EBadgeRequest.sendMsg(appName: 'A', title: 'B', text: 'C');
      final tlvs = EBadgeCodec.decode(frame).frame!.tlvs;
      expect(tlvs.length, 3);
    });

    test('超过 23 字节按字节拦截,不静默截断', () {
      // 8 个中文 = 24 字节 > 23,即使只有 8 个「字」也应拒绝。
      expect(
        () => EBadgeRequest.sendMsg(
          appName: 'A',
          title: 'B',
          text: '一二三四五六七八',
        ),
        throwsArgumentError,
      );
      // 7 个中文 = 21 字节,合法。
      expect(
        () => EBadgeRequest.sendMsg(appName: 'A', title: 'B', text: '一二三四五六七'),
        returnsNormally,
      );
    });
  });

  group('0x10 TRANSFER_OFFER (§4.7)', () {
    test('size / crc32 为小端 uint32,replaceId 可省', () {
      final frame = EBadgeRequest.transferOffer(
        name: 'a.jpg',
        type: EBadgeFileType.jpeg,
        size: 0x00012345,
        crc32: 0xAABBCCDD,
      );
      final f = EBadgeCodec.decode(frame).frame!;
      expect(f.tlvs.map((t) => t.type), [0x01, 0x02, 0x03, 0x04]);
      expect(EBadgeCodec.readU32le(f.value(EBadgeTlvOffer.size)!), 0x00012345);
      expect(EBadgeCodec.readU32le(f.value(EBadgeTlvOffer.crc32)!), 0xAABBCCDD);
    });

    test('带 replaceId 时追加 0x05 TLV(uint16 LE)', () {
      final f = EBadgeCodec.decode(EBadgeRequest.transferOffer(
        name: 'a.jpg',
        type: EBadgeFileType.png,
        size: 1,
        crc32: 2,
        replaceId: 0x0102,
      )).frame!;
      expect(EBadgeCodec.readU16le(f.value(EBadgeTlvOffer.replaceId)!), 0x0102);
    });

    test('file_type 为 0x00 被拒(Offer 不得使用未指定类型)', () {
      expect(
        () => EBadgeRequest.transferOffer(
          name: 'a',
          type: EBadgeFileType.unspecified,
          size: 1,
          crc32: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('0x08 / 0x09 同屏预览握手 (§4.5 / §4.6,V1.3 新增)', () {
    test('OFFER 带 name / type / fps 三个 TLV,且不带 size / crc32', () {
      final f = EBadgeCodec.decode(EBadgeRequest.jpgStreamOffer(
        name: 'live.jpg',
        fps: 20,
      )).frame!;
      expect(f.cmd, EBadgeCmd.h2dJpgStreamOffer);
      // 关键差别:同屏是持续推流,总长在握手时不存在,所以没有 size(0x03 在
      // 0x10 里是 size,在这里是 fps)、也没有 crc32(0x04)。
      expect(f.tlvs.map((t) => t.type), [0x01, 0x02, 0x03]);
      expect(utf8.decode(f.value(EBadgeTlvStreamOffer.name)!), 'live.jpg');
      expect(f.value(EBadgeTlvStreamOffer.type)![0], EBadgeFileType.jpegStream);
      expect(f.value(EBadgeTlvStreamOffer.fps)![0], 20);
      expect(eBadgeValidate(f), isEmpty);
    });

    test('fps 是 uint8,越界抛异常', () {
      expect(() => EBadgeRequest.jpgStreamOffer(name: 'a', fps: 0),
          throwsArgumentError);
      expect(() => EBadgeRequest.jpgStreamOffer(name: 'a', fps: 256),
          throwsArgumentError);
      expect(() => EBadgeRequest.jpgStreamOffer(name: 'a', fps: 255),
          returnsNormally);
    });

    test('file_type=0x00 被拒(与 0x10 同一条约束)', () {
      expect(
        () => EBadgeRequest.jpgStreamOffer(
          name: 'a',
          type: EBadgeFileType.unspecified,
          fps: 10,
        ),
        throwsArgumentError,
      );
    });

    test('DECISION 的 2 是「协商」而不是 0x11 那个「超时」', () {
      // decision=2 + fps=8:设备同意但要降帧率。
      final f = EBadgeCodec.decode(
        h('01 09 80 08 00 01 01 00 02 03 01 00 08'),
      ).frame!;
      final d = EBadgeStreamDecision.parse(f)!;
      expect(d.negotiated, isTrue);
      expect(d.accepted, isFalse); // 协商 ≠ accept,但同样要继续往下走
      expect(d.fps, 8);
      // 同一个字节值在两条命令里的名字不同,不能共用 name()。
      expect(EBadgeDecision.nameForStream(2), 'NEGOTIATE');
      expect(EBadgeDecision.name(2), 'TIMEOUT');
    });

    test('effectiveFps:设备给了听设备的,没给沿用请求值', () {
      final negotiated = EBadgeStreamDecision.parse(EBadgeCodec.decode(
        h('01 09 80 08 00 01 01 00 02 03 01 00 08'),
      ).frame!)!;
      expect(negotiated.effectiveFps(20), 8);

      // decision=1 且不带 fps:按请求的帧率走。
      final plain = EBadgeStreamDecision.parse(
        EBadgeCodec.decode(h('01 09 80 04 00 01 01 00 01')).frame!,
      )!;
      expect(plain.accepted, isTrue);
      expect(plain.fps, isNull);
      expect(plain.effectiveFps(20), 20);
    });

    test('拒绝时带 §2.6 错误码,摘要里能读到原因', () {
      final f = EBadgeCodec.decode(
        h('01 09 80 08 00 01 01 00 00 02 01 00 0A'),
      ).frame!;
      final d = EBadgeStreamDecision.parse(f)!;
      expect(d.accepted, isFalse);
      expect(d.negotiated, isFalse);
      expect(d.reason, EBadgeXferError.busy);
      final s = eBadgeDescribe(f);
      expect(s, contains('REJECT'));
      expect(s, contains('BUSY'));
    });

    test('decision TLV 缺失时 parse 返回 null 而不是崩', () {
      final f = EBadgeCodec.decode(h('01 09 80 00 00')).frame!;
      expect(EBadgeStreamDecision.parse(f), isNull);
      expect(eBadgeDescribe(f), contains('参数缺失'));
    });
  });

  group('帧解码', () {
    test('解出 0x04 RESULT:V1.3 起 0x00 是成功、0x01 是失败', () {
      // cmd=0x04,TLV 0x01 result_cmd=0x02,TLV 0x02 result_code=0x00
      //
      // 这两个断言的方向在 V1.3 被**对调**了(§2.5)。V1.2 抓的旧日志要反着读:
      // 方向错了不会报任何错,只会把成功显示成失败。
      final ok = EBadgeCodec.decode(
        h('01 04 80 08 00 01 01 00 02 02 01 00 00'),
      );
      expect(ok.isOk, isTrue);
      final r = EBadgeResult.parse(ok.frame!)!;
      expect(r.cmd, EBadgeCmd.h2dSendFile);
      expect(r.succeed, isTrue);

      final fail = EBadgeCodec.decode(
        h('01 04 80 08 00 01 01 00 02 02 01 00 01'),
      );
      expect(EBadgeResult.parse(fail.frame!)!.succeed, isFalse);
    });

    test('V1.3 新增的 0x02 未就绪 / 0x03 忙都不算成功', () {
      for (final code in ['02', '03']) {
        final f = EBadgeCodec.decode(
          h('01 04 80 08 00 01 01 00 12 02 01 00 $code'),
        ).frame!;
        expect(EBadgeResult.parse(f)!.succeed, isFalse);
      }
      expect(EBadgeResultCode.name(0x02), 'NOT_READY');
      expect(EBadgeResultCode.name(0x03), 'BUSY');
    });

    test('字节不足报 incomplete 且不消耗缓冲', () {
      final r = EBadgeCodec.decode(h('01 17 80'));
      expect(r.isOk, isFalse);
      expect(r.error, EBadgeParseError.incomplete);
      expect(r.consumed, 0);

      // 帧头齐全但参数区没收够,同样是 incomplete。
      final r2 = EBadgeCodec.decode(h('01 04 80 08 00 01 01'));
      expect(r2.error, EBadgeParseError.incomplete);
      expect(r2.consumed, 0);
    });

    test('ver / marker 错误时丢 1 字节重新找同步', () {
      final bad = EBadgeCodec.decode(h('FF 17 80 00 00'));
      expect(bad.error, EBadgeParseError.badVersion);
      expect(bad.consumed, 1);

      final badMarker = EBadgeCodec.decode(h('01 17 7F 00 00'));
      expect(badMarker.error, EBadgeParseError.badMarker);
      expect(badMarker.consumed, 1);
    });

    test('TLV 长度越界报 tlvOverflow 并消耗整帧', () {
      // params_len=5,但 TLV 声称 value 有 0xFF 字节
      final r = EBadgeCodec.decode(h('01 04 80 05 00 01 FF 00 AA BB'));
      expect(r.error, EBadgeParseError.tlvOverflow);
      expect(r.consumed, kEBadgeHeaderLength + 5);
    });

    test('未识别 TLV 被保留而非丢帧(§2.1 跳过规则)', () {
      // 0x04 RESULT 里混入一条 type=0x7E 的未知 TLV。末字节是 result_code,
      // V1.3 §2.5 里 0x00 才是成功(V1.2 是 0x01,方向对调过)。
      final r = EBadgeCodec.decode(
        h('01 04 80 0D 00 01 01 00 02 7E 02 00 AA BB 02 01 00 00'),
      );
      expect(r.isOk, isTrue);
      expect(r.frame!.tlvs.length, 3);
      expect(r.frame!.tlvs[1].type, 0x7E);
      // 未知 TLV 不影响已知字段的解析
      expect(EBadgeResult.parse(r.frame!)!.succeed, isTrue);
    });

    test('编码解码往返一致', () {
      final orig = EBadgeRequest.setTime(DateTime(2026, 1, 2, 3, 4, 5));
      final f = EBadgeCodec.decode(orig).frame!;
      expect(f.cmd, EBadgeCmd.h2dSetTime);
      expect(hexOf(f.raw), hexOf(orig));
      expect(hexOf(EBadgeCodec.encode(f.cmd, f.tlvs)), hexOf(orig));
    });

    test('一次 decode 只吃一帧,剩余留给下一次(粘包)', () {
      final two = Uint8List.fromList([
        ...EBadgeRequest.getBattery(),
        ...EBadgeRequest.getStorage(),
      ]);
      final first = EBadgeCodec.decode(two);
      expect(first.frame!.cmd, EBadgeCmd.h2dGetBattery);
      expect(first.consumed, 5);
      final second =
          EBadgeCodec.decode(Uint8List.sublistView(two, first.consumed));
      expect(second.frame!.cmd, EBadgeCmd.h2dGetStorage);
    });
  });

  group('D→H 解包器', () {
    test('0x13 AP_INFO 解出 IP / 端口 / 加密', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hApInfo, [
        EBadgeTlv(
            EBadgeTlvApInfo.ssid, Uint8List.fromList(utf8.encode('eBadge-AP'))),
        EBadgeTlv(EBadgeTlvApInfo.password,
            Uint8List.fromList(utf8.encode('12345678'))),
        EBadgeTlv(EBadgeTlvApInfo.channel, EBadgeCodec.u8(6)),
        EBadgeTlv(EBadgeTlvApInfo.ipv4, Uint8List.fromList([192, 168, 4, 1])),
        EBadgeTlv(EBadgeTlvApInfo.port, EBadgeCodec.u16le(9000)),
        EBadgeTlv(EBadgeTlvApInfo.proto, EBadgeCodec.u8(0x01)),
        EBadgeTlv(EBadgeTlvApInfo.security, EBadgeCodec.u8(1)),
      ]);
      final ap = EBadgeApInfo.parse(EBadgeCodec.decode(frame).frame!)!;
      expect(ap.ssid, 'eBadge-AP');
      expect(ap.ipv4, '192.168.4.1');
      expect(ap.port, 9000);
      expect(ap.isOpen, isFalse);
    });

    test('0x18 BATTERY', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hBattery, [
        EBadgeTlv(EBadgeTlvBattery.percent, EBadgeCodec.u8(87)),
        EBadgeTlv(EBadgeTlvBattery.charge, EBadgeCodec.u8(1)),
      ]);
      final b = EBadgeBattery.parse(EBadgeCodec.decode(frame).frame!)!;
      expect(b.percent, 87);
      expect(EBadgeChargeState.name(b.charge), 'CHARGING');
    });

    test('0x1A STORAGE_INFO 的 uint64 LE 与容量判定 (§2.9)', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hStorageInfo, [
        EBadgeTlv(EBadgeTlvStorage.total, EBadgeCodec.u64le(8 * 1024 * 1024)),
        EBadgeTlv(EBadgeTlvStorage.free, EBadgeCodec.u64le(100000)),
        EBadgeTlv(EBadgeTlvStorage.wpCount, EBadgeCodec.u16le(3)),
        EBadgeTlv(EBadgeTlvStorage.wpUsed, EBadgeCodec.u64le(4096 * 7)),
        EBadgeTlv(EBadgeTlvStorage.fsMargin, EBadgeCodec.u32le(4096)),
      ]);
      final s = EBadgeStorageInfo.parse(EBadgeCodec.decode(frame).frame!)!;
      expect(s.total, 8 * 1024 * 1024);
      expect(s.free, 100000);
      expect(s.wpCount, 3);
      expect(s.fsMargin, EBadgeLimits.fsMargin);
      // free 100000,margin 4096 → 95904 刚好放得下,95905 放不下。
      expect(s.canFit(100000 - 4096), isTrue);
      expect(s.canFit(100000 - 4096 + 1), isFalse);
    });

    test('0x14 PROGRESS 百分比', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hTransferProgress, [
        EBadgeTlv(EBadgeTlvProgress.recv, EBadgeCodec.u32le(512)),
        EBadgeTlv(EBadgeTlvProgress.total, EBadgeCodec.u32le(2048)),
      ]);
      final p = EBadgeProgress.parse(EBadgeCodec.decode(frame).frame!)!;
      expect(p.fraction, 0.25);
    });

    test('0x16 FAIL 的 reason 映射', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hTransferFail, [
        EBadgeTlv(
            EBadgeTlvFail.reason, EBadgeCodec.u8(EBadgeXferError.storageFull)),
      ]);
      final x = EBadgeTransferFail.parse(EBadgeCodec.decode(frame).frame!)!;
      expect(EBadgeXferError.name(x.reason), 'STORAGE_FULL');
      expect(x.detail, isNull);
    });

    test('必选 TLV 缺失时解包器返回 null 而不抛', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hBattery, const []);
      expect(EBadgeBattery.parse(EBadgeCodec.decode(frame).frame!), isNull);
    });
  });

  group('摘要文本', () {
    test('RESULT 摘要带上原命令名', () {
      final f = EBadgeCodec.decode(
        h('01 04 80 08 00 01 01 00 12 02 01 00 00'),
      ).frame!;
      expect(eBadgeDescribe(f), contains('GET_AP_INFO'));
      expect(eBadgeDescribe(f), contains('SUCCEED'));
    });

    test('未知命令给出 TLV 条数而不崩', () {
      final f = EBadgeCodec.decode(h('01 55 80 00 00')).frame!;
      expect(eBadgeDescribe(f), contains('UNKNOWN'));
    });
  });

  group('命令表', () {
    test('保留区间被标记', () {
      expect(EBadgeCmd.isReserved(0x05), isTrue);
      expect(EBadgeCmd.isReserved(0x07), isTrue);
      expect(EBadgeCmd.isReserved(0x0A), isTrue);
      expect(EBadgeCmd.isReserved(0x0F), isTrue);
      expect(EBadgeCmd.isReserved(0x1B), isTrue);
      expect(EBadgeCmd.isReserved(0x2F), isTrue);
      expect(EBadgeCmd.isReserved(0x04), isFalse);
      expect(EBadgeCmd.isReserved(0x1A), isFalse);
      expect(EBadgeCmd.isReserved(0x30), isFalse);
    });

    test('V1.3 把 0x08 / 0x09 从保留段挖出来给了同屏预览', () {
      // V1.2 的保留段是连续的 0x05–0x0F,这两个字节当时是禁用的。
      expect(EBadgeCmd.isReserved(0x08), isFalse);
      expect(EBadgeCmd.isReserved(0x09), isFalse);
      expect(EBadgeCmd.name(0x08), 'JPG_STREAM_OFFER');
      expect(EBadgeCmd.name(0x09), 'JPG_STREAM_DECISION');
    });
  });

  group('0xFF DEBUG(协议外的私有命令)', () {
    test('0xFF 不落在 §3 的保留段里 —— 这是敢占它的前提', () {
      // 协议只保留了 0x05–0x07 / 0x0A–0x0F / 0x1B–0x2F;0x30–0xFF 整段未涉及。
      // 这条断言在于:哪天协议扩了保留段,这里会先红,而不是等设备回错。
      expect(EBadgeCmd.isReserved(0xFF), isFalse);
      expect(EBadgeCmd.name(0xFF), 'DEBUG');
    });

    test('只带 subcmd 时的线上字节 —— 首个 TLV 固定 01 01 00 <val>', () {
      // 01 FF 80 04 00 | 01 01 00 01
      expect(
        hexOf(EBadgeRequest.debug(0x01)),
        hexOf(h('01 FF 80 04 00 01 01 00 01')),
      );
    });

    test('subcmd 可以是任意非零 uint8', () {
      expect(
        hexOf(EBadgeRequest.debug(0x7F)),
        hexOf(h('01 FF 80 04 00 01 01 00 7F')),
      );
      expect(
        hexOf(EBadgeRequest.debug(0xFF)),
        hexOf(h('01 FF 80 04 00 01 01 00 FF')),
      );
    });

    test('载荷 TLV 的 type 从 0x02 起顺序递增', () {
      final f = EBadgeRequest.debug(0x03, values: [
        [0xAA],
        [0xBB, 0xCC],
      ]);
      // subcmd(4B) + 载荷1(3+1) + 载荷2(3+2) = 13B 参数区
      expect(
        hexOf(f),
        hexOf(h('01 FF 80 0D 00 01 01 00 03 02 01 00 AA 03 02 00 BB CC')),
      );
    });

    test('载荷可以多于两条,type 一直往上加', () {
      final f = EBadgeRequest.debug(0x01, values: [
        [0x01],
        [0x02],
        [0x03],
        [0x04],
      ]);
      final d = EBadgeCodec.decode(f).frame!;
      expect(d.tlvs.map((t) => t.type), [0x01, 0x02, 0x03, 0x04, 0x05]);
    });

    test('subcmd=0 被拦 —— 约定从 0x01 起', () {
      expect(() => EBadgeRequest.debug(0), throwsArgumentError);
    });

    test('subcmd 超出 uint8 被拦', () {
      expect(() => EBadgeRequest.debug(0x100), throwsArgumentError);
    });

    test('自己发的 DEBUG 帧不该被判违规', () {
      // 0xFF 走的是 EBadgeCmd.name != 'UNKNOWN' 这条路,所以不会被「不在命令表
      // 内」误报;这条断言就是钉住这一点。
      final d = EBadgeCodec.decode(EBadgeRequest.debug(0x01)).frame!;
      expect(eBadgeValidate(d), isEmpty);
    });

    test('缺 subcmd / subcmd 长度不对 / subcmd=0 都报违规', () {
      // 手工造帧:0xFF 但参数区为空
      final none = EBadgeCodec.decode(h('01 FF 80 00 00')).frame!;
      expect(eBadgeValidate(none).single.hint, contains('缺 subcmd'));

      // subcmd 给了 2 字节
      final long =
          EBadgeCodec.decode(h('01 FF 80 05 00 01 02 00 01 02')).frame!;
      expect(eBadgeValidate(long).single.hint, contains('长度 2B'));

      final zero = EBadgeCodec.decode(h('01 FF 80 04 00 01 01 00 00')).frame!;
      expect(eBadgeValidate(zero).single.hint, contains('从 0x01 起'));
    });

    test('摘要读出 subcmd,并把载荷按十六进制列出来', () {
      final d = EBadgeCodec.decode(
        EBadgeRequest.debug(0x0A, values: [
          [0xDE, 0xAD]
        ]),
      ).frame!;
      final s = eBadgeDescribe(d);
      expect(s, contains('subcmd=0x0A'));
      expect(s, contains('DE AD'));
    });

    test('无载荷时摘要不拖多余的逗号', () {
      final d = EBadgeCodec.decode(EBadgeRequest.debug(0x01)).frame!;
      expect(eBadgeDescribe(d), 'DEBUG:subcmd=0x01');
    });
  });

  group('0xE0–0xE6 OTA 家族(协议外的私有命令)', () {
    test('五个号都不落在 §3 的保留段里 —— 这是敢占它们的前提', () {
      for (final cmd in [0xE0, 0xE1, 0xE4, 0xE5, 0xE6]) {
        expect(EBadgeCmd.isReserved(cmd), isFalse, reason: 'cmd=$cmd');
        // 名字必须登记:eBadgeValidate 见到 'UNKNOWN' 就报「不在命令表内」,
        // 于是自己发的每一帧都会被标红。
        expect(EBadgeCmd.name(cmd), isNot('UNKNOWN'), reason: 'cmd=$cmd');
      }
      expect(EBadgeCmd.name(0xE0), 'OTA_OFFER');
      expect(EBadgeCmd.name(0xE1), 'OTA_DECISION');
      expect(EBadgeCmd.name(0xE4), 'OTA_PROGRESS');
      expect(EBadgeCmd.name(0xE5), 'OTA_DONE');
      expect(EBadgeCmd.name(0xE6), 'OTA_FAIL');
    });

    test('0xE2/0xE3 刻意空着 —— 热点那两条共用 0x12/0x13', () {
      // 空号是**设计**,不是漏登记。哪天有人顺手把它们填上,这条断言先响:
      // 固件那侧只实现了一套热点命令。
      expect(EBadgeCmd.name(0xE2), 'UNKNOWN');
      expect(EBadgeCmd.name(0xE3), 'UNKNOWN');
    });

    test('TLV 号和被平移的那条逐个一致', () {
      // 号一致是眼下的事实,不是约束(§2.4:type 只在本命令上下文里有意义),所以
      // 用断言钉住而不是共享常量 —— 将来 OTA 要加的字段不会也进 0x10。
      expect(EBadgeTlvOtaOffer.name, EBadgeTlvOffer.name);
      expect(EBadgeTlvOtaOffer.type, EBadgeTlvOffer.type);
      expect(EBadgeTlvOtaOffer.size, EBadgeTlvOffer.size);
      expect(EBadgeTlvOtaOffer.crc32, EBadgeTlvOffer.crc32);
      expect(EBadgeTlvOtaDecision.decision, EBadgeTlvDecision.decision);
      expect(EBadgeTlvOtaDecision.reason, EBadgeTlvDecision.reason);
      expect(EBadgeTlvOtaProgress.recv, EBadgeTlvProgress.recv);
      expect(EBadgeTlvOtaProgress.total, EBadgeTlvProgress.total);
      expect(EBadgeTlvOtaDone.fileId, EBadgeTlvDone.fileId);
      expect(EBadgeTlvOtaDone.size, EBadgeTlvDone.size);
      expect(EBadgeTlvOtaDone.name, EBadgeTlvDone.name);
      expect(EBadgeTlvOtaFail.reason, EBadgeTlvFail.reason);
      expect(EBadgeTlvOtaFail.detail, EBadgeTlvFail.detail);
      // 0x05 replace_id 在 OTA 里没有对应物,所以 [EBadgeTlvOtaOffer] 跳过了它。
      expect(EBadgeTlvOffer.replaceId, 0x05);
    });

    test('0xE0 逐字节:name / type=BIN / size / crc32 四条,顺序照 0x10', () {
      // 设备侧解 0xE0 的代码是从 0x10 复制来的,同号同序是这条私有命令唯一的对齐
      // 依据 —— 一旦谁调了顺序,现场表现只是「设备不认」。
      expect(
        hexOf(EBadgeRequest.otaOffer(
            name: 'fw.bin', size: 0x0012D687, crc32: 0xDEADBEEF)),
        hexOf(h('01 E0 80 1B 00 '
            '01 06 00 66 77 2E 62 69 6E '
            '02 01 00 06 '
            '03 04 00 87 D6 12 00 '
            '04 04 00 EF BE AD DE')),
      );
      final d = EBadgeCodec.decode(
              EBadgeRequest.otaOffer(name: 'a.bin', size: 1, crc32: 2))
          .frame!;
      expect(d.tlvs.map((t) => t.type), [0x01, 0x02, 0x03, 0x04]);
      expect(d.value(EBadgeTlvOtaOffer.type)!.single, EBadgeFileType.bin);
      expect(EBadgeCodec.readU32le(d.value(EBadgeTlvOtaOffer.size)!), 1);
      expect(EBadgeCodec.readU32le(d.value(EBadgeTlvOtaOffer.crc32)!), 2);
    });

    test('4 GiB-1 也编得出来,越界和 0 直接拒', () {
      // size 是 uint32:边界值要能编,超界宁可当场抛也不要静默截断成一个小数字 ——
      // 截断后设备会以为包很小,收够就判完成,校验才失败,离根因太远。
      final d = EBadgeCodec.decode(EBadgeRequest.otaOffer(
              name: 'a.bin', size: 0xFFFFFFFF, crc32: 0xFFFFFFFF))
          .frame!;
      expect(
          EBadgeCodec.readU32le(d.value(EBadgeTlvOtaOffer.size)!), 0xFFFFFFFF);
      expect(
          EBadgeCodec.readU32le(d.value(EBadgeTlvOtaOffer.crc32)!), 0xFFFFFFFF);
      for (final bad in [0x100000000, 0, -1]) {
        expect(() => EBadgeRequest.otaOffer(name: 'a', size: bad, crc32: 0),
            throwsArgumentError,
            reason: 'size=$bad');
      }
    });

    test('包名超 §2.8 的 23 字节直接抛,不静默截断', () {
      // 名字现在**上线**(0xE0 的 TLV_NAME + EBXF 头),截断等于悄悄改掉设备落盘的
      // 名字。调用方要裁自己用 fitStr 裁,见 [EBadgeCodec.fitStr]。
      expect(
        () => EBadgeRequest.otaOffer(
            name: 'ebadge_fw_v1.2.3_release.bin', size: 1, crc32: 1),
        throwsArgumentError,
      );
    });

    test('自己发的 0xE0 不该被判违规', () {
      final d = EBadgeCodec.decode(EBadgeRequest.otaOffer(
              name: 'fw.bin', size: 4096, crc32: 0xDEADBEEF))
          .frame!;
      expect(eBadgeValidate(d), isEmpty);
    });

    test('0xE0 缺任何一条必选、size=0、type≠BIN 都要报违规', () {
      // 手工拼的坏帧只能靠 encode 造:otaOffer 自己已经拦住了这些输入。
      EBadgeFrame mk(List<EBadgeTlv> tlvs) =>
          EBadgeCodec.decode(EBadgeCodec.encode(EBadgeCmd.h2dOtaOffer, tlvs))
              .frame!;
      final nm = EBadgeTlv(EBadgeTlvOtaOffer.name,
          EBadgeCodec.str('fw.bin', EBadgeLimits.fileName, 'name'));
      final ty =
          EBadgeTlv(EBadgeTlvOtaOffer.type, EBadgeCodec.u8(EBadgeFileType.bin));
      final sz = EBadgeTlv(EBadgeTlvOtaOffer.size, EBadgeCodec.u32le(4096));
      final cr = EBadgeTlv(EBadgeTlvOtaOffer.crc32, EBadgeCodec.u32le(1));

      expect(eBadgeValidate(mk(const [])), isNotEmpty);
      expect(eBadgeValidate(mk([ty, sz, cr])), isNotEmpty); // 缺 name
      expect(eBadgeValidate(mk([nm, sz, cr])), isNotEmpty); // 缺 type
      expect(eBadgeValidate(mk([nm, ty, cr])), isNotEmpty); // 缺 size
      expect(eBadgeValidate(mk([nm, ty, sz])), isNotEmpty); // 缺 crc32
      // size 只有 2 字节 —— 设备解出来的是个随机数。
      expect(
        eBadgeValidate(mk([
          nm,
          ty,
          EBadgeTlv(EBadgeTlvOtaOffer.size, EBadgeCodec.u16le(4096)),
          cr
        ])),
        isNotEmpty,
      );
      expect(
        eBadgeValidate(mk([
          nm,
          ty,
          EBadgeTlv(EBadgeTlvOtaOffer.size, EBadgeCodec.u32le(0)),
          cr
        ])),
        isNotEmpty,
      );
      // type 报成 JPEG:§5.2 要求它和 EBXF 头里一致,而头里恒为 BIN。
      expect(
        eBadgeValidate(mk([
          nm,
          EBadgeTlv(
              EBadgeTlvOtaOffer.type, EBadgeCodec.u8(EBadgeFileType.jpeg)),
          sz,
          cr
        ])),
        isNotEmpty,
      );
    });

    test('0xE0 摘要把四条都读出来 —— size 十进制,crc32 十六进制', () {
      // size 按十进制(u32 的 hex 谁也换算不动)拿来和本机文件对眼;crc32 反过来按
      // 十六进制 —— 它要和 EBXF 头里那个字面比对。
      final d = EBadgeCodec.decode(EBadgeRequest.otaOffer(
              name: 'fw.bin', size: 1234567, crc32: 0x0012D687))
          .frame!;
      expect(
        eBadgeDescribe(d),
        'OTA_OFFER:name=fw.bin type=BIN size=1234567B crc32=0x0012D687',
      );
    });

    test('0xE0 缺字段的摘要写「缺失」而不是省略', () {
      // 省略会被当成正常 —— 看日志的人只会以为那一行本来就这么短。
      final s = eBadgeDescribe(EBadgeCodec.decode(
          EBadgeCodec.encode(EBadgeCmd.h2dOtaOffer, const [])).frame!);
      expect(s, contains('name=缺失'));
      expect(s, contains('type=缺失'));
      expect(s, contains('size=缺失'));
      expect(s, contains('crc32=缺失'));
    });

    test('将来从 0x06 起补的 TLV,摘要按十六进制原样列出', () {
      final f = EBadgeCodec.encode(EBadgeCmd.h2dOtaOffer, [
        EBadgeTlv(EBadgeTlvOtaOffer.size, EBadgeCodec.u32le(16)),
        EBadgeTlv(0x06, Uint8List.fromList([0xDE, 0xAD])),
      ]);
      final s = eBadgeDescribe(EBadgeCodec.decode(f).frame!);
      expect(s, contains('size=16B'));
      expect(s, contains('0x06='));
      expect(s, contains('DE AD'));
    });

    test('0xE1 / 0xE4 / 0xE6 的摘要换的只是命令名', () {
      // 参数区逐号一致,所以解析器共用;但命令名必须换 —— 两条链路的日志在调试台上
      // 是混着看的,不区分就分不出这条「同意」是谁给的。
      EBadgeFrame mk(int cmd, List<EBadgeTlv> tlvs) =>
          EBadgeCodec.decode(EBadgeCodec.encode(cmd, tlvs)).frame!;

      final dec = [
        EBadgeTlv(EBadgeTlvOtaDecision.decision,
            EBadgeCodec.u8(EBadgeDecision.accept)),
      ];
      final accept = EBadgeDecision.name(EBadgeDecision.accept);
      expect(eBadgeDescribe(mk(EBadgeCmd.d2hOtaDecision, dec)),
          'OTA_DECISION:$accept');
      expect(eBadgeDescribe(mk(EBadgeCmd.d2hTransferDecision, dec)),
          'DECISION:$accept');

      final prog = [
        EBadgeTlv(EBadgeTlvOtaProgress.recv, EBadgeCodec.u32le(50)),
        EBadgeTlv(EBadgeTlvOtaProgress.total, EBadgeCodec.u32le(200)),
      ];
      expect(eBadgeDescribe(mk(EBadgeCmd.d2hOtaProgress, prog)),
          'OTA_PROGRESS:50/200 (25.0%)');
      expect(eBadgeDescribe(mk(EBadgeCmd.d2hTransferProgress, prog)),
          'PROGRESS:50/200 (25.0%)');

      final fail = [
        EBadgeTlv(
            EBadgeTlvOtaFail.reason, EBadgeCodec.u8(EBadgeXferError.verify)),
      ];
      expect(eBadgeDescribe(mk(EBadgeCmd.d2hOtaFail, fail)),
          'OTA_FAIL:${EBadgeXferError.name(EBadgeXferError.verify)}');
      expect(eBadgeDescribe(mk(EBadgeCmd.d2hTransferFail, fail)),
          'FAIL:${EBadgeXferError.name(EBadgeXferError.verify)}');
    });

    test('0xE5 只把 size 当必选 —— file_id 不带也算成功', () {
      // 这是最不该出现的误报:file_id 的语义是「入库成了第几张壁纸」,固件包没有对应
      // 物。拿 0x15 的严格解析去解,一次**已经刷完的升级**会被等到超时报成失败。
      final only = EBadgeCodec.decode(EBadgeCodec.encode(EBadgeCmd.d2hOtaDone, [
        EBadgeTlv(EBadgeTlvOtaDone.size, EBadgeCodec.u32le(4096)),
      ])).frame!;
      final od = EBadgeOtaDone.parse(only);
      expect(od, isNotNull);
      expect(od!.size, 4096);
      expect(od.fileId, isNull);
      expect(od.name, '');
      expect(od.summary, 'size=4096B');
      expect(eBadgeValidate(only), isEmpty);
      expect(eBadgeDescribe(only), 'OTA_DONE:size=4096B');
      // 同一帧拿 0x15 的解析器去解就是 null —— 这条钉住「为什么要分开写一个解析器」。
      expect(EBadgeTransferDone.parse(only), isNull);
    });

    test('0xE5 带上 file_id / name 时一并读出来', () {
      final full = EBadgeCodec.decode(EBadgeCodec.encode(EBadgeCmd.d2hOtaDone, [
        EBadgeTlv(EBadgeTlvOtaDone.fileId, EBadgeCodec.u16le(7)),
        EBadgeTlv(EBadgeTlvOtaDone.size, EBadgeCodec.u32le(2048)),
        EBadgeTlv(EBadgeTlvOtaDone.name,
            EBadgeCodec.str('fw.bin', EBadgeLimits.fileName, 'name')),
      ])).frame!;
      final od = EBadgeOtaDone.parse(full)!;
      expect(od.fileId, 7);
      expect(od.name, 'fw.bin');
      expect(od.summary, 'size=2048B file_id=7 name=fw.bin');
      expect(eBadgeValidate(full), isEmpty);
    });

    test('0xE5 缺 size 才是真的失败', () {
      final none = EBadgeCodec.decode(EBadgeCodec.encode(EBadgeCmd.d2hOtaDone, [
        EBadgeTlv(EBadgeTlvOtaDone.fileId, EBadgeCodec.u16le(7)),
      ])).frame!;
      expect(EBadgeOtaDone.parse(none), isNull);
      expect(eBadgeValidate(none), isNotEmpty);
      expect(eBadgeDescribe(none), 'OTA_DONE(缺 size)');
    });

    test('0xE1 / 0xE4 / 0xE6 缺必选也照 §4 的强度报违规', () {
      EBadgeFrame mk(int cmd, List<EBadgeTlv> tlvs) =>
          EBadgeCodec.decode(EBadgeCodec.encode(cmd, tlvs)).frame!;
      expect(
          eBadgeValidate(mk(EBadgeCmd.d2hOtaDecision, const [])), isNotEmpty);
      expect(
          eBadgeValidate(mk(EBadgeCmd.d2hOtaProgress, const [])), isNotEmpty);
      expect(eBadgeValidate(mk(EBadgeCmd.d2hOtaFail, const [])), isNotEmpty);
      // 齐了就该干净 —— 否则自己模拟设备回帧时满屏红字,校验也就没人看了。
      expect(
        eBadgeValidate(mk(EBadgeCmd.d2hOtaDecision, [
          EBadgeTlv(EBadgeTlvOtaDecision.decision,
              EBadgeCodec.u8(EBadgeDecision.accept)),
        ])),
        isEmpty,
      );
      expect(
        eBadgeValidate(mk(EBadgeCmd.d2hOtaProgress, [
          EBadgeTlv(EBadgeTlvOtaProgress.recv, EBadgeCodec.u32le(1)),
          EBadgeTlv(EBadgeTlvOtaProgress.total, EBadgeCodec.u32le(2)),
        ])),
        isEmpty,
      );
      expect(
        eBadgeValidate(mk(EBadgeCmd.d2hOtaFail, [
          EBadgeTlv(
              EBadgeTlvOtaFail.reason, EBadgeCodec.u8(EBadgeXferError.verify)),
        ])),
        isEmpty,
      );
    });
  });

  group('EBadgeCodec.fitStr —— 按字节裁剪(只给协议管不到的名字用)', () {
    test('没超限就原样返回', () {
      expect(EBadgeCodec.fitStr('a.bin', EBadgeLimits.fileName), 'a.bin');
      expect(EBadgeCodec.fitStr('', 23), '');
    });

    test('超限时裁主干、保后缀', () {
      // 真实固件包名一上手就是 28 字节。
      final out = EBadgeCodec.fitStr(
          'ebadge_fw_v1.2.3_release.bin', EBadgeLimits.fileName);
      expect(utf8.encode(out).length, lessThanOrEqualTo(EBadgeLimits.fileName));
      expect(out.endsWith('.bin'), isTrue);
      expect(out, 'ebadge_fw_v1.2.3_re.bin');
    });

    test('绝不切断多字节序列', () {
      // 每个汉字 3 字节:23 字节的上限不是 3 的整数倍,按字节硬切必然切出半个字符。
      final out = EBadgeCodec.fitStr('固件升级包很长很长很长很长.bin', 23);
      final bytes = utf8.encode(out);
      expect(bytes.length, lessThanOrEqualTo(23));
      // 能原样解回来 = 没有残缺的 UTF-8 序列。
      expect(utf8.decode(bytes), out);
      expect(out, '固件升级包很.bin');
    });

    test('后缀超过 8B 就当它不是后缀(那多半只是名字里带个点)', () {
      final out = EBadgeCodec.fitStr('${'x' * 30}.superlongextension', 23);
      expect(out, 'x' * 23);
    });

    test('裁过的名字能过 EBXF 头,不裁的会被 str 挡下来', () {
      // 这就是 fitStr 存在的理由:EBadgeXferHeader 走的 str 对超长名字直接抛,
      // 而 OTA 的名字来自文件系统,不由协议约束。
      const long = 'ebadge_fw_v1.2.3_release.bin';
      expect(
        () => EBadgeXferHeader.build(
          fileType: EBadgeFileType.bin,
          name: long,
          size: 1,
          crc32: 0,
        ),
        throwsArgumentError,
      );
      final head = EBadgeXferHeader.build(
        fileType: EBadgeFileType.bin,
        name: EBadgeCodec.fitStr(long, EBadgeLimits.fileName),
        size: 1,
        crc32: 0,
      );
      expect(head.length, 40);
    });
  });

  group('Wi-Fi 数据面 (§5)', () {
    test('EBXF 头 40 字节,magic 与小端字段就位', () {
      final head = EBadgeXferHeader.build(
        fileType: EBadgeFileType.jpeg,
        name: 'a.jpg',
        size: 0x00010203,
        crc32: 0x04050607,
      );
      expect(head.length, 40);
      expect(head.sublist(0, 4), h('45 42 58 46')); // 'EBXF'
      expect(head[4], kEBadgeVersion);
      expect(head[5], EBadgeFileType.jpeg);
      expect(head[6], 5); // name_len
      expect(head[7], 0); // reserved
      expect(EBadgeCodec.readU32le(head, 8), 0x00010203);
      expect(EBadgeCodec.readU32le(head, 12), 0x04050607);
      expect(utf8.decode(head.sublist(16, 21)), 'a.jpg');
      // name 区剩余字节零填充
      expect(head.sublist(21, 40).every((b) => b == 0), isTrue);
    });

    test('完全复现 §5.2 文档示例头:wp.jpg / JPEG / 102400B / crc 0x12345678', () {
      final head = EBadgeXferHeader.build(
        fileType: EBadgeFileType.jpeg,
        name: 'wp.jpg',
        size: 102400,
        crc32: 0x12345678,
      );
      expect(
        hexOf(head),
        hexOf(h('45 42 58 46 ' // magic EBXF
            '01 ' // version
            '01 ' // JPEG
            '06 ' // name_len
            '00 ' // reserved
            '00 90 01 00 ' // size 102400
            '78 56 34 12 ' // crc32
            '77 70 2E 6A 70 67 ' // "wp.jpg"
            '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00')),
      );
    });

    test('EBXR 应答解析,magic 不符返回 null', () {
      final ok = EBadgeXferAck.parse(h('45 42 58 52 01 00 00 00'))!;
      expect(ok.succeed, isTrue);
      final bad = EBadgeXferAck.parse(h('45 42 58 52 00 03 00 00'))!;
      expect(bad.succeed, isFalse);
      expect(EBadgeXferError.name(bad.reason), 'STORAGE_FULL');
      expect(EBadgeXferAck.parse(h('00 00 00 00 00 00 00 00')), isNull);
      expect(EBadgeXferAck.parse(h('45 42 58 52')), isNull);
    });

    test('CRC32 用 IEEE 802.3 反射多项式', () {
      // 标准测试向量:"123456789" 的 CRC32 = 0xCBF43926
      expect(eBadgeCrc32(utf8.encode('123456789')), 0xCBF43926);
      expect(eBadgeCrc32(const []), 0);
    });
  });

  group('同屏预览数据面 (§6.2,V1.3 新增)', () {
    test('完全复现 §6.2 文档示例头:14B / JPEG Stream / 400B / crc 0x12345678', () {
      final head = EBadgeStreamHeader.build(
        size: 400,
        crc32: 0x12345678,
      );
      expect(head.length, 14);
      expect(
        hexOf(head),
        hexOf(h('45 42 58 46 ' // magic EBXF —— 与 §5.2 完全相同
            '01 ' // version
            '04 ' // JPEG Stream
            '90 01 00 00 ' // size 400(本帧 payload)
            '78 56 34 12')), // crc32(本帧 payload)
      );
    });

    test('magic 与 §5.2 同一个,只能靠头长区分两种会话', () {
      // 这是协议本身的设计,不是实现取巧:两个头的前 5 字节逐字节相同,收发两侧
      // 必须按会话类型(0x10 Offer 还是 0x08 Offer)决定拿哪个头去解。
      final stream = EBadgeStreamHeader.build(size: 1, crc32: 0);
      final xfer = EBadgeXferHeader.build(
        fileType: EBadgeFileType.jpegStream,
        name: 'a',
        size: 1,
        crc32: 0,
      );
      expect(stream.sublist(0, 5), xfer.sublist(0, 5));
      expect(EBadgeStreamHeader.length, 14);
      expect(EBadgeXferHeader.length, 40);
    });

    test('没有 name / name_len 字段 —— 流头到 14 字节就结束', () {
      // §5.2 的 name_len 在偏移 6,而这里偏移 6 已经是 size 的低字节了。
      final head = EBadgeStreamHeader.build(size: 0x11223344, crc32: 0);
      expect(EBadgeCodec.readU32le(head, 6), 0x11223344);
    });

    test('parse 能把自己发出去的头再读一遍(调试页要核对)', () {
      final head = EBadgeStreamHeader.build(size: 65535, crc32: 0xAABBCCDD);
      final p = EBadgeStreamHeader.parse(head)!;
      expect(p.fileType, EBadgeFileType.jpegStream);
      expect(p.size, 65535);
      expect(p.crc32, 0xAABBCCDD);
    });

    test('magic / version 不符或字节不足都返回 null', () {
      expect(
          EBadgeStreamHeader.parse(
              h('45 42 58 52 01 04 00 00 00 00 00 00 00 00')),
          isNull); // EBXR 不是 EBXF
      expect(
          EBadgeStreamHeader.parse(
              h('45 42 58 46 02 04 00 00 00 00 00 00 00 00')),
          isNull); // version=2
      expect(EBadgeStreamHeader.parse(h('45 42 58 46 01 04 00')), isNull);
    });
  });

  group('合规校验 eBadgeValidate', () {
    /// 便捷:把帧解出来直接校验。
    List<String> check(Uint8List frame) =>
        eBadgeValidate(EBadgeCodec.decode(frame).frame!)
            .map((v) => v.hint)
            .toList();

    test('组包器产出的帧一律合规 —— 校验器不能冤枉自己人', () {
      expect(check(EBadgeRequest.getBattery()), isEmpty);
      expect(check(EBadgeRequest.getStorage()), isEmpty);
      expect(check(EBadgeRequest.getApInfo()), isEmpty);
      expect(check(EBadgeRequest.setTime(DateTime(2026, 8, 13, 20, 15, 30))),
          isEmpty);
      expect(
        check(EBadgeRequest.sendMsg(
            appName: 'WeChat', title: 'Tom', text: 'hi', date: '08-13 20:15')),
        isEmpty,
      );
      expect(
        check(EBadgeRequest.transferOffer(
            name: 'a.jpg',
            type: EBadgeFileType.jpeg,
            size: 1024,
            crc32: 0xDEADBEEF)),
        isEmpty,
      );
      expect(
        check(EBadgeRequest.otaOffer(
            name: 'fw.bin', size: 1024, crc32: 0xDEADBEEF)),
        isEmpty,
      );
    });

    test('保留段 cmd 被标出 (§3)', () {
      final v = check(h('01 0A 80 00 00'));
      expect(v.single, contains('保留段'));
    });

    test('命令表外的 cmd 被标出', () {
      expect(check(h('01 55 80 00 00')).single, contains('不在 §3 命令表内'));
    });

    test('无参数查询命令带了 TLV 属违规 (§4)', () {
      final frame = EBadgeCodec.encode(
        EBadgeCmd.h2dGetBattery,
        [EBadgeTlv(0x01, EBadgeCodec.u8(1))],
      );
      expect(check(frame).single, contains('无参数命令'));
    });

    test('重复 TLV type 被标出 (§2.4)', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hBattery, [
        EBadgeTlv(EBadgeTlvBattery.percent, EBadgeCodec.u8(50)),
        EBadgeTlv(EBadgeTlvBattery.charge, EBadgeCodec.u8(1)),
        EBadgeTlv(EBadgeTlvBattery.percent, EBadgeCodec.u8(60)),
      ]);
      expect(check(frame).single, contains('重复出现'));
    });

    test('必选 TLV 缺失被标出', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hBattery, const []);
      final v = check(frame);
      expect(v.length, 2);
      expect(v.every((s) => s.contains('缺必选')), isTrue);
    });

    test('SET_TIME 各字段越界 (§4.1)', () {
      // year=1999(CF 07)、month=13、day=32、hour=24、min=60、sec=60、dow=8
      final frame = EBadgeCodec.encode(EBadgeCmd.h2dSetTime, [
        EBadgeTlv(
          EBadgeTlvSetTime.dateTime,
          h('CF 07 0D 20 18 3C 3C 08'),
        ),
      ]);
      final v = check(frame);
      expect(v.any((s) => s.contains('year=1999')), isTrue);
      expect(v.any((s) => s.contains('month=13')), isTrue);
      expect(v.any((s) => s.contains('day=32')), isTrue);
      expect(v.any((s) => s.contains('hour=24')), isTrue);
      expect(v.any((s) => s.contains('minute=60')), isTrue);
      expect(v.any((s) => s.contains('second=60')), isTrue);
      expect(v.any((s) => s.contains('day_of_week=8')), isTrue);
    });

    test('SET_TIME 的 TLV 长度不是 8B 时不再逐字段解读', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.h2dSetTime, [
        EBadgeTlv(EBadgeTlvSetTime.dateTime, Uint8List(6)),
      ]);
      // 只报长度这一条,不能因为读不到字段而炸出一串误报。
      expect(check(frame).single, contains('长度 6B,应为 8B'));
    });

    test('SEND_MSG 超 23B 字段被标出,比的是字节不是字符 (§2.8)', () {
      // 8 个中文 = 24B,只有 8 个「字」但超限。
      final frame = EBadgeCodec.encode(EBadgeCmd.h2dSendMsg, [
        EBadgeTlv(
            EBadgeTlvSendMsg.appName, Uint8List.fromList(utf8.encode('A'))),
        EBadgeTlv(EBadgeTlvSendMsg.title, Uint8List.fromList(utf8.encode('B'))),
        EBadgeTlv(
            EBadgeTlvSendMsg.text, Uint8List.fromList(utf8.encode('一二三四五六七八'))),
      ]);
      expect(check(frame).single, contains('24B 超出上限 23B'));
    });

    test('TRANSFER_OFFER 的 file_type=0x00 与表外值都被标出', () {
      Uint8List offer(int type) =>
          EBadgeCodec.encode(EBadgeCmd.h2dTransferOffer, [
            EBadgeTlv(
                EBadgeTlvOffer.name, Uint8List.fromList(utf8.encode('a.jpg'))),
            EBadgeTlv(EBadgeTlvOffer.type, EBadgeCodec.u8(type)),
            EBadgeTlv(EBadgeTlvOffer.size, EBadgeCodec.u32le(1)),
            EBadgeTlv(EBadgeTlvOffer.crc32, EBadgeCodec.u32le(1)),
          ]);
      expect(check(offer(0x00)).single, contains('不得使用 UNSPECIFIED'));
      expect(check(offer(0x09)).single, contains('不在 §2.7 文件类型表内'));
      expect(check(offer(EBadgeFileType.png)), isEmpty);
    });

    test('RESULT 的 result_code 只允许 0x00–0x03 (§2.5)', () {
      // V1.3 把上界从 0x01 抬到 0x03(新增未就绪 / 忙),0x02 / 0x03 不再是违规。
      for (final code in ['00', '01', '02', '03']) {
        expect(check(h('01 04 80 08 00 01 01 00 02 02 01 00 $code')), isEmpty);
      }
      expect(
        check(h('01 04 80 08 00 01 01 00 02 02 01 00 07')).single,
        contains('result_code=0x07'),
      );
    });

    test('STREAM_OFFER 必须齐 name / type / fps,且 fps≠0 (§4.5)', () {
      Uint8List offer({String? name, int? type, int? fps}) =>
          EBadgeCodec.encode(EBadgeCmd.h2dJpgStreamOffer, [
            if (name != null)
              EBadgeTlv(EBadgeTlvStreamOffer.name,
                  Uint8List.fromList(utf8.encode(name))),
            if (type != null)
              EBadgeTlv(EBadgeTlvStreamOffer.type, EBadgeCodec.u8(type)),
            if (fps != null)
              EBadgeTlv(EBadgeTlvStreamOffer.fps, EBadgeCodec.u8(fps)),
          ]);

      expect(
        check(offer(name: 's.jpg', type: EBadgeFileType.jpegStream, fps: 15)),
        isEmpty,
      );
      // 少哪个就报哪个,不能因为第一个缺了就不查后面的。
      expect(check(offer(type: EBadgeFileType.jpegStream, fps: 15)).single,
          contains('TLV_XFER_NAME'));
      expect(check(offer(name: 's.jpg', fps: 15)).single,
          contains('TLV_XFER_TYPE'));
      expect(
        check(offer(name: 's.jpg', type: EBadgeFileType.jpegStream)).single,
        contains('TLV_XFER_FPS'),
      );
      // fps=0 语法合法但语义上是「一帧都不发」。
      expect(
        check(offer(name: 's.jpg', type: EBadgeFileType.jpegStream, fps: 0))
            .single,
        contains('fps=0'),
      );
      expect(
        check(offer(name: 's.jpg', type: EBadgeFileType.unspecified, fps: 15))
            .single,
        contains('不得使用 UNSPECIFIED'),
      );
    });

    test('STREAM_DECISION:拒绝要给原因,协商要给帧率 (§4.6)', () {
      Uint8List dec(int d, {int? reason, int? fps}) =>
          EBadgeCodec.encode(EBadgeCmd.d2hJpgStreamDecision, [
            EBadgeTlv(EBadgeTlvStreamDecision.decision, EBadgeCodec.u8(d)),
            if (reason != null)
              EBadgeTlv(EBadgeTlvStreamDecision.reason, EBadgeCodec.u8(reason)),
            if (fps != null)
              EBadgeTlv(EBadgeTlvStreamDecision.fps, EBadgeCodec.u8(fps)),
          ]);

      expect(check(dec(EBadgeDecision.accept)), isEmpty);
      expect(check(dec(EBadgeDecision.reject)).single,
          contains('缺 TLV_XFER_REASON'));
      expect(
        check(dec(EBadgeDecision.reject, reason: EBadgeXferError.busy)),
        isEmpty,
      );
      // 协商却不给新帧率,App 无从下一步。
      expect(
        check(dec(EBadgeDecision.negotiate)).single,
        contains('协商不出帧率'),
      );
      expect(check(dec(EBadgeDecision.negotiate, fps: 8)), isEmpty);
      // 0x11 的 decision=2 是「超时」,0x09 的 2 是「协商」—— 同一字节两种含义,
      // 所以 3 才是本命令的第一个非法值。
      expect(check(dec(3)).any((s) => s.contains('decision=3')), isTrue);
    });

    test('DECISION 非 ACCEPT 必须带原因 (§4.8)', () {
      Uint8List dec(int d, {int? reason}) =>
          EBadgeCodec.encode(EBadgeCmd.d2hTransferDecision, [
            EBadgeTlv(EBadgeTlvDecision.decision, EBadgeCodec.u8(d)),
            if (reason != null)
              EBadgeTlv(EBadgeTlvDecision.reason, EBadgeCodec.u8(reason)),
          ]);
      // 同意时无需 reason。
      expect(check(dec(EBadgeDecision.accept)), isEmpty);
      expect(
          check(dec(EBadgeDecision.reject)).single, contains('缺 TLV_REASON'));
      expect(
        check(dec(EBadgeDecision.reject, reason: EBadgeXferError.userReject)),
        isEmpty,
      );
      expect(check(dec(5)).any((s) => s.contains('decision=5')), isTrue);
    });

    test('AP_INFO 的信道 / proto / security / 密码规则 (§4.9)', () {
      Uint8List ap({
        int channel = 6,
        int proto = 0x01,
        int security = 1,
        String password = '12345678',
      }) =>
          EBadgeCodec.encode(EBadgeCmd.d2hApInfo, [
            EBadgeTlv(EBadgeTlvApInfo.ssid,
                Uint8List.fromList(utf8.encode('eBadge-AP'))),
            EBadgeTlv(EBadgeTlvApInfo.password,
                Uint8List.fromList(utf8.encode(password))),
            EBadgeTlv(EBadgeTlvApInfo.channel, EBadgeCodec.u8(channel)),
            EBadgeTlv(
                EBadgeTlvApInfo.ipv4, Uint8List.fromList([192, 168, 4, 1])),
            EBadgeTlv(EBadgeTlvApInfo.port, EBadgeCodec.u16le(9000)),
            EBadgeTlv(EBadgeTlvApInfo.proto, EBadgeCodec.u8(proto)),
            EBadgeTlv(EBadgeTlvApInfo.security, EBadgeCodec.u8(security)),
          ]);

      expect(check(ap()), isEmpty);
      expect(check(ap(channel: 14)).single, contains('channel=14'));
      expect(check(ap(proto: 0x02)).single, contains('唯一合法值是 0x01'));
      expect(check(ap(security: 2)).single, contains('security=2'));
      // WPA2 但密码为空 / 过短。
      expect(check(ap(password: '')).single, contains('没给密码'));
      expect(check(ap(password: '1234')).single, contains('至少 8B'));
      // 开放网络允许空密码。
      expect(check(ap(security: 0, password: '')), isEmpty);
    });

    test('PROGRESS 的 recv 不得超过 total', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hTransferProgress, [
        EBadgeTlv(EBadgeTlvProgress.recv, EBadgeCodec.u32le(2048)),
        EBadgeTlv(EBadgeTlvProgress.total, EBadgeCodec.u32le(1024)),
      ]);
      expect(check(frame).single, contains('进度不可能超过总量'));
    });

    test('DONE 的 file_id 不得为 0 (§4.11)', () {
      Uint8List done(int id) => EBadgeCodec.encode(EBadgeCmd.d2hTransferDone, [
            EBadgeTlv(EBadgeTlvDone.fileId, EBadgeCodec.u16le(id)),
            EBadgeTlv(EBadgeTlvDone.size, EBadgeCodec.u32le(100)),
          ]);
      expect(check(done(0)).single, contains('file_id=0'));
      expect(check(done(1)), isEmpty);
    });

    test('FAIL 的 reason 必须在 §2.6 表内', () {
      Uint8List fail(int r) => EBadgeCodec.encode(EBadgeCmd.d2hTransferFail, [
            EBadgeTlv(EBadgeTlvFail.reason, EBadgeCodec.u8(r)),
          ]);
      expect(check(fail(EBadgeXferError.storageFull)), isEmpty);
      expect(check(fail(0x00)).single, contains('不在 §2.6'));
      expect(check(fail(0x20)).single, contains('不在 §2.6'));
    });

    test('BATTERY 的百分比与充电态取值 (§4.13)', () {
      Uint8List bat(int pct, int chg) =>
          EBadgeCodec.encode(EBadgeCmd.d2hBattery, [
            EBadgeTlv(EBadgeTlvBattery.percent, EBadgeCodec.u8(pct)),
            EBadgeTlv(EBadgeTlvBattery.charge, EBadgeCodec.u8(chg)),
          ]);
      expect(check(bat(100, 2)), isEmpty);
      expect(check(bat(101, 0)).single, contains('percent=101'));
      expect(check(bat(50, 3)).single, contains('charge=3'));
    });

    test('STORAGE_INFO 的 free≤total 与 fs_margin 固定值 (§2.9)', () {
      Uint8List st(
              {int total = 8388608, int free = 100000, int margin = 4096}) =>
          EBadgeCodec.encode(EBadgeCmd.d2hStorageInfo, [
            EBadgeTlv(EBadgeTlvStorage.total, EBadgeCodec.u64le(total)),
            EBadgeTlv(EBadgeTlvStorage.free, EBadgeCodec.u64le(free)),
            EBadgeTlv(EBadgeTlvStorage.wpCount, EBadgeCodec.u16le(3)),
            EBadgeTlv(EBadgeTlvStorage.wpUsed, EBadgeCodec.u64le(28672)),
            EBadgeTlv(EBadgeTlvStorage.fsMargin, EBadgeCodec.u32le(margin)),
          ]);
      expect(check(st()), isEmpty);
      expect(check(st(free: 9999999)).single, contains('> total'));
      expect(check(st(margin: 512)).single, contains('fs_margin=512'));
    });

    test('未知 TLV 不算违规 —— §2.1 要求跳过而非报错', () {
      final frame = EBadgeCodec.encode(EBadgeCmd.d2hBattery, [
        EBadgeTlv(EBadgeTlvBattery.percent, EBadgeCodec.u8(80)),
        EBadgeTlv(EBadgeTlvBattery.charge, EBadgeCodec.u8(1)),
        EBadgeTlv(0x7E, Uint8List.fromList([0xAA, 0xBB])),
      ]);
      expect(check(frame), isEmpty);
    });

    test('ver 非 0x01 被标出 (§2.3)', () {
      // decode 会先拒 ver 错的帧,所以直接构造 EBadgeFrame 走语义校验。
      final f = EBadgeFrame(
        ver: 0x02,
        cmd: EBadgeCmd.h2dGetBattery,
        params: Uint8List(0),
        tlvs: const [],
        raw: h('02 17 80 00 00'),
      );
      expect(eBadgeValidate(f).single.hint, contains('ver=0x02'));
    });
  });

  group('小端原语', () {
    test('u16 / u32 / u64 写入与回读对称', () {
      expect(EBadgeCodec.readU16le(EBadgeCodec.u16le(0xBEEF)), 0xBEEF);
      expect(EBadgeCodec.readU32le(EBadgeCodec.u32le(0xDEADBEEF)), 0xDEADBEEF);
      expect(
        EBadgeCodec.readU64le(EBadgeCodec.u64le(0x0102030405060708)),
        0x0102030405060708,
      );
    });

    test('u16le 低字节在前', () {
      expect(EBadgeCodec.u16le(0x1234), h('34 12'));
    });

    test('hex 超长时截断并标注总长', () {
      final s = EBadgeCodec.hex(Uint8List(100), max: 4);
      expect(s, contains('共 100B'));
    });
  });
}
