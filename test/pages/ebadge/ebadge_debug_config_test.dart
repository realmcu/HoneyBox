import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ebadge/ebadge_debug_config.dart';
import 'package:honeybox/pages/ebadge/ebadge_demo_presets.dart';

/// 只测模型的默认值与序列化。[EBadgeDebugConfigStore] 的读写走
/// `getApplicationSupportDirectory`(平台通道),不在这里测。
void main() {
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
  });

  group('序列化', () {
    test('四项都能存能读回', () {
      const cfg = EBadgeDebugConfig(
        xferWithHeader: true,
        demoPresetSlug: 'xxl',
        streamSource: EBadgeStreamSource.camera,
        autoScroll: false,
      );
      final back = EBadgeDebugConfig.fromJson(cfg.toJson());
      expect(back.xferWithHeader, isTrue);
      expect(back.demoPresetSlug, 'xxl');
      expect(back.streamSource, EBadgeStreamSource.camera);
      expect(back.autoScroll, isFalse);
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
    });

    test('类型不对的值不抛，退回默认', () {
      final back = EBadgeDebugConfig.fromJson(const {
        'xferWithHeader': 'yes',
        'demoPresetSlug': 42,
        'streamSource': 7,
        'autoScroll': 'no',
      });
      expect(back.xferWithHeader, isFalse);
      expect(back.demoPresetSlug, kDefaultDemoPresetSlug);
      expect(back.streamSource, EBadgeStreamSource.builtin);
      expect(back.autoScroll, isTrue);
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

      // false 不能被当成「没传」—— 命名可选参数配 `?? this.x` 时,把 bool 写成
      // 非空类型就会吞掉关掉开关的那次调用,现象是「这个开关关不掉」。
      final b = a.copyWith(xferWithHeader: false);
      expect(b.xferWithHeader, isFalse);
      final c = base.copyWith(autoScroll: false);
      expect(c.autoScroll, isFalse);
    });
  });
}
