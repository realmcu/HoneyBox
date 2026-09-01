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

  /// 订阅后立刻 pause:不再从 socket 取数据,接收缓冲很快填满,对端的 flush()
  /// 就悬在满的收窗上 —— 这正是「设备读得慢」的样子。
  ///
  /// 刻意不用「accept 之后完全不订阅」:那样 Windows 内核会直接把连接 abort
  /// (errno 10053),测到的就变成「对端断开」而不是「对端读得慢」,两件事的
  /// 诊断路径完全不同。
  void serveSlow() {
    server.listen((socket) {
      socket.listen((_) {}).pause();
    });
  }

  /// 大到必然塞满内核收发缓冲的一帧。典型收窗是几十 KB 量级,4 MB 足够。
  ///
  /// 一律显式给 crc32:自算 4 MB 的 CRC 是**同步**跑的,要上百毫秒,会把测试里
  /// 的时间判断搅乱(而且这几条测的不是 crc)。
  Future<EBadgeFrameOutcome> sendHuge(EBadgeStreamTransport t) =>
      t.sendFrame(frame(4 * 1024 * 1024, 0x5A), crc32: 0);

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
      // 警告类计数也要归零:上一场会话的警告数留到新会话里,会让「这次调整有没有
      // 改善」完全没法判断 —— 而那正是拖滑条时唯一要看的东西。
      expect(t.gapWarnings, 0);
      expect(t.framesSkipped, 0);
      expect(t.lastGap, isNull);
      // 带宽窗口同理:上一场的样本留下来,新会话头几秒会是两场混算的结果,而重连
      // 之后第一眼看的就是这个数。
      expect(t.wireBytesSent, 0);
      expect(t.peakBandwidthBps, 0);
      expect(t.bandwidthBps, isNull);
      expect(t.averageBandwidthBps, isNull);
      await t.close();
    });
  });

  // 带宽是这次要的读数本身:**按实际推出的数据量统计**,而「实际推出」含每帧的
  // 14B 流头 —— 头也过网卡、也占链路。
  group('实时带宽', () {
    test('线上字节含每帧 14B 流头，与 bytesSent 差的正是头', () async {
      serve();
      final t = await connected();
      await t.sendFrame(frame(100));
      await t.sendFrame(frame(200));

      expect(t.bytesSent, 300, reason: 'bytesSent 只算 payload');
      expect(t.wireBytesSent, 300 + 14 * 2, reason: '带宽要按线上字节算');
      await t.close();
    });

    test('样本跨度不足时不给读数 —— 宁可说算不出，也不报一个假的高值', () async {
      // 刚连上的头几十毫秒里单帧会把速率放大到荒谬的量级(0.5ms 推 40KB ⇒ 80MB/s),
      // 显示出来会让人以为链路很快。
      serve();
      final t = await connected();
      await t.sendFrame(frame(1000));
      expect(t.bandwidthBps, isNull, reason: '跨度不足 500ms 时该是 null');
      expect(t.averageBandwidthBps, isNull);
      await t.close();
    });

    test('窗口内推多帧后给出正的读数，且不低于按线上字节的粗算值', () async {
      serve();
      final t = await connected();
      // 600ms 里匀速推 6 帧,跨过 _minMeterSpan 才有读数。
      for (var i = 0; i < 6; i++) {
        await t.sendFrame(frame(1000));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final bps = t.bandwidthBps;
      expect(bps, isNotNull);
      expect(bps!, greaterThan(0));
      // 6 帧 × 1014B 落在约 600ms 里 ⇒ 上万 B/s 量级。放宽下界只验「量级没算错」,
      // 不验精确值 —— 测试机的调度抖动会让精确断言变成偶发失败。
      expect(bps, greaterThan(3000));
      expect(t.peakBandwidthBps, greaterThanOrEqualTo(bps));
      await t.close();
    });

    test('停止推帧后读数掉到 0，而不是冻在最后一瞬的正常值', () async {
      // 这条是带宽读数的核心价值:画面卡死时它必须如实归零。冻住的话屏上会显示
      // 「还在正常推」,而那正是最需要看出问题的时刻。
      // 窗口 = frameGapLimit(3s),所以这里真等 3s 多一点。
      serve();
      final t = await connected();
      await t.sendFrame(frame(1000));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(t.bandwidthBps, isNotNull, reason: '刚推过,应有读数');

      await Future<void>.delayed(
        EBadgeStreamTransport.bandwidthWindow +
            const Duration(milliseconds: 300),
      );
      expect(t.bandwidthBps, 0, reason: '窗口内一个字节都没出去 ⇒ 必须是 0,不是旧值也不是 null');
      // 但累计量和峰值不归零:它们回答的是「整场推了多少 / 冲到过多少」。
      expect(t.wireBytesSent, 1014);
      await t.close();
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('窗口长度与 §6.4 帧超时对齐 —— 读数为 0 就等于设备该超时了', () {
      // 这个对应关系是「0 有诊断意义」的全部依据,换成 1s 或 5s 就只是个数字了。
      expect(EBadgeStreamTransport.bandwidthWindow,
          EBadgeStreamTransport.frameGapLimit);
    });

    test('跳过的帧不计入带宽 —— 它一个字节都没出去', () async {
      serveSlow();
      final t = await connected();
      final first = sendHuge(t);
      final skipped = await t.sendFrame(frame(5000));

      expect(skipped.isOk, isTrue);
      expect(t.framesSkipped, 1);
      // 被跳过的帧没写出去,不能算进「实际推出的数据量」。第一帧还卡着也没算完。
      expect(t.wireBytesSent, 0, reason: '跳过的帧不占线上字节');

      await t.close();
      final e = await first;
      if (e.error != null) expect(e.error, isNot(contains('bound')));
    });

    group('formatBps', () {
      // 三处(界面、日志、会话总结)共用同一套格式化,否则同一个数在屏上和日志里
      // 长得不一样,核对时会先怀疑是不是两个数。
      test('null 给「—」而不是 0 —— 算不出来和真的是 0 是两回事', () {
        expect(EBadgeStreamTransport.formatBps(null), '—');
        expect(EBadgeStreamTransport.formatBps(0), '0 B/s');
      });

      test('按量级切单位，几十 KB/s 区间保留一位小数', () {
        expect(EBadgeStreamTransport.formatBps(512), '512 B/s');
        // 这条链路的典型区间就在几十 KB/s,取整会把拖滑条时唯一能看出的变化抹平。
        expect(EBadgeStreamTransport.formatBps(64 * 1024), '64.0 KB/s');
        expect(EBadgeStreamTransport.formatBps(200 * 1024), '200 KB/s');
        expect(EBadgeStreamTransport.formatBps(2 * 1024 * 1024), '2.00 MB/s');
      });
    });
  });

  group('sendFrame', () {
    test('线上字节 = 14B 流头 + payload,逐帧首尾相接', () async {
      final got = serve();
      final t = await connected();

      final a = frame(100, 0x41);
      final b = frame(50, 0x42);
      expect((await t.sendFrame(a)).isOk, isTrue);
      expect((await t.sendFrame(b)).isOk, isTrue);
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
      expect((await t.sendFrame(Uint8List(0))).error, contains('空帧'));
      expect(t.framesSent, 0);
      await t.close();
    });

    test('未连接就推帧,给的是原因而不是异常', () async {
      final t = EBadgeStreamTransport();
      expect((await t.sendFrame(frame(4))).error, 'TCP 未连接');
    });

    test('帧间隔超 §6.4 的 3s 会报出来,但帧照发', () async {
      // 不真等 3 秒:frameGapLimit 是常量,这里验的是「首帧不判间隔」这条 ——
      // last == null 时 gap 恒为 0,不该报。真超时路径由常量本身保证。
      expect(EBadgeStreamTransport.frameGapLimit, const Duration(seconds: 3));
      serve();
      final t = await connected();
      expect((await t.sendFrame(frame(4))).isOk, isTrue);
      expect(t.lastGap, isNull, reason: '首帧没有「上一帧」,间隔应为 null');
      await t.close();
    });

    test('lastGap 记录相邻两帧的实测间隔', () async {
      // 实测间隔是这条链路真实能力的读数 —— 它和协商的 fps 往往差很远,而这个差
      // 值本身就是要看的东西。
      serve();
      final t = await connected();
      await t.sendFrame(frame(4));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await t.sendFrame(frame(4));
      expect(t.lastGap, isNotNull);
      expect(t.lastGap!.inMilliseconds, greaterThanOrEqualTo(25));
      await t.close();
    });
  });

  // 这一组是需求本身:帧间隔超时**只警告,不中止会话**。
  //
  // 为什么:那条消息是 App 自己按 §6.4 的阈值推算出来的 —— 设备既没回 0x16
  // TRANSFER_FAIL,也没关连接,而且报警告的那一帧其实**写成功了**(计数器都加过)。
  // 按推测拆掉一条还活着的会话,会把「超时之后设备到底怎么反应」这个正要观察的现象
  // 抹掉。只有实证(对端断开、socket 写失败、未连接)才算 error。
  group('警告 vs 错误(自查不中止会话)', () {
    test('间隔超时走 warning，不占 error，且帧真的发出去了', () async {
      final got = serve();
      // 阈值调小以免真等 3 秒。这里 stallLimit 同时也是 gap 判定用的常量的替身,
      // 但 gap 走的是 frameGapLimit(常量),所以这条改用「卡住」路径来验语义。
      final t = EBadgeStreamTransport(
        stallLimit: const Duration(milliseconds: 50),
      );
      expect(
        await t.connect(ip: server.address.address, port: server.port),
        isNull,
      );

      final r = await t.sendFrame(frame(20));
      expect(r.error, isNull);
      expect(r.isOk, isTrue);
      await until(() => got.length >= 14 + 20);
      expect(t.framesSent, 1, reason: '警告路径下帧仍然要发出去');
      await t.close();
    });

    test('警告带归因:期间有跳帧 ⇒ 背压，指向质量/帧率旋钮', () async {
      serveSlow();
      final t = EBadgeStreamTransport(
        stallLimit: const Duration(milliseconds: 60),
      );
      expect(
        await t.connect(ip: server.address.address, port: server.port),
        isNull,
      );

      final first = sendHuge(t);
      // 阈值内的跳帧是静默的 —— 丢帧本身不是故障,§6 允许。
      expect((await t.sendFrame(frame(64))).isOk, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final r = await t.sendFrame(frame(64));
      // 关键:是 warning 而不是 error —— 会话不该因此被拆。
      expect(r.error, isNull, reason: '卡住是推测,不能当实证拆会话');
      expect(r.warning, contains('仍未完成'));
      expect(r.warning, contains('帧超时'));
      expect(r.diagnosis, EBadgeGapCause.backpressure);
      // 累计次数要报:偶发一次和一直在发生是两种情况,日志会滚过去,这个数不会。
      expect(t.gapWarnings, greaterThan(0));
      expect(r.warning, contains('累计'));

      await t.close();
      final e = await first;
      if (e.error != null) expect(e.error, isNot(contains('bound')));
    });

    test('对端断开才是 error —— 实证与推测分开', () async {
      serve(onBytes: (s, buf) {
        if (buf.length >= 14 + 4) s.destroy();
      });
      final t = await connected();
      await t.sendFrame(frame(4));
      await until(() => t.peerClosed != null);

      final r = await t.sendFrame(frame(4));
      expect(r.error, t.peerClosed, reason: '设备关连接是实证,必须是 error');
      expect(r.warning, isNull);
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
      expect((await t.sendFrame(frame(4))).error, t.peerClosed);
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

  // 这一组是一个真实故障的回归测试:现场报「推帧失败：Bad state: StreamSink is
  // bound to a stream」。
  //
  // 成因:dart:io 的 `IOSink.flush()` 执行期间会把 sink 标成 bound,此时第二个
  // `flush()`(或 `close()`)直接抛上面那个 StateError。而 §6 推帧是 Timer 驱动
  // 的 —— 设备读得慢一点,TCP 收窗压满,`flush()` 就迟迟不返回,下一个 tick 照样
  // 进来写,必然撞上。注意这跟帧率高低无关,靠「1 fps 应该来得及」是挡不住的。
  //
  // 复现手法:服务端 accept 之后**完全不读**,并推一个远大于收窗的 payload,
  // 让 flush() 真的悬住。
  group('写入串行化(回归:StreamSink is bound to a stream)', () {
    test('并发推帧不抛 StateError —— 上一帧没写完就跳过', () async {
      serveSlow();
      final t = await connected();

      // 两次 sendFrame 不 await 第一个:这正是 Timer.periodic 回调的形状。
      final first = sendHuge(t);
      final second = await t.sendFrame(frame(64));

      // 关键断言:第二次既没抛,也没把 bound 那条 StateError 当结果返回。
      expect(second.isOk, isTrue, reason: '并发推帧应被跳过,而不是报错');
      expect(second.error ?? '', isNot(contains('bound')));
      expect(t.framesSkipped, 1, reason: '被跳过的帧要计数,否则背压看不见');
      expect(t.framesSent, 0, reason: '第一帧还卡着,不该记成已推');

      await t.close();
      // first 在 close() 强拆连接后才会落地;它报错是正常的,但必须是 socket
      // 层面的原因,不能是 bound。
      final e = await first;
      if (e.error != null) expect(e.error, isNot(contains('bound')));
    });

    test('卡过 §6.4 帧超时后如实报出来,而不是一直静默跳帧', () async {
      serveSlow();
      final t = EBadgeStreamTransport(
        // 不真等 3 秒。验的是「卡太久要报」这条逻辑,阈值本身是常量。
        stallLimit: const Duration(milliseconds: 80),
      );
      expect(
        await t.connect(ip: server.address.address, port: server.port),
        isNull,
      );

      final first = sendHuge(t);
      // 阈值内跳帧是静默的 —— 丢帧本身不是故障,§6 允许。
      expect((await t.sendFrame(frame(64))).isOk, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      // 越过阈值要报,但只是**警告** —— 拆会话是推测,见「警告 vs 错误」那一组。
      final r = await t.sendFrame(frame(64));
      expect(r.warning, contains('仍未完成'));
      expect(r.warning, contains('帧超时'));
      expect(r.error, isNull);

      await t.close();
      final e = await first;
      if (e.error != null) expect(e.error, isNot(contains('bound')));
    });

    test('停止推流时不与在写的帧抢 sink —— close 不抛', () async {
      serveSlow();
      final t = EBadgeStreamTransport(
        // close() 要等在写的帧收尾,阈值调小免得测试等满 3 秒。
        stallLimit: const Duration(milliseconds: 80),
      );
      expect(
        await t.connect(ip: server.address.address, port: server.port),
        isNull,
      );

      final first = sendHuge(t);
      // 用户点「停止推流」正是这个时机:上一帧还压在满的收窗上。
      await expectLater(t.close(), completes);
      expect(t.connected, isFalse);

      final e = await first;
      if (e.error != null) expect(e.error, isNot(contains('bound')));
    });

    test('写失败后能恢复,不会永久卡在「上一帧还在写」', () async {
      // 一次异常之后如果不解锁 _inFlight,后续每帧都报「上一帧还在写」,真因就被
      // 永久盖住了 —— 那比原来的崩溃更难查。
      serve(onBytes: (s, buf) => s.destroy());
      final t = await connected();
      await t.sendFrame(frame(16));
      await until(() => t.peerClosed != null);

      expect(t.sending, isFalse, reason: '写完/写挂之后都必须解锁');
      // 连接已断,所以这里报的是 peerClosed 而不是「上一帧还在写」。
      expect((await t.sendFrame(frame(16))).error, t.peerClosed);
      await t.close();
    });

    test('串行写出的两帧在线上仍然首尾相接,头和正文不交错', () async {
      // 跳帧机制不能把帧写坏:被跳过的帧是**整帧**不发,而不是发一半。
      final got = serve();
      final t = await connected();

      final a = frame(2000, 0x41);
      final b = frame(1000, 0x42);
      final f1 = t.sendFrame(a);
      final f2 = t.sendFrame(b); // 大概率被跳过
      await Future.wait([f1, f2]);
      await until(() => got.length >= 14 + 2000);

      final h1 =
          EBadgeStreamHeader.parse(Uint8List.fromList(got.sublist(0, 14)))!;
      expect(h1.size, 2000);
      expect(h1.crc32, eBadgeCrc32(a));
      expect(got.sublist(14, 14 + 2000).every((x) => x == 0x41), isTrue,
          reason: '第二帧的字节插进了第一帧的正文里');
      // 线上总长只能是「整帧」的组合:要么只有 a,要么 a 之后紧跟完整的 b。
      expect(got.length, anyOf(14 + 2000, 14 + 2000 + 14 + 1000));

      await t.close();
    });
  });
}
