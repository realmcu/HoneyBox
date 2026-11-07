import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_history_record_presenter.dart';
import 'jw_history_sync_labels.dart';
import 'jw_history_sync_run_controller.dart';
import 'jw_history_sync_state.dart';

void openJwHistoryHub(BuildContext context, JWDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWHistorySyncFlowPage(controller: controller),
      ),
    ),
  );
}

/// 二级页：展示健康数据同步全流程。
class JWHistorySyncFlowPage extends StatefulWidget {
  const JWHistorySyncFlowPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JWHistorySyncFlowPage> createState() => _JWHistorySyncFlowPageState();
}

class _JWHistorySyncFlowPageState extends State<JWHistorySyncFlowPage> {
  late final JwHistorySyncRunController _sync;
  bool _resettingMarkers = false;

  @override
  void initState() {
    super.initState();
    _sync = JwHistorySyncRunController();
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  bool get _canStart =>
      widget.controller.state.isReady && widget.controller.session != null;

  Future<void> _startSync() async {
    final session = widget.controller.session;
    if (session == null) return;
    try {
      await _sync.start(session);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(error))),
      );
    }
  }

  Future<void> _resetDeviceSyncMarkers() async {
    final session = widget.controller.session;
    if (session == null || _resettingMarkers) return;
    setState(() => _resettingMarkers = true);
    try {
      await _sync.resetDeviceSyncMarkers(session);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(error))),
      );
    } finally {
      if (mounted) setState(() => _resettingMarkers = false);
    }
  }

  void _openCategory(JWHistorySyncCategory category) {
    final records = _sync.state.roundRecords[category] ?? const [];
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JWHistoryCategoryDetailPage(
            category: category,
            records: records,
            receivedTotal: _sync.state.receivedRowsByCategory[category] ?? 0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _sync]),
      builder: (context, _) {
        final state = _sync.state;
        final sessionState = widget.controller.state;
        return Scaffold(
          key: const Key('jw.demo.history.sync.flow'),
          appBar: AppBar(title: const Text('健康数据同步')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '发起同步后可查看设备计划、传输进度、各类型解析结果与过程日志。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _SessionBanner(sessionState: sessionState),
              const SizedBox(height: 12),
              _PhaseCard(state: state),
              if (state.plan != null) ...[
                const SizedBox(height: 12),
                _SyncStartSummary(plan: state.plan!),
              ],
              if (state.phase == JwHistorySyncPhase.success ||
                  state.phase == JwHistorySyncPhase.failed) ...[
                const SizedBox(height: 12),
                _SyncEndSummary(state: state),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.isActive || !_canStart ? null : _startSync,
                icon: state.isActive
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(state.isActive ? '同步进行中…' : '开始同步'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('jw.demo.history.reset_sync_markers'),
                onPressed: state.isActive ||
                        !_canStart ||
                        _resettingMarkers
                    ? null
                    : _resetDeviceSyncMarkers,
                icon: _resettingMarkers
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt_outlined),
                label: Text(_resettingMarkers ? '请求中…' : '重置同步标记'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '若设备计划条数全为 0（游标已推过），可先重置同步标记（0x05/0xFA）再重新同步。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (!sessionState.isReady && sessionState.isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '请先完成登录后再同步。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (!state.isActive &&
                  (state.phase == JwHistorySyncPhase.success ||
                      state.phase == JwHistorySyncPhase.failed))
                TextButton(
                  onPressed: _sync.reset,
                  child: const Text('清除本轮结果'),
                ),
              const SizedBox(height: 20),
              Text('过程日志', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SyncEventLog(entries: state.eventLog),
              const SizedBox(height: 20),
              Text('分类型结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._buildCategoryTiles(state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildCategoryTiles(JwHistorySyncRunState state) {
    final plan = state.plan;
    final tiles = <Widget>[];
    final tempAttached =
        state.receivedRowsByCategory[JWHistorySyncCategory.temperature] ?? 0;
    for (final category in jwDemoHistorySyncCategories) {
      final planned =
          plan == null ? null : jwDemoPlannedWireCount(plan, category);
      final received = state.receivedRowsByCategory[category] ?? 0;
      if (state.phase == JwHistorySyncPhase.idle) {
        continue;
      }
      if (planned == null && received == 0) {
        continue;
      }
      if (planned == 0 && received == 0) {
        continue;
      }
      final sampleCount = state.roundRecords[category]?.length ?? 0;
      tiles.add(
        Card(
          child: ListTile(
            title: Text(jwHistorySyncCategoryLabel(category)),
            subtitle: Text(
              jwDemoCategoryPlanSubtitle(
                category: category,
                planned: planned,
                received: received,
                temperatureAttached: tempAttached,
              ),
            ),
            trailing: sampleCount > 0 ? Text('样本 $sampleCount') : null,
            enabled: sampleCount > 0,
            onTap: sampleCount > 0 ? () => _openCategory(category) : null,
          ),
        ),
      );
    }
    if (tiles.isEmpty && state.phase != JwHistorySyncPhase.idle) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            state.awaitingDevicePlan
                ? '等待设备返回同步计划…'
                : '本轮暂无已解析的健康记录；请查看上方日志确认是否有传输或失败原因。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    } else if (tiles.isEmpty) {
      tiles.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('开始同步后，这里会按类型显示计划条数与已解析条数。'),
        ),
      );
    }
    return tiles;
  }
}

class _SessionBanner extends StatelessWidget {
  const _SessionBanner({required this.sessionState});

  final JWSessionState sessionState;

  @override
  Widget build(BuildContext context) {
    final label = switch (sessionState.phase) {
      JWSessionPhase.ready => '会话已就绪，可发起同步',
      JWSessionPhase.connected || JWSessionPhase.loggingIn => '已连接，等待登录完成',
      JWSessionPhase.disconnected => '未连接设备',
      _ => sessionState.phase.name,
    };
    return Card(
      child: ListTile(
        leading: Icon(
          sessionState.isReady
              ? Icons.check_circle_outline
              : Icons.info_outline,
        ),
        title: const Text('会话状态'),
        subtitle: Text(label),
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.state});

  final JwHistorySyncRunState state;

  @override
  Widget build(BuildContext context) {
    final total = state.totalWire;
    final received = state.receivedWire;
    final progress = total > 0 ? received / total : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(jwHistorySyncPhaseLabel(state.phase),
                style: Theme.of(context).textTheme.titleMedium),
            if (state.awaitingDevicePlan) ...[
              const SizedBox(height: 8),
              const Text('已发起同步，等待设备返回计划…'),
            ],
            if (total > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress?.clamp(0.0, 1.0)),
              const SizedBox(height: 4),
              Text('传输进度 $received / $total'),
            ],
            if (state.startedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '开始 ${state.startedAt!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.failure != null) ...[
              const SizedBox(height: 8),
              Text(
                describeJwHistorySyncFailure(state.failure!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncStartSummary extends StatelessWidget {
  const _SyncStartSummary({required this.plan});

  final JWHistorySyncPlan plan;

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[
      Text('同步开始 · 计划合计 ${plan.totalWireRecords} 条',
          style: Theme.of(context).textTheme.titleSmall),
    ];
    for (final category in jwDemoHistorySyncCategories) {
      final count = plan.wireCountsByCategory[category];
      if (count == null || count == 0) continue;
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('${jwHistorySyncCategoryLabel(category)}：$count'),
      ));
    }
    if (plan.totalWireRecords == 0) {
      lines.add(const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('设备未声明待传条目'),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines,
        ),
      ),
    );
  }
}

class _SyncEndSummary extends StatelessWidget {
  const _SyncEndSummary({required this.state});

  final JwHistorySyncRunState state;

  @override
  Widget build(BuildContext context) {
    final parsed = jwDemoParsedRowTotal(state.receivedRowsByCategory);
    final tempParsed = jwDemoTemperatureParsedCount(state.receivedRowsByCategory);
    final duration = state.startedAt != null && state.finishedAt != null
        ? state.finishedAt!.difference(state.startedAt!)
        : null;
    final durationLabel = duration == null
        ? null
        : duration.inSeconds >= 1
            ? '${duration.inSeconds} 秒'
            : '${duration.inMilliseconds} 毫秒';
    return Card(
      color: state.phase == JwHistorySyncPhase.failed
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.phase == JwHistorySyncPhase.success ? '同步结束' : '同步未完成',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text('传输 ${state.receivedWire} / ${state.totalWire}'),
            Text('已解析健康记录 $parsed 条'),
            if (tempParsed > 0) Text('附带体温 $tempParsed 条'),
            if (durationLabel != null) Text('耗时 $durationLabel'),
            if (state.finishedAt != null)
              Text(
                '结束 ${state.finishedAt!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncEventLog extends StatelessWidget {
  const _SyncEventLog({required this.entries});

  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.45,
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: entries.isEmpty
            ? Text('暂无日志；开始同步后会按时间顺序记录计划、进度与各类型批次。',
                style: Theme.of(context).textTheme.bodyMedium)
            : SelectableText(entries.join('\n'), style: mono),
      ),
    );
  }
}

/// 三级页：展示本轮 listener 缓冲的结构化样本（非全库查询）。
class JWHistoryCategoryDetailPage extends StatelessWidget {
  const JWHistoryCategoryDetailPage({
    super.key,
    required this.category,
    required this.records,
    required this.receivedTotal,
  });

  final JWHistorySyncCategory category;
  final List<Object> records;
  final int receivedTotal;

  @override
  Widget build(BuildContext context) {
    final title = jwHistorySyncCategoryLabel(category);
    return Scaffold(
      key: const Key('jw.demo.history.category.detail'),
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '本轮共解析 $receivedTotal 条；'
            '下方最多展示 ${JwHistorySyncRunState.maxSamplesPerCategory} 条样本。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < records.length; i++) ...[
            Text('记录 ${i + 1}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SelectableText(jwHistoryRecordSummary(records[i])),
            const SizedBox(height: 8),
            _FieldTable(fields: jwHistoryRecordFields(records[i])),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _FieldTable extends StatelessWidget {
  const _FieldTable({required this.fields});

  final Map<String, Object?> fields;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
        );
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: [
        for (final entry in fields.entries)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Text(entry.key, style: mono),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText('${entry.value}', style: mono),
              ),
            ],
          ),
      ],
    );
  }
}
