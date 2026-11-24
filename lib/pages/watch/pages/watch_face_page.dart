import 'package:flutter/material.dart';
import '../../../i18n/app_strings.dart';
import '../widgets/watch_feature_placeholder.dart';

/// 表盘推送 — 选择 / 自定义表盘并设为手表当前表盘。
class WatchFacePage extends StatelessWidget {
  const WatchFacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final watch = AppStrings.of(context).watch;
    return WatchFeaturePlaceholder(
      title: watch.cardFace,
      icon: Icons.palette_outlined,
      description: watch.faceDescription,
    );
  }
}
