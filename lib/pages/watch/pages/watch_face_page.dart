import 'package:flutter/material.dart';
import '../widgets/watch_feature_placeholder.dart';

/// 表盘推送 — 选择 / 自定义表盘并设为手表当前表盘。
class WatchFacePage extends StatelessWidget {
  const WatchFacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WatchFeaturePlaceholder(
      title: '表盘推送',
      icon: Icons.palette_outlined,
      description: '选择或自定义表盘，并推送设为手表当前表盘',
    );
  }
}
