import 'package:flutter/material.dart';

/// One acceptance test row under a group (placeholder until T4 implements tap).
class LabTestItemModel {
  const LabTestItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.implemented = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool implemented;
}

class LabTestGroupModel {
  const LabTestGroupModel({required this.title, required this.items});

  final String title;
  final List<LabTestItemModel> items;
}

/// Grouped checklist shown after lab device is connected.
class LabTestGroupSection extends StatelessWidget {
  const LabTestGroupSection({
    super.key,
    required this.group,
    required this.onItemTap,
  });

  final LabTestGroupModel group;
  final void Function(LabTestItemModel item) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(group.title, style: Theme.of(context).textTheme.titleMedium),
        children: [
          for (final item in group.items)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: item.implemented
                  ? const Icon(Icons.play_circle_outline)
                  : Chip(
                      label: Text(
                        '占位',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
              onTap: () => onItemTap(item),
            ),
        ],
      ),
    );
  }
}
