import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_history_sync_state.dart';
import 'jw_settings_app_theme.dart';

const kJwDataHomeStepGoal = 8000;

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
  if (kcal <= 0) return '0 千卡';
  final rounded = kcal.round();
  if ((kcal - rounded).abs() < 0.05) return '$rounded 千卡';
  return '${kcal.toStringAsFixed(1)} 千卡';
}

String jwFormatHomeDistanceKm(double km) {
  if (km <= 0) return '0 公里';
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} 公里';
}

/// 数据首页顶区：今日概要（0x0B/0x0C）+ 历史同步进度条 + 操作按钮。
class JwDataHomeHeader extends StatelessWidget {
  const JwDataHomeHeader({
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
    this.stepGoal = kJwDataHomeStepGoal,
  });

  final JwHistorySyncRunState syncState;
  final JWTodayActivitySummary? summary;
  final bool loadingSummary;
  final bool todaySupported;
  final bool sessionReady;
  final bool syncing;
  final bool resettingMarkers;
  final VoidCallback? onSync;
  final VoidCallback? onResetMarkers;
  final int stepGoal;

  bool get _syncing => syncState.isActive;

  double get _syncProgress {
    if (syncState.awaitingDevicePlan) return 0.12;
    if (syncState.totalWire > 0) {
      return syncState.receivedWire / syncState.totalWire;
    }
    if (_syncing) return 0.25;
    return 0;
  }

  int get _stepPercent {
    final steps = summary?.steps ?? 0;
    if (stepGoal <= 0) return 0;
    return math.min(100, ((steps / stepGoal) * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    final showKpi = sessionReady && todaySupported;
    final stepRing = !_failedSync;
    final ringProgress = stepRing ? _stepPercent / 100.0 : 0.0;
    final ringColor = JwSettingsAppTheme.positiveButton;

    return Material(
      color: JwSettingsAppTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        key: const Key('jw.demo.data.sync_hero'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRing(
                  progress: ringProgress,
                  color: ringColor,
                  centerLarge: stepRing && sessionReady && todaySupported
                      ? '$_stepPercent%'
                      : '—',
                  centerSmall: '步数目标',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日活动',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: JwSettingsAppTheme.subtitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _headline(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: JwSettingsAppTheme.title,
                        ),
                      ),
                      if (_statusLine() != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _statusLine()!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _failedSync
                                ? JwSettingsAppTheme.warn
                                : JwSettingsAppTheme.subtitle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (sessionReady) ...[
              const SizedBox(height: 12),
              _HomeSyncProgressLine(
                key: const Key('jw.demo.data.sync_progress_line'),
                active: _syncing,
                indeterminate: _syncing &&
                    (syncState.awaitingDevicePlan || syncState.totalWire == 0),
                value: _syncProgress.clamp(0.0, 1.0),
              ),
              const SizedBox(height: 12),
              if (todaySupported)
                _KpiRow(summary: summary, loading: loadingSummary),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('jw.demo.data.sync_start'),
                    onPressed: sessionReady && onSync != null ? onSync : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: JwSettingsAppTheme.positiveButton,
                      foregroundColor: JwSettingsAppTheme.positiveButtonText,
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          JwSettingsAppTheme.buttonRadius,
                        ),
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
                      foregroundColor: JwSettingsAppTheme.title,
                      minimumSize: const Size(0, 40),
                      side: const BorderSide(color: JwSettingsAppTheme.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          JwSettingsAppTheme.buttonRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      resettingMarkers ? '发送中…' : '重置同步标记',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _failedSync => syncState.phase == JwHistorySyncPhase.failed;

  String _headline() {
    if (!sessionReady) return '未连接';
    if (!todaySupported) return '不支持今日概要';
    final s = summary;
    if (s == null) {
      return loadingSummary ? '读取今日数据…' : '今日活动';
    }
    return '${jwFormatHomeSteps(s.steps)} 步';
  }

  String? _statusLine() {
    return switch (syncState.phase) {
      JwHistorySyncPhase.idle => null,
      JwHistorySyncPhase.syncing => syncState.awaitingDevicePlan
          ? '历史同步 · 等待设备计划'
          : '历史同步 · ${syncState.receivedWire}/${syncState.totalWire}',
      JwHistorySyncPhase.success =>
        '上次同步 · ${syncState.receivedWire} 条',
      JwHistorySyncPhase.failed =>
        syncState.failure?.message ?? '同步失败',
    };
  }
}

/// 固定 3px 高度：空闲为分隔线，同步中为进度（不挤占下方按钮）。
class _HomeSyncProgressLine extends StatelessWidget {
  const _HomeSyncProgressLine({
    super.key,
    required this.active,
    required this.indeterminate,
    required this.value,
  });

  final bool active;
  final bool indeterminate;
  final double value;

  static const _lineHeight = 3.0;
  static const _track = Color(0xFFE6EAF3);

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return const SizedBox(
        height: _lineHeight,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(color: JwSettingsAppTheme.divider),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(1.5),
      child: SizedBox(
        height: _lineHeight,
        width: double.infinity,
        child: LinearProgressIndicator(
          minHeight: _lineHeight,
          value: indeterminate ? null : value,
          backgroundColor: _track,
          color: JwSettingsAppTheme.accent,
        ),
      ),
    );
  }
}

class _HeaderRing extends StatelessWidget {
  const _HeaderRing({
    required this.progress,
    required this.color,
    required this.centerLarge,
    required this.centerSmall,
  });

  final double progress;
  final Color color;
  final String centerLarge;
  final String centerSmall;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLarge,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: JwSettingsAppTheme.title,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerSmall,
                style: const TextStyle(
                  fontSize: 11,
                  color: JwSettingsAppTheme.subtitle,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 7.0;
    final radius = (size.shortestSide - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final track = Paint()
      ..color = const Color(0xFFE6EAF3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        fg,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.summary, required this.loading});

  final JWTodayActivitySummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final steps = s == null
        ? (loading ? '…' : '—')
        : jwFormatHomeSteps(s.steps);
    final kcal =
        s == null ? (loading ? '…' : '—') : jwFormatHomeKcal(s.caloriesKcal);
    final km =
        s == null ? (loading ? '…' : '—') : jwFormatHomeDistanceKm(s.distanceKm);

    return Row(
      children: [
        Expanded(child: _KpiCell(label: '步数', value: steps)),
        Expanded(child: _KpiCell(label: '卡路里', value: kcal)),
        Expanded(child: _KpiCell(label: '距离', value: km)),
      ],
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: JwSettingsAppTheme.title,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: JwSettingsAppTheme.muted,
          ),
        ),
      ],
    );
  }
}
