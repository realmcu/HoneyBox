import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_history_sync_state.dart';
import 'ws_settings_app_theme.dart';
import 'compat/ws_demo_compat.dart';

String jwFormatHomeSteps(int steps) {
  final text = steps.toString();
  final buf = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final left = text.length - i;
    if (i > 0 && left % 3 == 0) buf.write(',');
    buf.write(text[i]);
  }
  return buf.toString();
}

String jwFormatHomeKcal(double kcal) {
  if (kcal <= 0) return '0';
  final rounded = kcal.round();
  if ((kcal - rounded).abs() < 0.05) return '$rounded';
  return kcal.toStringAsFixed(1);
}

String jwFormatHomeDistanceKm(double km) {
  if (km <= 0) return '0';
  return km.toStringAsFixed(km < 10 ? 1 : 0);
}

/// 数据首页顶区（对齐 [docs/jw-data-home-header-prototype] v0.4）。
class WsDataHomeHeader extends StatelessWidget {
  const WsDataHomeHeader({
    super.key,
    required this.syncState,
    required this.summary,
    required this.loadingSummary,
    required this.todaySupported,
    required this.sessionReady,
    required this.syncing,
    required this.resettingMarkers,
    required this.onSync,
    required this.onResetMarkers,
  });

  final WsHistorySyncRunState syncState;
  final WSTodayActivitySummary? summary;
  final bool loadingSummary;
  final bool todaySupported;
  final bool sessionReady;
  final bool syncing;
  final bool resettingMarkers;
  final VoidCallback? onSync;
  final VoidCallback? onResetMarkers;

  bool get _syncing => syncState.isActive;

  double get _syncProgress {
    if (syncState.totalWire > 0) {
      return syncState.receivedWire / syncState.totalWire;
    }
    return 0;
  }

  bool get _progressIndeterminate =>
      _syncing && syncState.totalWire <= 0;

  _SyncCaptionModel get _caption => _buildCaption();

  @override
  Widget build(BuildContext context) {
    final showMetrics = sessionReady && todaySupported;
    final caption = _caption;

    return Material(
      color: WsSettingsAppTheme.card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: const Color(0x1A171C3C),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12171C3C),
              blurRadius: 24,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          key: const Key('jw.demo.data.sync_hero'),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '今日活动',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WsSettingsAppTheme.accent,
                ),
              ),
              const SizedBox(height: 6),
              _SyncCaptionRow(
                hint: caption.hint,
                count: caption.count,
                warn: caption.warn,
              ),
              const SizedBox(height: 10),
              _HomeSyncProgressLine(
                key: const Key('jw.demo.data.sync_progress_line'),
                active: sessionReady && _syncing,
                indeterminate: sessionReady && _progressIndeterminate,
                showTrack: sessionReady,
                value: _syncProgress.clamp(0.0, 1.0),
              ),
              const SizedBox(height: 16),
              if (!sessionReady)
                const _MetricsPlaceholder()
              else if (!todaySupported)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '不支持今日概要',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: WsSettingsAppTheme.subtitle,
                    ),
                  ),
                )
              else
                Opacity(
                  opacity: showMetrics ? 1 : 0.45,
                  child: _MetricsRow(
                    summary: summary,
                    loading: loadingSummary,
                  ),
                ),
              const SizedBox(height: 16),
              _SyncDock(
                sessionReady: sessionReady,
                syncing: syncing,
                resettingMarkers: resettingMarkers,
                highlight: sessionReady && _syncing,
                onSync: onSync,
                onResetMarkers: onResetMarkers,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SyncCaptionModel _buildCaption() {
    if (!sessionReady) {
      return const _SyncCaptionModel(hint: '请先连接设备');
    }
    return switch (syncState.phase) {
      WsHistorySyncPhase.idle =>
        const _SyncCaptionModel(hint: '可同步手表历史数据'),
      WsHistorySyncPhase.syncing => _SyncCaptionModel(
          hint: '正在同步历史数据',
          count: syncState.totalWire > 0
              ? '${syncState.receivedWire} / ${syncState.totalWire}'
              : null,
        ),
      WsHistorySyncPhase.success => syncState.receivedWire > 0
          ? _SyncCaptionModel(
              hint: '上次同步完成',
              count: '${syncState.receivedWire} 条',
            )
          : const _SyncCaptionModel(hint: '上次同步完成'),
      WsHistorySyncPhase.failed => const _SyncCaptionModel(
            hint: '同步失败，请重试',
            warn: true,
          ),
    };
  }
}

class _SyncCaptionModel {
  const _SyncCaptionModel({
    required this.hint,
    this.count,
    this.warn = false,
  });

  final String hint;
  final String? count;
  final bool warn;
}

class _SyncCaptionRow extends StatelessWidget {
  const _SyncCaptionRow({
    required this.hint,
    required this.count,
    required this.warn,
  });

  final String hint;
  final String? count;
  final bool warn;

