import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/current_app_provider.dart';
import '../dashboard/dashboard_app_root.dart';
import '../ebadge/ebadge_app_root.dart';
import '../watch/watch_app_root.dart';
import 'app_catalog.dart';
import 'widgets/app_card.dart';

/// APK 打开时首先看到的页面。
/// 从 [kAppCatalog] 读取应用清单，展示为卡片列表。点击后 push 对应
/// `<App>AppRoot`（带 route name，供断连回退 popUntil 匹配）。
class AppLauncherPage extends ConsumerWidget {
  const AppLauncherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择应用'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => Navigator.pushNamed(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: '/settings', child: Text('设置')),
              PopupMenuItem(value: '/cache', child: Text('缓存管理')),
              PopupMenuItem(value: '/chip-config', child: Text('芯片配置')),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: kAppCatalog.length,
        itemBuilder: (_, i) {
          final entry = kAppCatalog[i];
          return AppCard(
            entry: entry,
            onTap: () => _launch(context, ref, entry),
          );
        },
      ),
    );
  }

  void _launch(BuildContext context, WidgetRef ref, AppEntry entry) {
    ref.read(currentAppProvider.notifier).state = entry.id;
    final name = routeNameFor(entry.id);
    Navigator.of(context).push(MaterialPageRoute(
      settings: RouteSettings(name: name),
      builder: (_) => _rootFor(entry),
    ));
  }

  Widget _rootFor(AppEntry entry) {
    switch (entry.id) {
      case AppId.ebadge:
        return const EBadgeAppRoot();
      case AppId.watch:
        return const WatchAppRoot();
      case AppId.dashboard:
        return const DashboardAppRoot();
    }
  }
}
