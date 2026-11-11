import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/current_app_provider.dart';
import 'sdk_demo_hub_page.dart';

/// 启动器「SDK Demo」一级入口：二级 Hub 内再进入 JW / WS Demo。
class SdkDemoAppRoot extends ConsumerWidget {
  const SdkDemoAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ref.read(currentAppProvider.notifier).state = null;
      },
      child: const SdkDemoHubPage(),
    );
  }
}
