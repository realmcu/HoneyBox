import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../scan/scan_page.dart';
import '../shared/app_placeholder_page.dart';

/// Dashboard（仪表盘）应用根：结构同 EBadgeAppRoot / WatchAppRoot。
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
    if (connected != null) {
      return AppPlaceholderPage(
        appTitle: '仪表盘',
        deviceName: connected.name,
      );
    }
    return const ScanPage(
      defaultDeviceFilter: 'Dashboard',
      appTitle: '仪表盘',
    );
  }
}
