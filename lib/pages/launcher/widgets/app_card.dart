import 'package:flutter/material.dart';
import '../app_catalog.dart';

/// 应用启动器里的一张卡片：图标 + 标题 + 副标题；
/// 未实现应用（`entry.implemented == false`）右上角显示"预览"角标。
class AppCard extends StatelessWidget {
  final AppEntry entry;
  final VoidCallback onTap;

  const AppCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: entry.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, size: 32, color: entry.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.title, style: tt.titleMedium),
                        if (!entry.implemented) ...[
                          const SizedBox(width: 8),
                          _PreviewBadge(color: cs.outline),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  final Color color;
  const _PreviewBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('预览', style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
