import 'package:flutter/material.dart';
import '../widgets/watch_feature_placeholder.dart';

/// 通知转发 — 配置手机通知同步到手表。
class WatchNotificationPage extends StatelessWidget {
  const WatchNotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WatchFeaturePlaceholder(
      title: '通知转发',
      icon: Icons.notifications_active_outlined,
      description: '配置手机通知同步到手表并管理消息类型开关',
    );
  }
}
