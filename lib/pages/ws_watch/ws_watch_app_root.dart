import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import '../../providers/current_app_provider.dart';

/// WS Watch 应用根：挂载 ws_watch_demo 的入口页面。
/// 蓝牙连接由 SDK 自己管理，不经过 HoneyBox 的 BleManager。
class WSWatchAppRoot extends ConsumerWidget {
  const WSWatchAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ref.read(currentAppProvider.notifier).state = null;
      },
      child: const WSWatchDemoHome(),
    );
  }
}
