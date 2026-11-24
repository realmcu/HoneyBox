import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/app_strings.dart';
import '../../../providers/watch_bind_provider.dart';
import '../../../services/watch_health_protocol.dart';
import '../../../theme/app_theme.dart';
import '../health/watch_health_data.dart';
import '../health/watch_health_provider.dart';

class WatchHealthPage extends ConsumerStatefulWidget {
  const WatchHealthPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  final String deviceName;
  final String deviceId;

  @override
  ConsumerState<WatchHealthPage> createState() => _WatchHealthPageState();
}

class _WatchHealthPageState extends ConsumerState<WatchHealthPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAndSync());
  }

  Future<void> _restoreAndSync() async {
    if (!mounted) return;
    final notifier = ref.read(watchHealthProvider(widget.deviceId).notifier);
    await notifier.restore();
    if (!mounted ||
        ref.read(watchBindProvider).phase != WatchBindPhase.success) {
      return;
    }
    await notifier.sync();
  }

  @override
  Widget build(BuildContext context) {
    final provider = watchHealthProvider(widget.deviceId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final syncing = state.phase == WatchHealthSyncPhase.syncing;
    final bound = ref.watch(watchBindProvider).phase == WatchBindPhase.success;

    ref.listen(provider, (previous, next) {
      if (next.phase != WatchHealthSyncPhase.failure ||
          previous?.phase == next.phase) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).watch.healthTitle),
        actions: [
          IconButton(
            key: const Key('watch-health-sync'),
            tooltip: AppStrings.of(context).watch.syncHealthTooltip,
            onPressed: syncing || !bound ? null : notifier.sync,
            icon: syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                _SyncHeader(
                  deviceName: widget.deviceName,
                  state: state,
                  bound: bound,
                  onSync: notifier.sync,
                ),
                if (state.snapshot == null)
                  _EmptyState(
                    syncing: syncing,
                    failed: state.phase == WatchHealthSyncPhase.failure,
                    bound: bound,
                    onSync: notifier.sync,
                  )
                else ...[
                  const SizedBox(height: 22),
                  _SectionHeading(
                    title: AppStrings.of(context).watch.todayOverview,
                    trailing: _date(context, state.snapshot!.syncedAt),
                  ),
                  const SizedBox(height: 10),
                  _MetricsGrid(snapshot: state.snapshot!),
                  const SizedBox(height: 22),
                  _TrendSection(
                    state: state,
                    onPeriodChanged: notifier.selectPeriod,
                  ),
                  const SizedBox(height: 22),
                  _SleepSection(snapshot: state.snapshot!),
                  const SizedBox(height: 22),
                  _HeartRateSection(snapshot: state.snapshot!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _date(BuildContext context, DateTime value) =>
      AppStrings.of(context).watch.dateShort(value.month, value.day);
}

class _SyncHeader extends StatelessWidget {
  const _SyncHeader({
    required this.deviceName,
    required this.state,
    required this.bound,
    required this.onSync,
  });

  final String deviceName;
  final WatchHealthState state;
  final bool bound;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final watch = AppStrings.of(context).watch;
    final syncing = state.phase == WatchHealthSyncPhase.syncing;
    final failed = state.phase == WatchHealthSyncPhase.failure;
    final status = syncing
        ? watch.syncingData
        : !bound
            ? watch.deviceNotBound
            : failed
                ? watch.syncFailedRetry
                : state.snapshot == null
                    ? watch.neverSynced
                    : watch.lastSync(_time(state.snapshot!.syncedAt));
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.outline)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.watchAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.watch_outlined, color: AppTheme.watchAccent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deviceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Text(
                status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: failed ? AppTheme.error : null,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: syncing || !bound ? null : onSync,
          icon: syncing
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync, size: 18),
          label: Text(failed
              ? watch.retry
              : syncing
                  ? watch.syncing
                  : watch.sync),
        ),
      ]),
    );
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.syncing,
    required this.failed,
    required this.bound,
    required this.onSync,
  });

  final bool syncing;
  final bool failed;
  final bool bound;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final watch = AppStrings.of(context).watch;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(children: [
        Icon(
          failed ? Icons.sync_problem : Icons.monitor_heart_outlined,
          size: 54,
          color: failed ? AppTheme.error : AppTheme.watchAccent,
        ),
        const SizedBox(height: 18),
        Text(
          syncing
              ? watch.readingWatchData
              : !bound
                  ? watch.bindWatchFirst
                  : failed
                      ? watch.syncIncomplete
                      : watch.syncToView,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          syncing
              ? watch.waitingRecords
              : !bound
                  ? watch.bindToSync
                  : failed
                      ? watch.keepConnected
                      : watch.providedByWatch,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!syncing && bound) ...[
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onSync,
            icon: const Icon(Icons.sync),
            label: Text(failed ? watch.resync : watch.syncNow),
          ),
        ],
      ]),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.snapshot});

  final WatchHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final watch = AppStrings.of(context).watch;
    final heartRate = snapshot.latestHeartRate;
    final sleep = snapshot.sleepMinutes;
    final metrics = [
      _Metric(Icons.directions_walk, watch.steps, _number(snapshot.steps),
          watch.unitSteps),
      _Metric(Icons.route_outlined, watch.distance,
          (snapshot.distanceMeters / 1000).toStringAsFixed(2), watch.unitKm),
      _Metric(Icons.local_fire_department_outlined, watch.calories,
          snapshot.caloriesKcal.toStringAsFixed(1), watch.unitKcal),
      _Metric(
          Icons.favorite,
          watch.lastHeartRate,
          heartRate?.toString() ?? '--',
          heartRate == null ? watch.noData : watch.unitBpm),
      _Metric(
          Icons.bedtime_outlined,
          watch.sleep,
          sleep == 0
              ? '--'
              : '${sleep ~/ 60}:${(sleep % 60).toString().padLeft(2, '0')}',
          sleep == 0 ? watch.noData : watch.unitHours),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: metrics
            .map((metric) => SizedBox(
                  width: width,
                  height: 104,
                  child: _MetricTile(metric: metric),
                ))
            .toList(),
      );
    });
  }

  static String _number(int value) {
    final text = value.toString();
    return text.length > 3
        ? '${text.substring(0, text.length - 3)},${text.substring(text.length - 3)}'
        : text;
  }
}

