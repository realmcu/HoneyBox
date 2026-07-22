import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/current_app_provider.dart';
import '../../providers/transfer_provider.dart';
import '../scan/scan_page.dart';
import '../device/device_page.dart';

/// eBadge 应用根：Launcher 之上的第一个页面，作为连接状态门。
/// - 未连接 → [ScanPage]（过滤 eBadge 设备名前缀）
/// - 已连接 → [DevicePage]
///
/// 断连时通过 `popUntil((r) => r.settings.name == '/ebadge-root')`
/// 弹回自己，而不弹到 Launcher。用户按返回键回到 Launcher 时（spec §4.4）
/// 通过 [PopScope] 主动 disconnect + 重置 transferProgress + 清 currentApp，
/// 避免 BLE 状态泄漏到下一个应用。
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
    final child = connected != null
        ? DevicePage(
            deviceName: connected.name,
            deviceId: connected.deviceId,
          )
        : const ScanPage(
            defaultDeviceFilter: 'eBadge',
            appTitle: 'eBadge',
          );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // 用户返回到 Launcher — 断开 BLE，重置传输状态，清 currentApp。
        // disconnect 是 fire-and-forget：Bluetooth 断开是纯副作用，不需要
        // 阻塞 pop 完成。
        ref.read(bleNotifierProvider.notifier).disconnect();
        ref.read(transferProgressProvider.notifier).reset();
        ref.read(currentAppProvider.notifier).state = null;
      },
      child: child,
    );
  }
}
