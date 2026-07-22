import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/current_app_provider.dart';
import '../scan/scan_page.dart';
import '../shared/app_placeholder_page.dart';

/// Dashboard（仪表盘）应用根：结构同 EBadgeAppRoot / WatchAppRoot。
/// [PopScope] 保证返回 Launcher 时 disconnect + 清 currentApp（spec §4.4）。
class DashboardAppRoot extends ConsumerWidget {
  const DashboardAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (prev != null && next == null) {
        Navigator.of(context)
            .popUntil((r) => r.settings.name == '/dashboard-root');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final connected = ref.watch(connectedDeviceProvider);
    final child = connected != null
        ? AppPlaceholderPage(
            appTitle: '仪表盘',
            deviceName: connected.name,
          )
        : const ScanPage(
            defaultDeviceFilter: 'Dashboard',
            appTitle: '仪表盘',
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
