import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/current_app_provider.dart';
import '../../providers/transfer_provider.dart';
import '../launcher/app_catalog.dart';
import '../launcher/connected_app.dart';
import '../scan/scan_page.dart';
import '../device/device_page.dart';

/// eBadge 应用根:Launcher 之上的第一个页面,作为连接状态门。
/// - 未连接 → [ScanPage](过滤 eBadge 设备名前缀)
/// - 已连接 → [DevicePage]
///
/// 断连时通过 `popUntil((r) => r.settings.name == '/ebadge-root')`
/// 弹回自己,而不弹到 Launcher。
///
/// 返回 Launcher 不主动断开设备；连接由设备页的“断开”按钮显式结束。
/// Launcher 继续展示连接状态，再次点击应用可直接回到设备页。
class EBadgeAppRoot extends ConsumerStatefulWidget {
  const EBadgeAppRoot({super.key});

  @override
  ConsumerState<EBadgeAppRoot> createState() => _EBadgeAppRootState();
}

class _EBadgeAppRootState extends ConsumerState<EBadgeAppRoot> {
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (connectedDeviceMatchesApp(prev, AppId.ebadge) &&
          !connectedDeviceMatchesApp(next, AppId.ebadge) &&
          !_leaving) {
        ref.read(transferProgressProvider.notifier).reset();
        Navigator.of(context)
            .popUntil((r) => r.settings.name == '/ebadge-root');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final allConnected = ref.watch(connectedDeviceProvider);
    final connected = connectedDeviceMatchesApp(allConnected, AppId.ebadge)
        ? allConnected
        : null;
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
        if (didPop) {
          _leaving = true;
          // 未连接分支:pop 已完成,回到 Launcher。清理动作延到下一 frame,
          // 避免同步改 provider 时 subtree 已 deactivated 引发
          // markNeedsBuild-on-defunct 断言。
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(bleNotifierProvider.notifier).stopScan();
            ref.read(transferProgressProvider.notifier).reset();
            ref.read(currentAppProvider.notifier).state = null;
          });
        }
      },
      child: child,
    );
  }
}