  static const _rowHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final showCount = count != null && count!.isNotEmpty;
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: warn ? FontWeight.w600 : FontWeight.w500,
                color: warn ? WsSettingsAppTheme.warn : WsSettingsAppTheme.subtitle,
              ),
            ),
          ),
          if (showCount) ...[
            const SizedBox(width: 12),
            Text(
              count!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
                color: WsSettingsAppTheme.title,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncDock extends StatelessWidget {
  const _SyncDock({
    required this.sessionReady,
    required this.syncing,
    required this.resettingMarkers,
    required this.highlight,
    required this.onSync,
    required this.onResetMarkers,
  });

  final bool sessionReady;
  final bool syncing;
  final bool resettingMarkers;
  final bool highlight;
  final VoidCallback? onSync;
  final VoidCallback? onResetMarkers;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight ? const Color(0x0F5C5CE0) : const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? WsSettingsAppTheme.accent.withValues(alpha: 0.35)
              : const Color(0xFFEBEFF5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('jw.demo.data.sync_start'),
                onPressed: sessionReady && onSync != null ? onSync : null,
                style: FilledButton.styleFrom(
                  backgroundColor: WsSettingsAppTheme.positiveButton,
                  foregroundColor: WsSettingsAppTheme.positiveButtonText,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(syncing ? '同步中…' : '同步'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                key: const Key('jw.demo.data.reset_sync_markers'),
                onPressed: sessionReady && !syncing && onResetMarkers != null
                    ? onResetMarkers
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: WsSettingsAppTheme.title,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: Color(0xFFEBEFF5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  resettingMarkers ? '发送中…' : '重置标记',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSyncProgressLine extends StatelessWidget {
  const _HomeSyncProgressLine({
    super.key,
    required this.active,
    required this.indeterminate,
    required this.showTrack,
    required this.value,
  });

  final bool active;
  final bool indeterminate;
  final bool showTrack;
  final double value;

  static const _lineHeight = 6.0;
  static const _track = Color(0xFFE6EAF3);

  @override
  Widget build(BuildContext context) {
    if (!showTrack) {
      return const SizedBox(height: _lineHeight);
    }
    if (!active) {
      return const SizedBox(
        height: _lineHeight,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _track,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: _lineHeight,
        width: double.infinity,
        child: LinearProgressIndicator(
          minHeight: _lineHeight,
          value: indeterminate ? null : value,
          backgroundColor: _track,
          color: WsSettingsAppTheme.accent,
        ),
      ),
    );
  }
}

class _MetricsPlaceholder extends StatelessWidget {
  const _MetricsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _MetricTile.empty(
            icon: Icons.directions_walk_rounded,
            colors: _MetricColors.steps,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricTile.empty(
            icon: Icons.local_fire_department_rounded,
            colors: _MetricColors.kcal,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MetricTile.empty(
            icon: Icons.place_rounded,
            colors: _MetricColors.distance,
          ),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.summary, required this.loading});

  final WSTodayActivitySummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final steps = s == null ? (loading ? '…' : '—') : jwFormatHomeSteps(s.steps);
    final kcal = s == null ? (loading ? '…' : '—') : jwFormatHomeKcal(s.caloriesKcal);
    final km = s == null ? (loading ? '…' : '—') : jwFormatHomeDistanceKm(s.distanceKm);

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.directions_walk_rounded,
            colors: _MetricColors.steps,
            value: steps,
            unit: '步',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: Icons.local_fire_department_rounded,
            colors: _MetricColors.kcal,
            value: kcal,
            unit: '千卡',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: Icons.place_rounded,
            colors: _MetricColors.distance,
            value: km,
            unit: '公里',
          ),
        ),
      ],
    );
  }
}

class _MetricColors {
  const _MetricColors({
    required this.background,
    required this.border,
    required this.iconGradient,
  });

  final Color background;
  final Color border;
  final List<Color> iconGradient;

  static const steps = _MetricColors(
    background: Color(0xFFFFF5F7),
    border: Color(0xFFFFE0E8),
    iconGradient: [Color(0xFFFF5C7A), Color(0xFFFF2D55)],
  );

  static const kcal = _MetricColors(
    background: Color(0xFFFFF9F2),
    border: Color(0xFFFFE8CC),
    iconGradient: [Color(0xFFFFB84D), Color(0xFFF28C28)],
  );

  static const distance = _MetricColors(
    background: Color(0xFFF6F7FF),
    border: Color(0xFFDDE2FF),
    iconGradient: [Color(0xFF7B7BEF), Color(0xFF5C5CE0)],
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.colors,
    required this.value,
    required this.unit,
  });

  const _MetricTile.empty({
    required this.icon,
    required this.colors,
  })  : value = '—',
        unit = '—';

  final IconData icon;
  final _MetricColors colors;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors.iconGradient,
                ),
              ),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
                color: WsSettingsAppTheme.title,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: WsSettingsAppTheme.subtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
