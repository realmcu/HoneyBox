import 'package:flutter/material.dart';

/// OTA 升级 — the firmware update itself is performed in the Realtek OTA app,
/// so this screen just directs the user there.
class OtaPage extends StatelessWidget {
  const OtaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('OTA 升级')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_alt, size: 64, color: cs.primary),
              const SizedBox(height: 20),
              Text(
                '请在 Realtek OTA app 使用升级功能',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
