import 'package:flutter/material.dart';

/// Modal bottom sheet (~half screen) on the current page.
class WsDemoContentSheet extends StatelessWidget {
  const WsDemoContentSheet({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget body;

  static const TextStyle apiMonospaceStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    height: 1.5,
  );

  static const double sheetHeightFactor = 0.5;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget body,
  }) {
    final sheetHeight = MediaQuery.sizeOf(context).height * sheetHeightFactor;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: sheetHeight,
        child: WsDemoContentSheet(
          key: const Key('jw.demo.content_sheet'),
          title: title,
          subtitle: subtitle,
          body: body,
        ),
      ),
    );
  }

  static Future<void> showApiExample(
    BuildContext context, {
    required String stepTitle,
    required String code,
  }) {
    return show(
      context,
      title: stepTitle,
      subtitle: '公开 API 示例',
      body: SelectableText(code, style: apiMonospaceStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (subtitle != null) ...[
            Text(subtitle!, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: body,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
