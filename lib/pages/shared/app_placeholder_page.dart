import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';

/// 骨架应用（Watch / Dashboard）连接设备后展示的临时功能页。
/// 只显示应用名与已连接设备名，并提供断开按钮。
class AppPlaceholderPage extends ConsumerWidget {
  final String appTitle;
  final String deviceName;

  const AppPlaceholderPage({
    super.key,
    required this.appTitle,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(appTitle, style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('$appTitle 功能开发中', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('已连接：$deviceName',
                style: tt.bodyMedium?.copyWith(color: cs.outline)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(bleNotifierProvider.notifier).disconnect(),
              icon: const Icon(Icons.link_off),
              label: const Text('断开连接'),
            ),
          ],
        ),
      ),
    );
  }
}
