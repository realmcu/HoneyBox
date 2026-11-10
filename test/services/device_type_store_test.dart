import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/device_type_store.dart';

/// 只测绑定表的编解码 —— 落盘走 `getApplicationSupportDirectory`(平台通道),
/// 不在单测范围里。
void main() {
  group('绑定表解码', () {
    test('正常的一张表原样读回', () {
      final map = decodeDeviceTypeBindings(const {
        'AA:BB:CC:DD:EE:FF': 'mi',
        '11:22:33:44:55:66': 'demo',
      });
      expect(map, {
        'AA:BB:CC:DD:EE:FF': DeviceType.mi,
        '11:22:33:44:55:66': DeviceType.demo,
      });
    });

    // 关键一条:**认不出的条目只丢它自己**,不能整份作废。否则加一类设备之前存下
    // 的配置,或者一次手改,就会把其他几台已经绑好的设备一起忘掉 —— 而现象是
    // 「换回那台设备类型又变回 Demo 了」,极难归因到一条别的记录上。
    test('认不出的类型名只丢那一条，其余照旧', () {
      final map = decodeDeviceTypeBindings(const {
        'AA:BB:CC:DD:EE:FF': 'mi',
        '11:22:33:44:55:66': 'watch', // 没有这个类型
      });
      expect(map, {'AA:BB:CC:DD:EE:FF': DeviceType.mi});
    });

    // 空键会让所有「没有 id」的设备并成同一条记录 —— 一台机器切了类型,另一台
    // 跟着变。
    test('空键和非字符串的键/值都不收', () {
      final map = decodeDeviceTypeBindings(const {
        '': 'mi',
        42: 'mi',
        'AA:BB:CC:DD:EE:FF': 42,
        '11:22:33:44:55:66': null,
        'CC:DD:EE:FF:00:11': 'demo',
      });
      expect(map, {'CC:DD:EE:FF:00:11': DeviceType.demo});
    });

    test('不是 Map 的输入不抛，得到空表', () {
      expect(decodeDeviceTypeBindings(null), isEmpty);
      expect(decodeDeviceTypeBindings('{}'), isEmpty);
      expect(decodeDeviceTypeBindings(const <String>[]), isEmpty);
    });
  });

  group('绑定表编码', () {
    // 存的是类型名而不是序号 —— 序号会随枚举增删悄悄错位。
    test('存的是名字', () {
      expect(
        encodeDeviceTypeBindings(const {'AA:BB:CC:DD:EE:FF': DeviceType.mi}),
        {'AA:BB:CC:DD:EE:FF': 'mi'},
      );
    });

    test('存读一轮不丢', () {
      const original = {
        'AA:BB:CC:DD:EE:FF': DeviceType.mi,
        '11:22:33:44:55:66': DeviceType.demo,
      };
      expect(decodeDeviceTypeBindings(encodeDeviceTypeBindings(original)),
          original);
    });
  });
}