class _Metric {
  const _Metric(this.icon, this.label, this.value, this.unit);
  final IconData icon;
  final String label;
  final String value;
  final String unit;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(metric.icon, size: 18, color: AppTheme.watchAccent),
              const SizedBox(width: 7),
              Text(metric.label, style: Theme.of(context).textTheme.bodySmall),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(
                child: Text(
                  metric.value,
                  maxLines: 1,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(metric.unit,
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ]),
          ]),
        ),
      );
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.state, required this.onPeriodChanged});

  final WatchHealthState state;
  final ValueChanged<WatchHealthPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final trend = state.trend!;
    final hasHeartRate = trend.points.any((point) => point.heartRate != null);
    return Column(children: [
      _SectionHeading(
          title: AppStrings.of(context).watch.trend, trailing: trend.summary),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(trend.label,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            SegmentedButton<WatchHealthPeriod>(
              segments: [
                ButtonSegment(
                    value: WatchHealthPeriod.day,
                    label: Text(AppStrings.of(context).watch.periodDay)),
                ButtonSegment(
                    value: WatchHealthPeriod.week,
                    label: Text(AppStrings.of(context).watch.periodWeek)),
                ButtonSegment(
                    value: WatchHealthPeriod.month,
                    label: Text(AppStrings.of(context).watch.periodMonth)),
              ],
              selected: {state.period},
              onSelectionChanged: (value) => onPeriodChanged(value.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _Legend(
                color: AppTheme.watchAccent,
                label: AppStrings.of(context).watch.steps),
            if (hasHeartRate) ...[
              const SizedBox(width: 14),
              _Legend(
                  color: AppTheme.error,
                  label: AppStrings.of(context).watch.legendHeartRate),
            ],
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 178,
            width: double.infinity,
            child: CustomPaint(painter: _TrendPainter(trend)),
          ),
        ]),
      ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.trend);
  final WatchHealthTrend trend;

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 22.0;
    const top = 8.0;
    final height = size.height - bottom - top;
    final width = size.width;
    final points = trend.points;
    if (points.isEmpty) return;
    final maxSteps =
        points.map((point) => point.steps).fold(1, (a, b) => a > b ? a : b);
    final slot = width / points.length;
    final barPaint = Paint()
      ..color = AppTheme.watchAccent.withValues(alpha: 0.55);
    final gridPaint = Paint()..color = AppTheme.outline.withValues(alpha: 0.5);
    for (var i = 0; i < 4; i++) {
      final y = top + height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }
    for (var i = 0; i < points.length; i++) {
      final barHeight = height * points[i].steps / maxSteps;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * slot + slot * 0.28,
            top + height - barHeight,
            slot * 0.44,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }
    final heartPoints = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final bpm = points[i].heartRate;
      if (bpm == null) continue;
      final normalized = ((bpm - 40) / 160).clamp(0.0, 1.0);
      heartPoints.add(Offset(
        slot * (i + 0.5),
        top + height * (1 - normalized),
      ));
    }
    if (heartPoints.isNotEmpty) {
      final line = Paint()
        ..color = AppTheme.error
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(heartPoints.first.dx, heartPoints.first.dy);
      for (final point in heartPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, line);
      final dot = Paint()..color = AppTheme.error;
      for (final point in heartPoints) {
        canvas.drawCircle(point, 3, dot);
      }
    }
    const labelStyle = TextStyle(color: AppTheme.textTertiary, fontSize: 9);
    final labelEvery = points.length > 10 ? 5 : 1;
    for (var i = 0; i < points.length; i += labelEvery) {
      final painter = TextPainter(
        text: TextSpan(text: points[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slot * labelEvery);
      painter.paint(
        canvas,
        Offset(slot * (i + 0.5) - painter.width / 2, size.height - 14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.trend != trend;
}

class _SleepSection extends StatelessWidget {
  const _SleepSection({required this.snapshot});
  final WatchHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final stages = snapshot.sleepStages;
    return Column(children: [
      _SectionHeading(
          title: AppStrings.of(context).watch.sleep,
          trailing: snapshot.sleepRange ?? AppStrings.of(context).watch.noData),
      const SizedBox(height: 10),
      _DataPanel(
        child: stages.isEmpty
            ? _NoData(message: AppStrings.of(context).watch.noSleepRecords)
            : Column(children: [
                for (final stage in stages)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Icon(
                        stage.state == WatchSleepState.deep
                            ? Icons.nights_stay_outlined
                            : Icons.bedtime_outlined,
                        size: 18,
                        color: AppTheme.watchAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(stage.name)),
                      Text(AppStrings.of(context)
                          .watch
                          .sleepStage(stage.minutes)),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}

class _HeartRateSection extends StatelessWidget {
  const _HeartRateSection({required this.snapshot});
  final WatchHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    // Version 1 has no per-sample heart rate stream; each entry here is the
    // average bpm of one 15-minute activity bucket.
    final records = [...snapshot.heartRateBuckets]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recent = records.take(5).toList();
    return Column(children: [
      _SectionHeading(
          title: AppStrings.of(context).watch.heartRate,
          trailing:
              AppStrings.of(context).watch.heartRatePeriods(records.length)),
      const SizedBox(height: 10),
      _DataPanel(
        child: recent.isEmpty
            ? _NoData(message: AppStrings.of(context).watch.noHeartRateRecords)
            : Column(children: [
                for (var i = 0; i < recent.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      const Icon(Icons.favorite,
                          size: 18, color: AppTheme.error),
                      const SizedBox(width: 9),
                      Expanded(child: Text(_recordTime(recent[i].timestamp))),
                      Text(AppStrings.of(context)
                          .watch
                          .heartRateValue(recent[i].heartRate)),
                    ]),
                  ),
                  if (i < recent.length - 1) const Divider(),
                ],
              ]),
      ),
    ]);
  }

  /// Buckets land on 15-minute boundaries, so seconds carry no information.
  static String _recordTime(DateTime value) =>
      '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
}

class _NoData extends StatelessWidget {
  const _NoData({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}
