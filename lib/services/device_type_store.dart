// device_type_store.dart
//
// 设备类型(Demo / Mi)以及「设备 → 类型」的绑定记忆。
//
// 为什么要记绑定:同一个工位上来回连的常常是不同的样机,而两类设备能用的功能
// 完全不一样 —— 每换一台就手动切一次类型,漏切的结果是点进一台机器根本没有的
// 功能,然后拿着「设备一点反应都没有」去查链路,而问题只是点了不该点的卡片。
// 记下来之后换回来就自动切回去了。
//
// 键取 BLE 的 deviceId(Android 上就是 MAC),这是连接后唯一稳定、能跨进程复现的
// 标识:设备名不可靠(几台样机都叫 eBadge 是常态),而 iOS/macOS 给的是系统
// UUID —— 那种平台上这个键不是 MAC,但对「认出同一台设备」这件事同样成立,所以
// 不特殊处理。

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 功能选择界面上可切换的设备类型。
///
/// 类型决定**列出哪些功能卡片**(见 `pages/device/device_features.dart`),
/// 各页内部行为一概不变 —— 类型只是目录,不是权限。
enum DeviceType {
  /// 默认类型。没绑过、绑定认不出、读取失败,一律落回它。
  demo('Demo'),

  /// 小米(私有协议方向)样机。
  mi('Mi');

  const DeviceType(this.label);
  final String label;

  /// 按 [name] 反查,认不出退回 [demo]。
  ///
  /// 存的是名字而不是序号:枚举里插一项就会让旧文件里的序号指向另一个类型,
  /// 而「我明明选的是 Mi」这种偏差在界面上看不出来(卡片变了,但没人会想到是
  /// 存盘格式错位)。
  static DeviceType byName(String? name) => DeviceType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => DeviceType.demo,
      );
}

/// 把 `{deviceId: typeName}` 这层 JSON 解成绑定表。
///
/// **认不出的条目一律丢掉,而不是整份作废**:一条野值只该让那一台设备回到默认
/// 类型,没道理把其他几台已经绑好的设备一起忘掉。
Map<String, DeviceType> decodeDeviceTypeBindings(Object? raw) {
  if (raw is! Map) return <String, DeviceType>{};
  final out = <String, DeviceType>{};
  raw.forEach((key, value) {
    // 空键(以及非字符串的键)不认:它会把所有没有 id 的设备并成同一条记录。
    if (key is! String || key.isEmpty || value is! String) return;
    if (!DeviceType.values.any((t) => t.name == value)) return;
    out[key] = DeviceType.byName(value);
  });
  return out;
}

/// 绑定表的存盘形式 —— 单独提出来是为了能不碰平台通道地测。
Map<String, String> encodeDeviceTypeBindings(
        Map<String, DeviceType> bindings) =>
    bindings.map((id, type) => MapEntry(id, type.name));

/// 持久化「设备 → 类型」的绑定。
///
/// 与 `EBadgeDebugConfigStore` 同形(静态读写、失败一律吞掉):这是**尽力而为**的
/// 便利,存不下来最坏是下次回到默认类型,不该让一个只读文件系统把首页卡住。
///
/// 整份表在内存里缓存一份:首页每次连接都要查一次,而读盘是异步的 —— 不缓存的话
/// 每连一次就要开一次文件。写回时连内存一起更新,所以同一次运行里切完立刻重连也
/// 读得到。
class DeviceTypeBindingStore {
  DeviceTypeBindingStore._();

  static const _fileName = 'device_type_bindings.json';

  static Map<String, DeviceType>? _cache;

  /// 正在读盘的那一次。两处同时来查(页面 initState + 用户手快点了切换)不该读
  /// 两遍文件,更不该让后读到的结果覆盖掉先写进去的那条绑定。
  static Future<Map<String, DeviceType>>? _inflight;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<Map<String, DeviceType>> _bindings() async {
    final cached = _cache;
    if (cached != null) return cached;
    final pending = _inflight;
    if (pending != null) return pending;
    final future = _read();
    _inflight = future;
    try {
      return await future;
    } finally {
      _inflight = null;
    }
  }

  static Future<Map<String, DeviceType>> _read() async {
    Map<String, DeviceType> bindings = const <String, DeviceType>{};
    try {
      final file = await _file();
      if (await file.exists()) {
        bindings =
            decodeDeviceTypeBindings(jsonDecode(await file.readAsString()));
      }
    } catch (_) {
      // 文件不存在 / 坏了 / 平台通道不可用 —— 一律当成「没绑过」。
    }
    _cache = bindings;
    return bindings;
  }

  /// 这台设备上次绑定的类型;没绑过(或 [deviceId] 为空)返回 [DeviceType.demo]。
  ///
  /// 空 id 直接返回默认而不去查表:拿空串当键的话,所有「拿不到 id」的设备会互相
  /// 覆盖对方的绑定。
  static Future<DeviceType> typeFor(String deviceId) async {
    if (deviceId.isEmpty) return DeviceType.demo;
    final bindings = await _bindings();
    return bindings[deviceId] ?? DeviceType.demo;
  }

  /// 记住这台设备的类型并落盘。
  static Future<void> bind(String deviceId, DeviceType type) async {
    if (deviceId.isEmpty) return;
    final bindings = Map<String, DeviceType>.of(await _bindings());
    bindings[deviceId] = type;
    _cache = bindings;
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(encodeDeviceTypeBindings(bindings)));
    } catch (_) {
      // 见类文档:存不下来最坏是下次回到默认类型,内存里这次仍然生效。
    }
  }
}
