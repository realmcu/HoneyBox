import 'package:flutter/material.dart';
import '../shared/placeholder_scaffold.dart';

/// 设置 — reserved. App/device settings UI to be implemented later.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(title: '设置', icon: Icons.settings_outlined);
  }
}
