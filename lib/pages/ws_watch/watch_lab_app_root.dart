import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';
import '../../providers/current_app_provider.dart';

/// Watch Lab 入口：两个独立按钮，分别进入 JW / WS Lab（WS 暂未开放）。
class WatchLabHubPage extends ConsumerWidget {
  const WatchLabHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ref.read(currentAppProvider.notifier).state = null;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Watch Lab')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '选择协议实验室（独立全屏，非 Tab 切换）',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.watch),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('JW Watch Lab'),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JWWatchLabAppRoot(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.hourglass_empty),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('WS Watch Lab（暂未重构）'),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('WS Lab 尚未接入新框架，当前仅推进 JW')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// @deprecated 使用 [WatchLabHubPage]。
typedef WatchLabAppRoot = WatchLabHubPage;
