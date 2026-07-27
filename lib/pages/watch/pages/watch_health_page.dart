import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../health/watch_health_data.dart';
import '../health/watch_health_provider.dart';

class WatchHealthPage extends ConsumerWidget {
  const WatchHealthPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  final String deviceName;
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(watchHealthProvider(deviceId));
    final notifier = ref.read(watchHealthProvider(deviceId).notifier);
    final syncing = state.phase == WatchHealthSyncPhase.syncing;

    ref.listen(watchHealthProvider(deviceId), (previous, next) {
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
        title: const Text('运动 / 健康'),
        actions: [
          IconButton(
            key: const Key('watch-health-sync'),
            tooltip: '同步健康数据',
            onPressed: syncing ? null : notifier.sync,
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
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  sliver: SliverList.list(
                    children: [
                      _SyncHeader(
                        deviceName: deviceName,
                        state: state,
                        onSync: notifier.sync,
                      ),
                      if (state.snapshot == null)
                        _EmptyHealthState(
                          syncing: syncing,
                          failed: state.phase == WatchHealthSyncPhase.failure,
                          onSync: notifier.sync,
                        )
                      else ...[
                        const SizedBox(height: 22),
                        _SectionHeading(
                          title: '今日概览',
                          trailing: _formatDate(state.snapshot!.syncedAt),
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
                        _RecordsSection(records: state.snapshot!.records),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) => '${date.month}月${date.day}日';
}

class _SyncHeader extends StatelessWidget {
  const _SyncHeader({
    required this.deviceName,
    required this.state,
    required this.onSync,
  });

  final String deviceName;
  final WatchHealthState state;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final syncing = state.phase == WatchHealthSyncPhase.syncing;
    final failed = state.phase == WatchHealthSyncPhase.failure;
    final status = syncing
        ? '正在同步健康数据...'
        : failed
            ? '同步失败 · 可重新尝试'
            : snapshot == null
                ? '尚未同步健康数据'
                : '最近同步：刚刚';

    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.watchAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.watch_outlined, color: AppTheme.watchAccent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot == null
                      ? deviceName
                      : '$deviceName · ${snapshot.batteryPercent}%',
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
            onPressed: syncing ? null : onSync,
            icon: syncing
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(failed
                ? '重试'
                : syncing
                    ? '同步中'
                    : '同步'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHealthState extends StatelessWidget {
  const _EmptyHealthState({
    required this.syncing,
    required this.failed,
    required this.onSync,
  });

  final bool syncing;
  final bool failed;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        children: [
          Icon(
            failed ? Icons.sync_problem : Icons.monitor_heart_outlined,
            size: 54,
            color: failed ? AppTheme.error : AppTheme.watchAccent,
          ),
          const SizedBox(height: 18),
          Text(
            syncing
                ? '正在读取手表数据'
                : failed
                    ? '同步未完成'
                    : '同步手表后即可查看',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            syncing
                ? '正在准备步数、心率、睡眠和活动数据'
                : failed
                    ? '请确认手表保持连接，然后重新同步'
                    : '这里将展示步数、心率、睡眠和活动趋势',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!syncing) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onSync,
              icon: const Icon(Icons.sync),
              label: Text(failed ? '重新同步' : '立即同步'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.snapshot});

  final WatchHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final sleepHours = snapshot.sleepMinutes ~/ 60;
    final sleepMinutes = snapshot.sleepMinutes % 60;
    final progress = (snapshot.steps / snapshot.stepGoal * 100).round();
    final metrics = [
      _MetricData(Icons.directions_walk, '步数', _number(snapshot.steps), '步',
          '目标 ${_number(snapshot.stepGoal)} · 已完成 $progress%'),
      _MetricData(Icons.favorite, '心率', '${snapshot.heartRate}', '次/分',
          '今日范围 ${snapshot.minimumHeartRate}-${snapshot.maximumHeartRate}'),
      _MetricData(Icons.bedtime_outlined, '睡眠', '$sleepHours:$sleepMinutes',
          '小时', '昨晚 ${snapshot.sleepRange}'),
      _MetricData(Icons.timer_outlined, '活动时长', '${snapshot.activeMinutes}',
          '分钟', '中高强度 ${snapshot.vigorousMinutes} 分钟'),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: metrics
            .map((metric) => SizedBox(
                  width: width,
                  height: 116,
                  child: _MetricTile(data: metric),
                ))
            .toList(),
      );
    });
  }

  static String _number(int value) {
    final digits = value.toString();
    return digits.length > 3
        ? '${digits.substring(0, digits.length - 3)},${digits.substring(digits.length - 3)}'
        : digits;
  }
}

class _MetricData {
  const _MetricData(this.icon, this.label, this.value, this.unit, this.detail);
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String detail;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(data.icon, size: 18, color: AppTheme.watchAccent),
              const SizedBox(width: 7),
              Text(data.label, style: Theme.of(context).textTheme.bodySmall),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(
                child: Text(data.value,
                    maxLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(data.unit,
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ]),
            const SizedBox(height: 7),
            Text(data.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.state, required this.onPeriodChanged});
  final WatchHealthState state;
  final ValueChanged<WatchHealthPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final trend = state.trend!;
    return Column(
      children: [
        _SectionHeading(title: '趋势分析', trailing: trend.summary),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: Text(trend.label,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                SegmentedButton<WatchHealthPeriod>(
                  segments: const [
                    ButtonSegment(
                        value: WatchHealthPeriod.day, label: Text('日')),
                    ButtonSegment(
                        value: WatchHealthPeriod.week, label: Text('周')),
                    ButtonSegment(
                        value: WatchHealthPeriod.month, label: Text('月')),
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
                const _Legend(color: AppTheme.watchAccent, label: '步数'),
                const SizedBox(width: 14),
                const _Legend(color: AppTheme.error, label: '心率趋势'),
                const Spacer(),
                Text('平均 ${trend.averageHeartRate} 次/分',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.error)),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 178,
                width: double.infinity,
                child: CustomPaint(painter: _TrendPainter(trend)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.trend);
  final WatchHealthTrend trend;

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 24.0;
    const top = 10.0;
    const right = 24.0;
    final chartHeight = size.height - bottom - top;
    final chartWidth = size.width - right;
    final grid = Paint()..color = AppTheme.outline.withValues(alpha: 0.55);
    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), grid);
    }
    final count = trend.steps.length;
    final slot = chartWidth / count;
    final bars = Paint()..color = AppTheme.watchAccent.withValues(alpha: 0.5);
    for (var i = 0; i < count; i++) {
      final height = chartHeight * trend.steps[i] / 100;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * slot + slot * 0.31, top + chartHeight - height,
              slot * 0.38, height),
          const Radius.circular(3),
        ),
        bars,
      );
    }
    final line = Paint()
      ..color = AppTheme.error
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final point = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;
    final pointBorder = Paint()
      ..color = AppTheme.error
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < trend.heartRates.length; i++) {
      final x = slot * (i + 0.5);
      final normalized = ((trend.heartRates[i] - 50) / 80).clamp(0.0, 1.0);
      final y = top + chartHeight * (1 - normalized);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      points.add(Offset(x, y));
    }
    canvas.drawPath(path, line);
    for (final offset in points) {
      canvas.drawCircle(offset, 3.2, point);
      canvas.drawCircle(offset, 3.2, pointBorder);
    }
    const labelStyle = TextStyle(color: AppTheme.textTertiary, fontSize: 9);
    for (var i = 0; i < trend.labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: trend.labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slot);
      painter.paint(canvas,
          Offset(slot * (i + 0.5) - painter.width / 2, size.height - 15));
    }
    for (final entry in const [(120, 0.0), (90, 0.5), (60, 1.0)]) {
      final painter = TextPainter(
        text: TextSpan(
            text: '${entry.$1}',
            style: labelStyle.copyWith(color: AppTheme.error)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
          canvas, Offset(chartWidth + 3, top + chartHeight * entry.$2 - 5));
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
    final hours = snapshot.sleepMinutes ~/ 60;
    final minutes = snapshot.sleepMinutes % 60;
    const colors = [
      Color(0xFF236A61),
      Color(0xFF5DA79A),
      Color(0xFF94C8BF),
      Color(0xFFD6A24C)
    ];
    return Column(children: [
      const _SectionHeading(title: '睡眠详情', trailing: '昨晚'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Row(children: [
            Text('$hours小时$minutes分钟',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(snapshot.sleepRange,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 11,
              child: Row(children: [
                for (var i = 0; i < snapshot.sleepStages.length; i++)
                  Expanded(
                      flex: snapshot.sleepStages[i].minutes,
                      child: ColoredBox(color: colors[i])),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 8, children: [
              for (var i = 0; i < snapshot.sleepStages.length; i++)
                SizedBox(
                    width: width,
                    child: _SleepLegend(
                        stage: snapshot.sleepStages[i], color: colors[i])),
            ]);
          }),
        ]),
      ),
    ]);
  }
}

class _SleepLegend extends StatelessWidget {
  const _SleepLegend({required this.stage, required this.color});
  final WatchSleepStage stage;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 7, height: 7, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(stage.name,
                style: Theme.of(context).textTheme.labelSmall)),
        Text('${stage.minutes ~/ 60}时${stage.minutes % 60}分',
            style: Theme.of(context).textTheme.labelMedium),
      ]);
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.records});
  final List<WatchHealthRecord> records;
  @override
  Widget build(BuildContext context) => Column(children: [
        const _SectionHeading(title: '最近记录', trailing: '今天'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              border:
                  Border.all(color: AppTheme.outline.withValues(alpha: 0.75)),
              borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            for (var i = 0; i < records.length; i++) ...[
              _RecordRow(record: records[i]),
              if (i < records.length - 1) const Divider(),
            ],
          ]),
        ),
      ]);
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});
  final WatchHealthRecord record;
  @override
  Widget build(BuildContext context) {
    final icon = switch (record.type) {
      WatchHealthRecordType.heartRate => Icons.favorite,
      WatchHealthRecordType.activity => Icons.directions_walk,
      WatchHealthRecordType.milestone => Icons.flag_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: AppTheme.watchAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 17, color: AppTheme.watchAccent)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record.title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(record.subtitle, style: Theme.of(context).textTheme.labelSmall)
        ])),
        Text(record.value, style: Theme.of(context).textTheme.labelMedium),
      ]),
    );
  }
}
