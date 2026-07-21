import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../providers/transfer_provider.dart';

/// Format file size in bytes to a human-readable string.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Compact selectable pill for the preset rows on the send pages (尺寸 / fps /
/// 质量). Deliberately smaller than a default [ChoiceChip] — 12px label, tight
/// padding, a shrink-wrapped tap target and no check mark — so a row of presets
/// stays tidy and fits more options without wrapping. Colors are left to the
/// ambient theme, so it matches each page's chips and only changes their size.
class PresetChip extends StatelessWidget {
  /// Text shown inside the pill.
  final String label;

  /// Whether this preset is the current selection.
  final bool selected;

  /// Tapped callback; null disables the chip (e.g. while sending / busy).
  final VoidCallback? onTap;

  const PresetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      showCheckmark: false,
      labelStyle: const TextStyle(fontSize: 12),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }
}

/// Paints a dashed rectangular border around a given [Rect].
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6,
    this.dashGap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = min(distance + dashWidth, metric.length);
        final segmentPath = metric.extractPath(distance, end);
        canvas.drawPath(segmentPath, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Shared layout widget for file-send pages (image, GIF, video).
///
/// Renders the common pattern:
///   - LinearProgressIndicator (visible only while sending)
///   - Dashed-border tap-to-pick area (icon + hint, or filename + size)
///   - Status text (progress / success / error)
///   - Action button (send or cancel)
class FileSendLayout extends StatelessWidget {
  /// Currently selected file name, or null if none selected.
  final String? fileName;

  /// Currently selected file size in bytes, or null.
  final int? fileSize;

  /// Reactive transfer state from the provider.
  final TransferState transferState;

  /// Called when the user taps the pick area.
  final VoidCallback onPick;

  /// Called when the user taps the send button.
  final VoidCallback onSend;

  /// Called when the user taps the cancel button (during sending).
  final VoidCallback onCancel;

  /// Hint text shown inside the pick area (e.g. "点击选择图片").
  final String hintText;

  /// Icon shown inside the pick area.
  final IconData pickIcon;

  const FileSendLayout({
    super.key,
    this.fileName,
    this.fileSize,
    required this.transferState,
    required this.onPick,
    required this.onSend,
    required this.onCancel,
    required this.hintText,
    required this.pickIcon,
  });

  bool get _isSending => transferState.status == TransferStatus.sending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Progress bar (only during sending) ---
          if (_isSending)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(
                value: transferState.progress,
                backgroundColor: colorScheme.surfaceVariant,
                color: colorScheme.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

          // --- File pick area (dashed border) ---
          GestureDetector(
            onTap: _isSending ? null : onPick,
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: fileName != null
                    ? colorScheme.primary.withOpacity(0.5)
                    : colorScheme.outline,
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: fileName != null
                    ? _buildFileInfo(theme, colorScheme)
                    : _buildPickHint(theme, colorScheme),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Status text ---
          _buildStatusText(theme, colorScheme),

          const SizedBox(height: 20),

          // --- Action button ---
          if (_isSending)
            FilledButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('取消'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            FilledButton.icon(
              onPressed: fileName != null ? onSend : null,
              icon: const Icon(Icons.send),
              label: const Text('发送到设备'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Pick area content when no file is selected.
  Widget _buildPickHint(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(pickIcon, size: 48, color: colorScheme.outline),
        const SizedBox(height: 12),
        Text(
          hintText,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Pick area content when a file is selected.
  Widget _buildFileInfo(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(pickIcon, size: 32, color: colorScheme.primary),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (fileSize != null)
                Text(
                  formatFileSize(fileSize!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the status text based on transfer state.
  Widget _buildStatusText(ThemeData theme, ColorScheme colorScheme) {
    final state = transferState;

    switch (state.status) {
      case TransferStatus.idle:
        return const SizedBox.shrink();

      case TransferStatus.sending:
        final pct = (state.progress * 100).toInt();
        return Text(
          '$pct% · ${state.speedKBs} KB/s',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        );

      case TransferStatus.done:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 20, color: colorScheme.secondary),
            const SizedBox(width: 6),
            Text(
              '发送成功',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case TransferStatus.error:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 20, color: colorScheme.error),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                state.errorMessage ?? '发送失败',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
    }
  }
}
