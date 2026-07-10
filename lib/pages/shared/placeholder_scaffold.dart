import 'package:flutter/material.dart';

/// A simple "reserved / coming soon" screen used by app-level entries that are
/// wired up but not yet implemented (chip config, settings, …).
class PlaceholderScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.icon,
    this.message = '功能开发中，敬请期待',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(message, style: tt.bodyLarge),
          ],
        ),
      ),
    );
  }
}
