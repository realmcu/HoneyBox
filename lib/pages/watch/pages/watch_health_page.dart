import 'package:flutter/material.dart';
import '../widgets/watch_feature_placeholder.dart';

/// 运动 / 健康 — 读取并展示手表的步数、心率、睡眠等数据。
class WatchHealthPage extends StatelessWidget {
  const WatchHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WatchFeaturePlaceholder(
      title: '运动 / 健康',
      icon: Icons.favorite_outline,
      description: '同步并展示步数、心率、睡眠等运动健康数据',
    );
  }
}
