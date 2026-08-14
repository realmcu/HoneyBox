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
      // §4.7:01 12 80 00 00
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

  group('0x10 TRANSFER_OFFER (§4.5)', () {
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

  group('帧解码', () {
    test('解出 0x04 RESULT:0x00 是失败、0x01 是成功', () {
      // cmd=0x04,TLV 0x01 result_cmd=0x02,TLV 0x02 result_code=0x01
      final ok = EBadgeCodec.decode(
        h('01 04 80 08 00 01 01 00 02 02 01 00 01'),
      );
      expect(ok.isOk, isTrue);
      final r = EBadgeResult.parse(ok.frame!)!;
      expect(r.cmd, EBadgeCmd.h2dSendFile);
      expect(r.succeed, isTrue);

      final fail = EBadgeCodec.decode(
        h('01 04 80 08 00 01 01 00 02 02 01 00 00'),
      );
      expect(EBadgeResult.parse(fail.frame!)!.succeed, isFalse);
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
      // 0x04 RESULT 里混入一条 type=0x7E 的未知 TLV
      final r = EBadgeCodec.decode(
        h('01 04 80 0D 00 01 01 00 02 7E 02 00 AA BB 02 01 00 01'),
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
        h('01 04 80 08 00 01 01 00 12 02 01 00 01'),
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
      expect(EBadgeCmd.isReserved(0x0F), isTrue);
      expect(EBadgeCmd.isReserved(0x1B), isTrue);
      expect(EBadgeCmd.isReserved(0x2F), isTrue);
      expect(EBadgeCmd.isReserved(0x04), isFalse);
      expect(EBadgeCmd.isReserved(0x1A), isFalse);
      expect(EBadgeCmd.isReserved(0x30), isFalse);
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

    test('RESULT 的 result_code 只允许 0x00 / 0x01 (§2.5)', () {
      expect(check(h('01 04 80 08 00 01 01 00 02 02 01 00 01')), isEmpty);
      expect(
        check(h('01 04 80 08 00 01 01 00 02 02 01 00 07')).single,
        contains('result_code=0x07'),
      );
    });

    test('DECISION 非 ACCEPT 必须带原因 (§4.6)', () {
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

    test('AP_INFO 的信道 / proto / security / 密码规则 (§4.7)', () {
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

    test('DONE 的 file_id 不得为 0 (§4.9)', () {
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

    test('BATTERY 的百分比与充电态取值 (§4.11)', () {
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
