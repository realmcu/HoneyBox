import 'package:flutter/material.dart';

/// Watch 各功能子页当前的统一占位样式。业务逻辑接入后，各子页会用真正的
/// 内容替换掉本组件；在那之前四个入口（表盘 / 通知 / 健康 / OTA）共用它，
/// 避免复制四份几乎相同的 "开发中" 骨架。
class WatchFeaturePlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const WatchFeaturePlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: cs.primary),
              const SizedBox(height: 20),
              Text(
                '$title 功能开发中',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
