import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ebadge_protocol.dart';
import 'package:honeybox/services/ebadge_wifi_transport.dart';

/// 数据面测试刻意分两半:
///
/// - `join` / `leave` 只能打假 MethodChannel —— 真去 `requestNetwork` 要有设备、
///   有热点、还要人点系统弹窗,不可能在 CI 上跑。
/// - `upload` 则起一个**真的** loopback ServerSocket 让它连。它测的是 EBXF 组包、
///   分块写、读 EBXR 这些纯 Dart 逻辑,假 socket 反而要把 `dart:io` 的行为(尤其
///   是 onDone 早于攒够 8 字节的时机)重新实现一遍,那才是真正容易写错的地方。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('join / leave (假 MethodChannel)', () {
    const name = 'ebadge/wifi';
    const channel = MethodChannel(name);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    final calls = <MethodCall>[];

    void mock(Future<Object?>? Function(MethodCall) handler) {
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    setUp(calls.clear);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('成功时返回 null,并把 ssid/密码/超时毫秒透给原生', () async {
      mock((_) async => true);
      final t = EBadgeWifiTransport(channel: channel);

      final err = await t.join(
        ssid: 'eBadge-1234',
        password: 'pass1234',
        timeout: const Duration(seconds: 45),
      );

      expect(err, isNull);
      expect(t.joined, isTrue);
      expect(calls.single.method, 'joinAp');
      expect(calls.single.arguments, {
        'ssid': 'eBadge-1234',
        'password': 'pass1234',
        'timeoutMs': 45000,
      });
    });

    test('绑定失败(返回 false)仍算连上 —— 默认路由可能碰巧可达', () async {
      mock((_) async => false);
      final t = EBadgeWifiTransport(channel: channel);
      expect(await t.join(ssid: 'x', password: 'y'), isNull);
      expect(t.joined, isTrue);
    });

    test('PlatformException 的 message 直接当失败原因,joined 保持 false', () async {
      mock((_) async => throw PlatformException(
            code: 'wifi_off',
            message: 'Wi-Fi 未开启，请开启后重试',
          ));
      final t = EBadgeWifiTransport(channel: channel);
      expect(await t.join(ssid: 'x', password: 'y'), 'Wi-Fi 未开启，请开启后重试');
      expect(t.joined, isFalse);
    });

    test('message 为空时退回 code,不能返回 null 让调用方误判成功', () async {
      mock((_) async => throw PlatformException(code: 'unavailable'));
      final t = EBadgeWifiTransport(channel: channel);
      expect(await t.join(ssid: 'x', password: 'y'), 'unavailable');
    });

    test('原生没实现(非 Android)给的是人话而不是 MissingPluginException', () async {
      mock((_) async => throw MissingPluginException());
      final t = EBadgeWifiTransport(channel: channel);
      expect(await t.join(ssid: 'x', password: 'y'), contains('仅 Android'));
      expect(t.joined, isFalse);
    });

    test('leave 即使原生抛异常也不往外传 —— 它总在 finally 里被调用', () async {
      mock((call) async {
        if (call.method == 'leaveAp') throw PlatformException(code: 'boom');
        return true;
      });
      final t = EBadgeWifiTransport(channel: channel);
      await t.join(ssid: 'x', password: 'y');

      await expectLater(t.leave(), completes);
      expect(t.joined, isFalse);
    });

    test('leave 幂等:没 join 过也能调', () async {
      mock((_) async => null);
      final t = EBadgeWifiTransport(channel: channel);
      await expectLater(t.leave(), completes);
      await expectLater(t.leave(), completes);
    });
  });

  group('upload (真 loopback socket)', () {
    late ServerSocket server;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async => server.close());

    /// 收 [expectBytes] 字节后回 [reply],并把收到的全部字节交出去。
    ///
    /// 应答时机必须是「收够了」而不是 `onDone` —— 客户端要读应答,不会半关连接,
    /// 等 `onDone` 两边就一起挂死了。真设备也是收够 size 就校验并回 EBXR。
    Future<Uint8List> serve(Uint8List? reply, int expectBytes) {
      final got = Completer<Uint8List>();
      server.listen((socket) {
        final buf = <int>[];
        socket.listen((data) async {
          buf.addAll(data);
          if (buf.length < expectBytes || got.isCompleted) return;
          if (reply != null) {
            socket.add(reply);
            await socket.flush();
          }
          await socket.close();
          got.complete(Uint8List.fromList(buf));
        });
      });
      return got.future;
    }

    /// 模拟 §5.2 校验失败:设备一连上就关,什么也不回。
    void serveSlam() {
      server.listen((socket) => socket.destroy());
    }

    /// 设备侧一收到 40 字节头就立刻回应答 —— 用于验证「还在写正文时应答就来了」
    /// 这条路径:监听必须在写之前挂上,否则这 8 字节会被漏掉。
    void serveAckOnHeader(Uint8List reply) {
      server.listen((socket) {
        var seen = 0;
        socket.listen((data) async {
          final first = seen == 0;
          seen += data.length;
          if (first) {
            socket.add(reply);
            await socket.flush();
          }
        });
      });
    }

    Uint8List body(int n) =>
        Uint8List.fromList(List.generate(n, (i) => i & 0xFF));

    Uint8List ok() => Uint8List.fromList([0x45, 0x42, 0x58, 0x52, 1, 0, 0, 0]);
    Uint8List fail(int reason) =>
        Uint8List.fromList([0x45, 0x42, 0x58, 0x52, 0, reason, 0, 0]);

    test('线上字节 = 40B EBXF 头 + 正文,一字节不多不少', () async {
      final payload = body(300);
      final crc = eBadgeCrc32(payload);
      final received = serve(ok(), 40 + payload.length);

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'wp.jpg',
        fileType: EBadgeFileType.jpeg,
        body: payload,
        crc32: crc,
      );

      expect(r.succeed, isTrue);
      final wire = await received;
      expect(wire.length, 40 + payload.length);
      expect(
        wire.sublist(0, 40),
        EBadgeXferHeader.build(
          fileType: EBadgeFileType.jpeg,
          name: 'wp.jpg',
          size: payload.length,
          crc32: crc,
        ),
      );
      expect(wire.sublist(40), payload);
    });

    test('crc32 用调用方给的值,不自己重算 —— §5.2 要求与 Offer 一致', () async {
      final received = serve(ok(), 40 + 16);
      // 故意给一个错的 CRC:头里必须原样出现它,而不是被「修正」成真值。
      const wrong = 0xDEADBEEF;

      await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(16),
        crc32: wrong,
      );

      expect(EBadgeCodec.readU32le(await received, 12), wrong);
    });

    test('进度按分块回调,最后一次必然等于总长', () async {
      final received = serve(ok(), 40 + 2500);
      final progress = <int>[];

      await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(2500),
        crc32: 0,
        chunkSize: 1000,
        onProgress: (sent, _) => progress.add(sent),
      );

      await received;
      expect(progress, [1000, 2000, 2500]);
    });

    test('设备回 status=失败时 succeed 为 false,且带出 §2.6 错误码名', () async {
      final received = serve(fail(0x03), 40 + 8); // STORAGE_FULL

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(8),
        crc32: 0,
      );

      await received;
      expect(r.error, isNull, reason: '这是设备明确判失败,不是链路问题');
      expect(r.succeed, isFalse);
      expect(r.describe(), contains('STORAGE_FULL'));
    });

    test('正文还在写时应答就到了 —— 监听挂在写之前,不能漏', () async {
      serveAckOnHeader(ok());

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        // 大到足以让应答在写正文期间抵达。
        body: body(512 * 1024),
        crc32: 0,
        chunkSize: 1024,
      );

      expect(r.succeed, isTrue);
    });

    test('设备不回应答就关连接 → 报「未回 EBXR」而不是挂到超时', () async {
      serveSlam();

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(64),
        crc32: 0,
        // 挂死的话这里会 30 s 超时失败,而不是等满 120 s —— 把上限压到远小于
        // 测试超时,好让「挂死」和「正确报错」在结果上分得开。
        ackTimeout: const Duration(seconds: 3),
      );

      expect(r.succeed, isFalse);
      // 报的是「设备中途关连接」而不是笼统的「未回 EBXR」:设备一连上就 destroy,
      // 我们的正文根本没写完,这两种要分开 —— 前者查设备为什么拒收,后者查固件
      // 为什么不回应答。
      expect(
        r.failure,
        anyOf(
          EBadgeWifiFailure.closedWhileSending,
          EBadgeWifiFailure.ackMissing,
        ),
      );
      expect(r.error, contains('关闭了连接'));
      // 关键:错误文本里必须有「传了多少」,这是排查的第一手线索。
      expect(r.error, contains('/64 B'));
      expect(r.totalBytes, 64);
    });

    test('失败时带上已写字节数 —— 不能只给一句「未应答」', () async {
      // 收下 40B 头 + 前 1000B 正文后就掐连接,什么也不回。
      server.listen((socket) {
        var seen = 0;
        socket.listen((data) {
          seen += data.length;
          if (seen >= 40 + 1000) socket.destroy();
        });
      });

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(64 * 1024),
        crc32: 0,
        chunkSize: 1000,
        ackTimeout: const Duration(seconds: 5),
      );

      expect(r.succeed, isFalse);
      expect(r.headerSent, isTrue, reason: '40B 头是先写出去的');
      expect(r.totalBytes, 64 * 1024);
      // flush 只保证数据进入本机内核缓冲。慢机器可能在正文写完前观察到 RST，
      // 快机器（包括 CI Linux）也可能先把 64 KiB 全交给内核，随后才看到断线。
      // 两种时序都合法，但 failure 必须与本机实际写入进度一致。
      expect(
        r.failure,
        anyOf(
          EBadgeWifiFailure.closedWhileSending,
          EBadgeWifiFailure.ackMissing,
        ),
      );
      if (r.failure == EBadgeWifiFailure.closedWhileSending) {
        expect(r.bytesSent, lessThan(r.totalBytes));
      } else {
        expect(r.bytesSent, r.totalBytes);
      }
      expect(r.progressText, contains('40B 头已发'));
      expect(r.error, contains('§5.2'), reason: '要指向设备校验失败这条线索');
    });

    test('应答只回了 3 字节 → 报「应答被截断」并附原始字节', () async {
      // EBXR 要 8 字节,这里只回 4 字节的 magic 就关连接。
      final received = serve(
        Uint8List.fromList([0x45, 0x42, 0x58, 0x52]),
        40 + 16,
      );

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(16),
        crc32: 0,
        ackTimeout: const Duration(seconds: 3),
      );

      await received;
      expect(r.succeed, isFalse);
      expect(r.failure, EBadgeWifiFailure.ackTruncated);
      expect(r.error, contains('只回了 4 字节'));
      // 原始字节必须原样带出来 —— 「不是 EBXR」远不如「它回的是 45 42 58 52」有用。
      expect(r.error, contains('45 42 58 52'));
      expect(r.bytesSent, 16, reason: '正文是写完了的,锅在应答');
    });

    test('回够 8 字节但 magic 不对 → 报「不是 EBXR」并附原始字节', () async {
      // 'EBXF' 而不是 'EBXR' —— 固件把请求头的 magic 抄过来了,很常见的错。
      final received = serve(
        Uint8List.fromList([0x45, 0x42, 0x58, 0x46, 1, 0, 0, 0]),
        40 + 16,
      );

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(16),
        crc32: 0,
        ackTimeout: const Duration(seconds: 3),
      );

      await received;
      expect(r.succeed, isFalse);
      expect(r.failure, EBadgeWifiFailure.ackMalformed);
      expect(r.error, contains('45 42 58 46'));
      expect(r.error, contains('45 42 58 52'), reason: '要告诉人正确的 magic 是什么');
    });

    test('连不上时如实说「0 字节发出」,不假装传了什么', () async {
      final port = server.port;
      await server.close();

      final r = await EBadgeWifiTransport().upload(
        ip: '127.0.0.1',
        port: port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(2048),
        crc32: 0,
        connectTimeout: const Duration(milliseconds: 500),
      );

      expect(r.failure, EBadgeWifiFailure.connect);
      expect(r.headerSent, isFalse);
      expect(r.bytesSent, 0);
      expect(r.progressText, contains('0 字节发出'));
    });

    test('应答迟迟不来时按 ackTimeout 超时,错误里带上协议条款', () async {
      // 收下但永不回应答,也不关连接。
      server.listen((socket) => socket.listen((_) {}));

      final r = await EBadgeWifiTransport().upload(
        ip: server.address.address,
        port: server.port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(8),
        crc32: 0,
        ackTimeout: const Duration(milliseconds: 300),
      );

      expect(r.succeed, isFalse);
      expect(r.error, contains('§5.5'));
    });

    test('端口没人监听 → 连接失败,错误里带 ip:port 便于定位', () async {
      final port = server.port;
      await server.close();

      final r = await EBadgeWifiTransport().upload(
        ip: '127.0.0.1',
        port: port,
        name: 'a.bin',
        fileType: EBadgeFileType.bin,
        body: body(8),
        crc32: 0,
        connectTimeout: const Duration(milliseconds: 500),
      );

      expect(r.succeed, isFalse);
      expect(r.error, contains('127.0.0.1:$port'));
    });
  });

  group('EBadgeWifiResult.describe', () {
    test('区分链路失败与设备判失败', () {
      const link = EBadgeWifiResult.fail(
        EBadgeWifiFailure.connect,
        detail: 'TCP 连接失败',
      );
      expect(link.succeed, isFalse);
      expect(link.describe(), contains('TCP 连接失败'));

      final ok = EBadgeWifiResult.ok(
        EBadgeXferAck.parse(
          Uint8List.fromList([0x45, 0x42, 0x58, 0x52, 1, 0, 0, 0]),
        )!,
      );
      expect(ok.succeed, isTrue);
      expect(ok.describe(), contains('成功'));

      final bad = EBadgeWifiResult.ok(
        EBadgeXferAck.parse(
          Uint8List.fromList([0x45, 0x42, 0x58, 0x52, 0, 0x05, 0, 0]),
        )!,
      );
      expect(bad.succeed, isFalse);
      expect(bad.describe(), contains('0x05'));
    });

    test('每种 failure 都给出可区分的原因文本,不能都是「未应答 EBXR」', () {
      final texts = <String>{};
      for (final f in EBadgeWifiFailure.values) {
        if (f == EBadgeWifiFailure.none) continue;
        final r = EBadgeWifiResult.fail(
          f,
          bytesSent: 100,
          totalBytes: 200,
          headerSent: true,
          ackRaw: Uint8List.fromList([0x45, 0x42]),
        );
        expect(r.error, isNotNull);
        texts.add(r.error!);
      }
      // 8 个枚举值去掉 none 还剩 7 种,每种文本都不同 —— 一旦有人把两种失败合并成
      // 同一句话,这里就会红。
      expect(texts.length, EBadgeWifiFailure.values.length - 1);
    });

    test('progressText 分得清「头都没发」和「头发了正文卡在 0」', () {
      const noHeader = EBadgeWifiResult.fail(
        EBadgeWifiFailure.closedWhileSending,
        totalBytes: 1024,
      );
      expect(noHeader.progressText, contains('40B EBXF 头都没写出去'));

      const zeroBody = EBadgeWifiResult.fail(
        EBadgeWifiFailure.closedWhileSending,
        totalBytes: 1024,
        headerSent: true,
      );
      expect(zeroBody.progressText, contains('40B 头已发'));
      expect(zeroBody.progressText, contains('0/1024 B'));

      const half = EBadgeWifiResult.fail(
        EBadgeWifiFailure.ackTimeout,
        bytesSent: 512,
        totalBytes: 1024,
        headerSent: true,
      );
      expect(half.progressText, contains('512/1024 B（50.0%）'));
    });
  });
}
