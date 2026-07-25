import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/current_app_provider.dart';
import '../scan/scan_page.dart';
import 'watch_device_page.dart';

/// Watch 应用根：结构与 EBadgeAppRoot 一致。
/// [PopScope] 保证返回 Launcher 时 disconnect + 清 currentApp（spec §4.4）。
class WatchAppRoot extends ConsumerWidget {
  const WatchAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (prev != null && next == null) {
        Navigator.of(context).popUntil((r) => r.settings.name == '/watch-root');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final connected = ref.watch(connectedDeviceProvider);
    final child = connected != null
        ? WatchDevicePage(
            deviceName: connected.name,
            deviceId: connected.deviceId,
          )
        : const ScanPage(
            defaultDeviceFilter: 'Watch',
            appTitle: 'Watch',
          );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ref.read(bleNotifierProvider.notifier).disconnect();
        ref.read(currentAppProvider.notifier).state = null;
      },
      child: child,
    );
  }
}
