import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/transfer_provider.dart';
import '../scan/scan_page.dart';
import '../device/device_page.dart';

/// eBadge 应用根：Launcher 之上的第一个页面，作为连接状态门。
/// - 未连接 → [ScanPage]（过滤 eBadge 设备名前缀）
/// - 已连接 → [DevicePage]
///
/// 断连时通过 `popUntil((r) => r.settings.name == '/ebadge-root')`
/// 弹回自己，而不弹到 Launcher。
class EBadgeAppRoot extends ConsumerWidget {
  const EBadgeAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (prev != null && next == null) {
        ref.read(transferProgressProvider.notifier).reset();
        Navigator.of(context)
            .popUntil((r) => r.settings.name == '/ebadge-root');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final connected = ref.watch(connectedDeviceProvider);
    if (connected != null) {
      return DevicePage(
        deviceName: connected.name,
        deviceId: connected.deviceId,
      );
    }
    return const ScanPage(
      defaultDeviceFilter: 'eBadge',
      appTitle: 'eBadge',
    );
  }
}
