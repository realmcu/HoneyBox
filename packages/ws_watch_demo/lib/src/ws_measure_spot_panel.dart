import 'package:flutter/material.dart';

class WsMeasureSpotPanel extends StatelessWidget {
  const WsMeasureSpotPanel({
    super.key,
    required this.accent,
    required this.valueText,
    required this.placeholderUnit,
    required this.statusText,
    required this.measuring,
    required this.busy,
    required this.blockStart,
    required this.onToggle,
    this.onCheck,
  });

  final Color accent;
  final String? valueText;
  final String placeholderUnit;
  final String statusText;
  final bool measuring;
  final bool busy;
  final bool blockStart;
  final VoidCallback onToggle;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = valueText ?? '--';
    final canToggle = measuring || !blockStart;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.92),
            accent.withValues(alpha: 0.55),
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.65),
                        width: measuring ? 4 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: measuring ? 24 : 8,
                          spreadRadius: measuring ? 2 : 0,
                        ),
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          display,
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        if (placeholderUnit.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            placeholderUnit,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: accent,
                    minimumSize: const Size(120, 44),
                  ),
                  onPressed: busy || !canToggle ? null : onToggle,
                  child: Text(measuring ? '结束测量' : '开始测量'),
                ),
                if (onCheck != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: busy || blockStart ? null : onCheck,
                    child: const Text('Check'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
