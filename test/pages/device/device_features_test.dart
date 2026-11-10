import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/device/device_features.dart';
import 'package:honeybox/services/device_type_store.dart';

/// 只测「哪类设备列哪些卡片」这个纯函数与它的目录常量。
/// `DeviceTypeBindingStore` 的读写走 `getApplicationSupportDirectory`(平台通道),
/// 不在这里测;它的纯解码逻辑在 device_type_store_test.dart 里。
void main() {
  group('两类设备的功能目录', () {
    // 需求本身:Demo 用当前页面上除「协议调试」之外的那几张卡。
    test('Demo 列出业务功能卡,但不含协议调试', () {
      final routes =
          deviceFeaturesFor(DeviceType.demo).map((f) => f.route).toList();
      expect(routes, [
        '/image',
        '/danmaku',
        '/video',
        '/slideshow',
        '/stream',
        '/ota',
      ]);
      expect(routes, isNot(contains('/ebadge-debug')));
    });

    // 需求本身:Mi 目前只有协议调试。
    test('Mi 只列协议调试', () {
      final routes =
          deviceFeaturesFor(DeviceType.mi).map((f) => f.route).toList();
      expect(routes, ['/ebadge-debug']);
    });

    // 两张清单加起来必须正好是全部目录 —— 有卡片谁都不给就等于从界面上消失了,
    // 而这种「少了张卡」没人会当成 bug 报上来。
    test('每一张卡片都至少属于一类设备', () {
      final reachable = DeviceType.values
          .expand((t) => deviceFeaturesFor(t))
          .map((f) => f.route)
          .toSet();
      expect(reachable, kDeviceFeatures.map((f) => f.route).toSet());
    });

    // 协议调试是这条需求的由头:D它的路由必须在两类之间真的被分开了。
    test('协议调试只对 Mi 可见', () {
      final debug =
          kDeviceFeatures.firstWhere((f) => f.route == '/ebadge-debug');
      expect(debug.showsFor(DeviceType.mi), isTrue);
      expect(debug.showsFor(DeviceType.demo), isFalse);
    });
  });

  group('目录自身的约束', () {
    // 路由重复的话,同一张卡会在网格里出现两次,点哪个都跳同一页 —— 看着像渲染
    // 出了 bug。
    test('路由不重复', () {
      final routes = kDeviceFeatures.map((f) => f.route).toList();
      expect(routes.toSet().length, routes.length);
    });

    test('每张卡都有标题和图标', () {
      for (final f in kDeviceFeatures) {
        expect(f.title, isNotEmpty, reason: f.route);
        expect(f.types, isNotEmpty, reason: f.route);
      }
    });

    // 顺序是界面上的展示顺序(两列网格按行填),所以 Demo 那几张的相对顺序要与
    // 改造之前一致 —— 用户的手指记着位置。
    test('列出时保持目录顺序', () {
      final all = deviceFeaturesFor(DeviceType.demo).map((f) => f.route);
      final expected = kDeviceFeatures
          .where((f) => f.showsFor(DeviceType.demo))
          .map((f) => f.route);
      expect(all.toList(), expected.toList());
    });
  });

  group('设备类型', () {
    // 需求本身:默认 Demo。
    test('认不出的名字退回 Demo', () {
      expect(DeviceType.byName(null), DeviceType.demo);
      expect(DeviceType.byName(''), DeviceType.demo);
      expect(DeviceType.byName('mi'), DeviceType.mi);
      expect(DeviceType.byName('Mi'), DeviceType.demo,
          reason: '认的是 name,不是 label');
    });

    test('两类都在,标签就是界面上显示的那两个字', () {
      expect(DeviceType.values.map((t) => t.name), ['demo', 'mi']);
      expect(DeviceType.demo.label, 'Demo');
      expect(DeviceType.mi.label, 'Mi');
    });
  });
}
