import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ebadge_protocol.dart';
import 'package:honeybox/services/ebadge_stream_transport.dart';

/// §6 同屏预览数据面的测试。
///
/// 全部走**真的** loopback ServerSocket:这个类的价值就在「连续多帧写到一条长连
/// 接上」和「应答可选但必须一直读」这两件事上,而这两件事恰恰是假 socket 最难模
/// 拟对的(尤其是 onDone 的时机)。
///
/// 与 `ebadge_wifi_transport_test.dart` 的关键差别:那边是「收够 N 字节就回应答
/// 并关连接」,这边服务端**收完不能关** —— §6 的连接要一直开着,一关就等于设备
/// 主动断开,后续推帧全会失败。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServerSocket server;

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async => server.close());

  /// 起一个「只收不关」的服务端,累积收到的所有字节。
  ///
  /// [onBytes] 每次收到数据后回调,用于在测试里按累积量做动作(回 EBXR、关连接)。
  List<int> serve({void Function(Socket s, List<int> buf)? onBytes}) {
    final buf = <int>[];
    server.listen((socket) {
      socket.listen((data) {
        buf.addAll(data);
        onBytes?.call(socket, buf);
      });
    });
    return buf;
  }

  Uint8List frame(int n, [int fill = 0x41]) =>
      Uint8List.fromList(List.filled(n, fill));

  Uint8List ackOk() => Uint8List.fromList([0x45, 0x42, 0x58, 0x52, 1, 0, 0, 0]);
  Uint8List ackFail(int reason) =>
      Uint8List.fromList([0x45, 0x42, 0x58, 0x52, 0, reason, 0, 0]);

  Future<EBadgeStreamTransport> connected() async {
    final t = EBadgeStreamTransport();
    expect(
      await t.connect(ip: server.address.address, port: server.port),
      isNull,
    );
    return t;
  }

  /// 等到 [test] 成立。socket 的收发是异步的,固定 delay 要么慢要么偶发失败。
  Future<void> until(bool Function() test) async {
    for (var i = 0; i < 200; i++) {
      if (test()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('等待条件超时');
  }

  group('connect', () {
    test('连不上时返回人话,不抛异常', () async {
      // 端口 1 上不会有监听;给短超时免得测试卡住。
      final t = EBadgeStreamTransport();
      final err = await t.connect(
        ip: '127.0.0.1',
        port: 1,
        timeout: const Duration(milliseconds: 300),
      );
      expect(err, contains('TCP 连接'));
      expect(t.connected, isFalse);
    });

    test('重复 connect 被拦 —— §6.7 一条连接只接一个客户端', () async {
      final t = await connected();
      expect(
        await t.connect(ip: server.address.address, port: server.port),
        contains('先 close'),
      );
      await t.close();
    });

    test('connect 会把计数器归零,同一实例能重连', () async {
      serve();
      final t = await connected();
      await t.sendFrame(frame(10));
      expect(t.framesSent, 1);

      await t.close();
      expect(await t.connect(ip: server.address.address, port: server.port),
          isNull);
      expect(t.framesSent, 0);
      expect(t.bytesSent, 0);
      expect(t.lastAck, isNull);
      expect(t.peerClosed, isNull);
      await t.close();
    });
  });

  group('sendFrame', () {
    test('线上字节 = 14B 流头 + payload,逐帧首尾相接', () async {
      final got = serve();
      final t = await connected();

      final a = frame(100, 0x41);
      final b = frame(50, 0x42);
      expect(await t.sendFrame(a), isNull);
      expect(await t.sendFrame(b), isNull);
      await until(() => got.length >= 14 * 2 + 150);

      // 帧 1
      final h1 =
          EBadgeStreamHeader.parse(Uint8List.fromList(got.sublist(0, 14)))!;
      expect(h1.fileType, EBadgeFileType.jpegStream);
      expect(h1.size, 100);
      expect(h1.crc32, eBadgeCrc32(a));
      expect(got.sublist(14, 114).every((x) => x == 0x41), isTrue);

      // 帧 2 紧跟其后,中间没有任何分隔字节 —— 接收侧完全靠头里的 size 切帧。
      final h2 =
          EBadgeStreamHeader.parse(Uint8List.fromList(got.sublist(114, 128)))!;
      expect(h2.size, 50);
      expect(h2.crc32, eBadgeCrc32(b));
      expect(got.length, 14 * 2 + 150);

      await t.close();
    });

    test('crc32 默认按本帧 payload 自算,每帧各不相同', () async {
      final got = serve();
      final t = await connected();
      await t.sendFrame(frame(8, 0x01));
      await t.sendFrame(frame(8, 0x02));
      await until(() => got.length >= 44);

      final c1 = EBadgeCodec.readU32le(Uint8List.fromList(got), 10);
      final c2 = EBadgeCodec.readU32le(Uint8List.fromList(got), 22 + 10);
      expect(c1, eBadgeCrc32(frame(8, 0x01)));
      expect(c2, eBadgeCrc32(frame(8, 0x02)));
      expect(c1, isNot(c2));
      await t.close();
    });

    test('显式传 crc32 可构造坏帧(调试要看设备怎么反应)', () async {
      final got = serve();
      final t = await connected();
      await t.sendFrame(frame(16), crc32: 0xDEADBEEF);
      await until(() => got.length >= 30);
      expect(EBadgeCodec.readU32le(Uint8List.fromList(got), 10), 0xDEADBEEF);
      await t.close();
    });

    test('累计计数只算 payload,不含 14B 头', () async {
      serve();
      final t = await connected();
      await t.sendFrame(frame(100));
      await t.sendFrame(frame(200));
      expect(t.framesSent, 2);
      expect(t.bytesSent, 300);
      await t.close();
    });

    test('空 payload 被拦 —— §6.2 的 size=0 没有意义', () async {
      serve();
      final t = await connected();
      expect(await t.sendFrame(Uint8List(0)), contains('空帧'));
      expect(t.framesSent, 0);
      await t.close();
    });

    test('未连接就推帧,给的是原因而不是异常', () async {
      final t = EBadgeStreamTransport();
      expect(await t.sendFrame(frame(4)), 'TCP 未连接');
    });

    test('帧间隔超 §6.4 的 3s 会报出来,但帧照发', () async {
      // 不真等 3 秒:frameGapLimit 是常量,这里验的是「首帧不判间隔」这条 ——
      // last == null 时 gap 恒为 0,不该报。真超时路径由常量本身保证。
      expect(EBadgeStreamTransport.frameGapLimit, const Duration(seconds: 3));
      serve();
      final t = await connected();
      expect(await t.sendFrame(frame(4)), isNull);
      await t.close();
    });
  });

  group('EBXR 应答(§6.3 可选)', () {
    test('设备不回应答是正常情况,lastAck 保持 null', () async {
      serve();
      final t = await connected();
      await t.sendFrame(frame(32));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(t.lastAck, isNull);
      expect(t.connected, isTrue); // 没应答不等于连接坏了
      await t.close();
    });

    test('设备回应答时被读出来,多条只留最后一条', () async {
      var replied = 0;
      serve(onBytes: (s, buf) {
        // 每收到一帧回一条应答:第一条成功,第二条失败。
        if (buf.length >= 14 + 8 && replied == 0) {
          replied = 1;
          s.add(ackOk());
        } else if (buf.length >= (14 + 8) * 2 && replied == 1) {
          replied = 2;
          s.add(ackFail(EBadgeXferError.verify));
        }
      });

      final t = await connected();
      await t.sendFrame(frame(8));
      await until(() => t.lastAck != null);
      expect(t.lastAck!.succeed, isTrue);

      await t.sendFrame(frame(8));
      await until(() => t.lastAck?.succeed == false);
      expect(EBadgeXferError.name(t.lastAck!.reason), 'VERIFY');
      await t.close();
    });

    test('杂字节不会被当成应答,也不会卡住后续解析', () async {
      serve(onBytes: (s, buf) {
        if (buf.length >= 14 + 4) {
          // 先来 8 个非 EBXR 字节,再来一条真应答。
          s.add(Uint8List.fromList(List.filled(8, 0x99)));
          s.add(ackOk());
        }
      });
      final t = await connected();
      await t.sendFrame(frame(4));
      await until(() => t.lastAck != null);
      expect(t.lastAck!.succeed, isTrue);
      await t.close();
    });
  });

  group('设备主动断开', () {
    test('对端关连接后 peerClosed 有值,再推帧直接失败', () async {
      serve(onBytes: (s, buf) {
        if (buf.length >= 14 + 4) s.destroy();
      });
      final t = await connected();
      await t.sendFrame(frame(4));
      await until(() => t.peerClosed != null);

      expect(t.connected, isFalse);
      // 断了之后不再往一条死连接上写 —— 那样 framesSent 会继续涨,看着像在推流。
      final before = t.framesSent;
      expect(await t.sendFrame(frame(4)), t.peerClosed);
      expect(t.framesSent, before);
      await t.close();
    });
  });

  group('close', () {
    test('幂等:没连过、连过、连过又关过都能调', () async {
      final fresh = EBadgeStreamTransport();
      await expectLater(fresh.close(), completes);

      serve();
      final t = await connected();
      await t.sendFrame(frame(4));
      await expectLater(t.close(), completes);
      await expectLater(t.close(), completes);
      expect(t.connected, isFalse);
    });
  });
}
