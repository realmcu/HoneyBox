import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ebadge/ebadge_debug_config.dart';
import 'package:honeybox/pages/ebadge/ebadge_demo_presets.dart';
import 'package:honeybox/pages/ebadge/ebadge_stream_camera_source.dart';
import 'package:honeybox/services/ebadge_stream_transport.dart';

/// 只测模型的默认值与序列化。[EBadgeDebugConfigStore] 的读写走
/// `getApplicationSupportDirectory`(平台通道),不在这里测。
void main() {
  group('帧源帧率', () {
    // 需求本身:内置测试帧按 1 fps 发。四帧轮转的用途是肉眼判断卡帧/丢帧,10 fps
    // 下白块转一圈只要 400 ms,看着就是一片闪烁,读不出帧号;1 fps 下每秒落一帧,
    // 能逐帧对着设备屏核对。
    test('内置测试帧按 1 fps 发送', () {
      expect(EBadgeStreamSource.builtin.defaultFps, 1);
    });

    // 摄像头源的用途是加压,1 fps 压不出任何东西 —— 两个源的帧率必须能各自不同,
    // 所以帧率挂在枚举上而不是共用一个常量。
    test('摄像头源保持 10 fps —— 两个源的帧率互不牵连', () {
      expect(EBadgeStreamSource.camera.defaultFps, 10);
      expect(EBadgeStreamSource.camera.defaultFps,
          greaterThan(EBadgeStreamSource.builtin.defaultFps));
    });

    // 1 fps 是安全下限,不能再往下调:§6.4 的帧超时 3 s 是设备清理会话的阈值。
    // 周期必须留出「跳一个 tick 也不超时」的余量 —— 2×周期 < 3 s 才安全,1 fps
    // 刚好卡在 2 s。真降到 0.5 fps,跳一次 tick 就是 4 s,设备直接把会话拆了,
    // 而现象是「推着推着自己断了」,真因却在帧源。
    test('每个源的周期都留得住一次跳帧，不会撞上 §6.4 的 3s 帧超时', () {
      for (final s in EBadgeStreamSource.values) {
        final periodMs = 1000 ~/ s.defaultFps;
        expect(periodMs * 2,
            lessThan(EBadgeStreamTransport.frameGapLimit.inMilliseconds),
            reason: '${s.name} 的 ${s.defaultFps} fps 下跳一个 tick 就会超时');
      }
    });

    // fps 进 0x08 OFFER 的 TLV 是 uint8,取值 1–255(见 EBadgeRequest
    // .jpgStreamOffer,越界直接抛 ArgumentError)。0 或负数会让点「开始推流」
    // 变成崩溃而不是失败提示。
    test('帧率落在 0x08 OFFER 的 uint8 合法区间内', () {
      for (final s in EBadgeStreamSource.values) {
        expect(s.defaultFps, inInclusiveRange(1, 255), reason: s.name);
      }
    });
  });

  group('默认值', () {
    // 这条是需求本身:默认发裸 JFIF。§5.2 字面上说 payload 是「原始文件字节」,
    // 裸流才是字面一致的那份,且此时 Offer 报的 file_type=JPEG 名副其实。默认值是
    // 每轮调试的起点,起点必须落在协议写着的那一种上。
    test('默认不带 16B 设备头', () {
      expect(const EBadgeDebugConfig().xferWithHeader, isFalse);
    });

    // 从最小体积起步:先确认链路通,再逐档加大去找它在哪一档开始失败。默认落在大档
    // 会让第一次调试就同时面对「链路通不通」和「体积扛不扛得住」两个变量。
    test('默认档位是最小的那一档', () {
      const cfg = EBadgeDebugConfig();
      expect(cfg.demoPresetSlug, kDefaultDemoPresetSlug);
      expect(cfg.demoPresetIndex, 0);
      expect(kEBadgeDemoPresets.first.slug, kDefaultDemoPresetSlug);
    });

    test('默认帧源是内置测试帧，默认自动滚动开启', () {
      const cfg = EBadgeDebugConfig();
      expect(cfg.streamSource, EBadgeStreamSource.builtin);
      expect(cfg.autoScroll, isTrue);
    });

    // 滑条的默认档必须与两个「事实来源」一致:帧率对齐摄像头源在枚举上声明的
    // defaultFps,质量对齐原生 JPEG 分支的默认档(见 EBadgeStreamCameraSource
    // .quality)。各写一个字面量的话,迟早出现「界面显示 10 fps、实际按别的推」。
    test('滑条默认档对齐帧源与原生的默认值', () {
      const cfg = EBadgeDebugConfig();
      expect(cfg.cameraFps, EBadgeStreamSource.camera.defaultFps);
      expect(cfg.cameraQuality, EBadgeStreamCameraSource.quality);
    });

    // 从没选过升级包时是 null,而不是空串 —— 页面据此显示「尚未选择升级包」并把
    // 「OTA 升级」按钮禁掉,不会拿一个空路径去 stat。
    test('默认没有 OTA 升级包路径', () {
      expect(const EBadgeDebugConfig().otaFilePath, isNull);
    });

    test('滑条默认档落在自己的区间里', () {
      const cfg = EBadgeDebugConfig();
      expect(cfg.cameraFps,
          inInclusiveRange(kEBadgeStreamFpsMin, kEBadgeStreamFpsMax));
      expect(cfg.cameraQuality,
          inInclusiveRange(kEBadgeStreamQualityMin, kEBadgeStreamQualityMax));
    });
  });

  group('滑条区间', () {
    // 需求本身:帧率 1–40。
    test('帧率区间是 1–40', () {
      expect(kEBadgeStreamFpsMin, 1);
      expect(kEBadgeStreamFpsMax, 40);
    });

    // 整个区间都要能进 0x08 OFFER 的 uint8 TLV。上界若越过 255,
    // EBadgeRequest.jpgStreamOffer 会直接抛 ArgumentError —— 拖到头就是崩溃。
    test('帧率上下界都在 0x08 OFFER 的 uint8 区间内', () {
      expect(kEBadgeStreamFpsMin, inInclusiveRange(1, 255));
      expect(kEBadgeStreamFpsMax, inInclusiveRange(1, 255));
    });

    // 质量上界是 IJG 质量档的定义上限;下界再低下去,466×466 的块效应会盖住画面
    // 内容,「设备显示不对」和「本来就编得糊」就分不开了。
    test('质量区间落在 IJG 的 1–100 内', () {
      expect(kEBadgeStreamQualityMin, greaterThan(0));
      expect(kEBadgeStreamQualityMax, 100);
      expect(kEBadgeStreamQualityMin, lessThan(kEBadgeStreamQualityMax));
    });
  });

  group('序列化', () {
    test('七项都能存能读回', () {
      const cfg = EBadgeDebugConfig(
        xferWithHeader: true,
        demoPresetSlug: 'xxl',
        streamSource: EBadgeStreamSource.camera,
        autoScroll: false,
        cameraFps: 25,
        cameraQuality: 45,
        otaFilePath: '/data/user/0/app/cache/ebadge_fw_v1.2.3.bin',
      );
      final back = EBadgeDebugConfig.fromJson(cfg.toJson());
      expect(back.xferWithHeader, isTrue);
      expect(back.demoPresetSlug, 'xxl');
      expect(back.streamSource, EBadgeStreamSource.camera);
      expect(back.autoScroll, isFalse);
      expect(back.cameraFps, 25);
      expect(back.cameraQuality, 45);
      expect(back.otaFilePath, '/data/user/0/app/cache/ebadge_fw_v1.2.3.bin');
    });

    // 只存路径,不存体积:文件随时会被删或被换成新一版固件,存下体积就有机会拿一个
    // 过期数字去填 Offer 和 EBXF 头,而那两处报的必须是这一次真正推出去的字节数。
    test('只记路径，不记体积或校验值', () {
      final json = const EBadgeDebugConfig(otaFilePath: '/tmp/fw.bin').toJson();
      expect(json['otaFilePath'], '/tmp/fw.bin');
      expect(json.keys.where((k) => k.toLowerCase().contains('ota')),
          ['otaFilePath']);
    });

    // 存名字而不是序号:枚举里插一项就会让旧配置里的序号指向另一个源,而「我明明
    // 选的是内置帧」这种偏差在界面上看不出来。
    test('帧源存的是名字，不是序号', () {
      expect(
        const EBadgeDebugConfig(streamSource: EBadgeStreamSource.camera)
            .toJson()['streamSource'],
        'camera',
      );
    });

    // 同理:档位存 slug。kEBadgeDemoPresets 是按体积排序的调试顺序,往中间插一档
    // 是很可能的事,序号一错位界面就显示「极小 ~6K」而实际传的是别的体积。
    test('档位存的是 slug，不是索引', () {
      expect(
        const EBadgeDebugConfig(demoPresetSlug: 'm').toJson()['demoPresetSlug'],
        'm',
      );
    });

    // 加了新字段之后,旧配置文件缺的就是那一个键。整份退回默认会把用户其他几项
    // 选择一起丢掉 —— 那看起来就像「配置没存住」。
    test('缺字段时逐项退回默认，不丢其余各项', () {
      final back = EBadgeDebugConfig.fromJson(const {'xferWithHeader': true});
      expect(back.xferWithHeader, isTrue);
      expect(back.demoPresetSlug, kDefaultDemoPresetSlug);
      expect(back.streamSource, EBadgeStreamSource.builtin);
      expect(back.autoScroll, isTrue);
      expect(back.cameraFps, const EBadgeDebugConfig().cameraFps);
      expect(back.cameraQuality, const EBadgeDebugConfig().cameraQuality);
      expect(back.otaFilePath, isNull);
    });

    test('类型不对的值不抛，退回默认', () {
      final back = EBadgeDebugConfig.fromJson(const {
        'xferWithHeader': 'yes',
        'demoPresetSlug': 42,
        'streamSource': 7,
        'autoScroll': 'no',
        'cameraFps': '30',
        'cameraQuality': null,
        'otaFilePath': 12345,
      });
      expect(back.xferWithHeader, isFalse);
      expect(back.demoPresetSlug, kDefaultDemoPresetSlug);
      expect(back.streamSource, EBadgeStreamSource.builtin);
      expect(back.autoScroll, isTrue);
      expect(back.cameraFps, const EBadgeDebugConfig().cameraFps);
      expect(back.cameraQuality, const EBadgeDebugConfig().cameraQuality);
      expect(back.otaFilePath, isNull);
    });

    // 空串一并当「没选过」:它只会让界面显示一个没有名字的文件,而 File('') 的
    // exists() 恒为 false —— 两条路的结果一样,不如在入口就收敛掉。
    test('空的 OTA 路径等同没选过', () {
      expect(
        EBadgeDebugConfig.fromJson(const {'otaFilePath': ''}).otaFilePath,
        isNull,
      );
    });

    // 越界的值**夹到区间**而不是退回默认:存下来的是用户上次调的值,滑条上界将来
    // 若收窄(比如实测发现 40 fps 毫无意义),夹到新上界比跳回 10 更贴近他的本意。
    //
    // 而且夹这一步是必需的、不是防御性冗余:帧率会进 0x08 OFFER,而
    // EBadgeRequest.jpgStreamOffer 对越界 fps 直接抛 ArgumentError —— 一个手改出来
    // 的 `"cameraFps": 0` 会让点「开始推流」变成崩溃,而不是一条失败提示。
    test('越界的帧率/质量被夹到区间内，不退回默认也不越界', () {
      final low = EBadgeDebugConfig.fromJson(const {
        'cameraFps': 0,
        'cameraQuality': -5,
      });
      expect(low.cameraFps, kEBadgeStreamFpsMin);
      expect(low.cameraQuality, kEBadgeStreamQualityMin);

      final high = EBadgeDebugConfig.fromJson(const {
        'cameraFps': 9999,
        'cameraQuality': 300,
      });
      expect(high.cameraFps, kEBadgeStreamFpsMax);
      expect(high.cameraQuality, kEBadgeStreamQualityMax);
    });

    // 滑条给的是整数,但手改的配置里可能是小数(或 jsonDecode 把 25 读成 25.0)。
    // `as int` 会抛,而抛出去就是整份配置退回默认。
    test('小数值被截成整数，不抛', () {
      final back = EBadgeDebugConfig.fromJson(const {
        'cameraFps': 12.7,
        'cameraQuality': 55.9,
      });
      expect(back.cameraFps, 12);
      expect(back.cameraQuality, 55);
    });

    // 关键一条:示例图被换掉、某档被删,旧配置里的 slug 就成了野值。此时必须退回
    // 已知档位 —— 否则 demoPresetIndex 会给出 -1,`kEBadgeDemoPresets[-1]` 直接
    // 让页面在 build 里崩,而崩因是一个几个月前存下的字符串,极难归因。
    test('认不出的档位 slug 退回默认，不产生越界索引', () {
      final back = EBadgeDebugConfig.fromJson(
          const {'demoPresetSlug': 'no-such-preset'});
      expect(back.demoPresetSlug, kDefaultDemoPresetSlug);
      expect(back.demoPresetIndex, 0);
    });

    test('认不出的帧源名退回内置帧', () {
      expect(EBadgeStreamSource.byName('h264'), EBadgeStreamSource.builtin);
      expect(EBadgeStreamSource.byName(null), EBadgeStreamSource.builtin);
      expect(EBadgeStreamSource.byName('camera'), EBadgeStreamSource.camera);
    });
  });

  group('档位索引', () {
    test('每一档的 slug 都能换算回自己的下标', () {
      for (var i = 0; i < kEBadgeDemoPresets.length; i++) {
        final cfg =
            EBadgeDebugConfig(demoPresetSlug: kEBadgeDemoPresets[i].slug);
        expect(cfg.demoPresetIndex, i,
            reason: '${kEBadgeDemoPresets[i].slug} 应换算到 $i');
      }
    });
  });

  group('copyWith', () {
    test('只改指定的那一项', () {
      const base = EBadgeDebugConfig();
      final a = base.copyWith(xferWithHeader: true);
      expect(a.xferWithHeader, isTrue);
      expect(a.demoPresetSlug, base.demoPresetSlug);
      expect(a.streamSource, base.streamSource);
      expect(a.autoScroll, base.autoScroll);
      expect(a.cameraFps, base.cameraFps);
      expect(a.cameraQuality, base.cameraQuality);

      // false 不能被当成「没传」—— 命名可选参数配 `?? this.x` 时,把 bool 写成
      // 非空类型就会吞掉关掉开关的那次调用,现象是「这个开关关不掉」。
      final b = a.copyWith(xferWithHeader: false);
      expect(b.xferWithHeader, isFalse);
      final c = base.copyWith(autoScroll: false);
      expect(c.autoScroll, isFalse);
    });

    // 两条滑条各自独立:拖帧率不能顺带把质量改回默认。它们是同一次调试里的两个
    // 自变量,互相污染的话「哪个变化导致跳帧」就没法归因了。
    test('两条滑条互不影响', () {
      const base = EBadgeDebugConfig();
      final fps = base.copyWith(cameraFps: 40);
      expect(fps.cameraFps, 40);
      expect(fps.cameraQuality, base.cameraQuality);

      final both = fps.copyWith(cameraQuality: 20);
      expect(both.cameraQuality, 20);
      expect(both.cameraFps, 40, reason: '改质量不该把帧率带回默认');
    });

    test('改 OTA 路径不动其余各项，改其余各项也不丢 OTA 路径', () {
      const base = EBadgeDebugConfig();
      final a = base.copyWith(otaFilePath: '/tmp/fw.bin');
      expect(a.otaFilePath, '/tmp/fw.bin');
      expect(a.cameraFps, base.cameraFps);
      expect(a.demoPresetSlug, base.demoPresetSlug);

      final b = a.copyWith(cameraFps: 30);
      expect(b.otaFilePath, '/tmp/fw.bin', reason: '改帧率不该把选好的包丢掉');
    });

    // 可空字段没法用 `?? this.x` 表达「清空」—— 传 null 和不传是同一件事,所以另给
    // 一个显式开关。少了它,选过的包就再也去不掉,只能整个重建配置对象。
    test('clearOtaFilePath 能真的清掉路径', () {
      final a = const EBadgeDebugConfig().copyWith(otaFilePath: '/tmp/fw.bin');
      expect(a.copyWith(clearOtaFilePath: true).otaFilePath, isNull);
      // 传 null 不等于清空(那是「没传」),这一点要钉住,否则将来有人以为能这么清。
      expect(a.copyWith(otaFilePath: null).otaFilePath, '/tmp/fw.bin');
    });
  });
}
