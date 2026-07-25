import 'package:flutter/material.dart';
import '../widgets/watch_feature_placeholder.dart';

/// 固件 OTA 升级 — 检查并向手表推送固件更新。
class WatchOtaPage extends StatelessWidget {
  const WatchOtaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WatchFeaturePlaceholder(
      title: '固件 OTA 升级',
      icon: Icons.system_update_alt,
      description: '检查并向手表推送固件更新',
    );
  }
}
