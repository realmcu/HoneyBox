import 'package:flutter/material.dart';

/// One row on a Watch Lab home (WS or JW).
class LabCapabilityTile extends StatelessWidget {
  const LabCapabilityTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

/// Optional footer hint under capability list.
class LabHomeHint extends StatelessWidget {
  const LabHomeHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}
