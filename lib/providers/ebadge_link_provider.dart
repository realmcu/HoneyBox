import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ebadge_link.dart';

/// eBadge 协议调试链路,按 deviceId 分族。
///
/// 与 `remoteControlSessionProvider` 那种「全 app 一个、跟随 BleManager 生命
/// 周期」的做法不同,这里用 `autoDispose` + `family`:
///
/// - `family`:link 自己持有 deviceId 并据此查找 GATT 特征,换设备必须换实例。
/// - `autoDispose`:它订阅了 f48affc2 的 notify 且缓存了日志。退出调试页就该
///   取消订阅、释放缓冲,不然日志会在后台一直涨,notify 也白占带宽。
final eBadgeLinkProvider =
    Provider.autoDispose.family<EBadgeLink, EBadgeLinkArgs>((ref, args) {
  final link = EBadgeLink(
    deviceId: args.deviceId,
    deviceName: args.deviceName,
  );
  ref.onDispose(link.dispose);
  return link;
});

/// [eBadgeLinkProvider] 的族参数。
///
/// 必须实现 `==` / `hashCode`:Riverpod 的 family 用参数相等性做实例缓存,
/// 不重写的话每次 build 传一个新对象都会被当成新设备,重建 link 并丢掉日志。
class EBadgeLinkArgs {
  const EBadgeLinkArgs({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;

  @override
  bool operator ==(Object other) =>
      other is EBadgeLinkArgs &&
      other.deviceId == deviceId &&
      other.deviceName == deviceName;

  @override
  int get hashCode => Object.hash(deviceId, deviceName);
}
