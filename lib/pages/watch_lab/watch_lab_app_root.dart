import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';
import '../../providers/current_app_provider.dart';

/// Watch Lab：当前仅挂载 JW SDK Demo（WS 包 Greenfield 重建中，不接 HoneyBox）。
class WatchLabAppRoot extends ConsumerWidget {
  const WatchLabAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ref.read(currentAppProvider.notifier).state = null;
      },
      child: const JWWatchLabAppRoot(),
    );
  }
}
