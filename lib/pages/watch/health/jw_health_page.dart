import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../providers/jw_device_provider.dart';
import '../../../providers/ble_provider.dart';
import '../../../services/jw/health/jw_health_goals.dart';
import '../../../services/jw/health/jw_health_models.dart';
import '../../../services/jw/health/jw_health_repository.dart';
import '../../../services/jw/jw_device_repository.dart';
import '../../../services/jw/jw_models.dart';
import '../jw_history_page.dart';
import 'jw_health_charts.dart';
import 'jw_health_sport_page.dart';
import 'jw_health_summary_card.dart';

final jwHealthGoalStoreProvider =
    FutureProvider<JwHealthGoalStore>((ref) async {
  final directory = await getApplicationSupportDirectory();
  return JwHealthGoalStore(File('${directory.path}/jw_health_goals_v1.json'));
});
const _primary = Color(0xff5c5ce0);

class JwHealthPage extends ConsumerStatefulWidget {
  const JwHealthPage({super.key, required this.deviceKey, this.deviceName});
  final String deviceKey;
  final String? deviceName;
  @override
  ConsumerState<JwHealthPage> createState() => _JwHealthPageState();
}

class _JwHealthPageState extends ConsumerState<JwHealthPage> {
  DateTime _date = jwHealthDate(DateTime.now());
  JwHealthPeriod _period = JwHealthPeriod.day;
  JwHealthSnapshot? _snapshot;
  JwHealthGoals? _goals;
  String? _error, _goalError, _syncMessage;
  bool _started = false, _loading = false, _syncing = false;
  int _generation = 0, _syncOperation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load(latest: true);
    }
  }

  @override
  void didUpdateWidget(covariant JwHealthPage old) {
    super.didUpdateWidget(old);
    if (old.deviceKey != widget.deviceKey) {
      _generation++;
      _syncOperation++;
      _syncing = false;
      _snapshot = null;
      _goals = null;
      _syncMessage = null;
      _load(latest: true);
    }
  }

  JwDeviceRepository? get _matchingRepository {
    final repository = ref.read(jwDeviceProvider.notifier).repository;
    if (repository == null) return null;
    try {
      return repository.historyDeviceKey == widget.deviceKey
          ? repository
          : null;
    } catch (_) {
      return null;
    }
  }

  JwCapabilities? get _currentCapabilities {
    final current = ref.read(jwRepositoryProvider);
    final connected = ref.read(connectedDeviceProvider);
    // Riverpod may retain a previous repository while its replacement loads.
    if (current.isLoading || current.hasError || connected?.isJw != true) {
      return null;
    }
    final repository = current.valueOrNull;
    if (repository == null ||
        repository.platformDeviceKey != connected!.deviceId ||
        repository.state.info == null ||
        !repository.session.isOpen ||
        [
          JwDevicePhase.loading,
          JwDevicePhase.disconnected,
          JwDevicePhase.failed
        ].contains(repository.state.phase)) {
      return null;
    }
    try {
      return repository.historyDeviceKey == widget.deviceKey
          ? repository.state.capabilities
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load({bool latest = false}) async {
    final generation = ++_generation, key = widget.deviceKey, period = _period;
    var date = _date;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await ref.read(jwHistoryStoreProvider.future);
      if (latest) {
        final inventory = await store.inventory(key);
        final dates = inventory.daysByType.values
            .expand((days) => days)
            .toSet()
            .toList()
          ..sort();
        if (dates.isNotEmpty) date = jwHealthDate(DateTime.parse(dates.last));
      }
      final snapshot = await JwHealthRepository(store)
          .load(deviceKey: key, date: date, period: period);
      JwHealthGoals? goals;
      String? goalError;
      try {
        goals =
            await (await ref.read(jwHealthGoalStoreProvider.future)).read(key);
      } catch (_) {
        goalError = '无法读取本地目标，请重试';
      }
      if (!mounted || generation != _generation || key != widget.deviceKey) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _date = date;
        _goals = goals;
        _goalError = goalError;
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = '无法读取已保存数据：$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _sync() async {
    final repository = _matchingRepository;
    if (repository == null || !repository.state.canWrite || _syncing) return;
    final key = widget.deviceKey;
    final operation = ++_syncOperation;
    setState(() {
      _syncing = true;
      _syncMessage = null;
    });
    try {
      final result = await repository.syncHistory();
      if (!mounted || key != widget.deviceKey || operation != _syncOperation) {
        return;
      }
      setState(() => _syncMessage = result.phase.name == 'completed'
          ? '已保存本批数据；设备全部记录是否取完尚未证实'
          : '本次同步未完成；仍可查看已保存记录');
    } catch (e) {
      if (mounted && key == widget.deviceKey && operation == _syncOperation) {
        setState(() => _syncMessage = '同步未完成：$e');
      }
    } finally {
      if (mounted && key == widget.deviceKey && operation == _syncOperation) {
        setState(() => _syncing = false);
        await _load();
      }
    }
  }

  Future<void> _editGoals() async {
    final key = widget.deviceKey;
    final saved = await showDialog<JwHealthGoals>(
        context: context,
        builder: (context) => _GoalEditor(
            initial: _goals ?? const JwHealthGoals(),
            save: (goals) async {
              final store = await ref.read(jwHealthGoalStoreProvider.future);
              await store.write(key, goals);
            }));
    if (saved != null && mounted && key == widget.deviceKey) {
      setState(() {
        _goals = saved;
        _goalError = null;
      });
    }
  }

  void _changeDate(int offset) {
    setState(() => _date = _date.add(Duration(days: offset)));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(_date.year, _date.month, _date.day),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (picked != null && mounted) {
      setState(() => _date = jwHealthDate(picked));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(jwDeviceProvider);
    ref.watch(jwRepositoryProvider);
    ref.watch(connectedDeviceProvider);
    final capabilities = _currentCapabilities;
    final live = _matchingRepository;
    final canSync = live?.state.canWrite == true && !_syncing;
    final s = _snapshot?.date == _date && _snapshot?.period == _period
        ? _snapshot
        : null;
    return Theme(
        data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: _primary),
            textTheme: Theme.of(context).textTheme.apply(
                bodyColor: const Color(0xff090c23),
                displayColor: const Color(0xff090c23)),
            appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xfff9f9f9),
                foregroundColor: Color(0xff090c23),
                surfaceTintColor: Colors.transparent),
            scaffoldBackgroundColor: const Color(0xfff9f9f9)),
        child: Scaffold(
            appBar: AppBar(
                title: Text(widget.deviceName?.isNotEmpty == true
                    ? '${widget.deviceName} · 健康'
                    : '我的健康'),
                actions: [
                  IconButton(
                      key: const Key('jw-health-refresh'),
                      tooltip: '刷新已保存数据',
                      onPressed: () => _load(),
                      icon: const Icon(Icons.refresh))
                ]),
            body: RefreshIndicator(
                onRefresh: () => _load(),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Center(
                          child: Wrap(spacing: 8, children: [
                        for (final period in JwHealthPeriod.values)
                          ChoiceChip(
                              key: Key('jw-health-${period.name}'),
                              label: Text(
                                  period == JwHealthPeriod.day ? '日' : '周'),
                              selected: _period == period,
                              onSelected: (_) {
                                setState(() => _period = period);
                                _load();
                              })
                      ])),
                      Row(children: [
                        IconButton(
                            key: const Key('jw-health-prev'),
                            tooltip: '前一天',
                            onPressed: () => _changeDate(-1),
                            icon: const Icon(Icons.chevron_left)),
                        Expanded(
                            child: TextButton(
                                key: const Key('jw-health-date'),
                                onPressed: _pickDate,
                                child: Text(jwHealthDayKey(_date),
                                    textAlign: TextAlign.center))),
                        IconButton(
                            key: const Key('jw-health-next'),
                            tooltip: '后一天',
                            onPressed: () => _changeDate(1),
                            icon: const Icon(Icons.chevron_right)),
                      ]),
                      if (_period == JwHealthPeriod.week)
                        Text(
                            '${jwHealthDayKey(_date.subtract(const Duration(days: 6)))} — ${jwHealthDayKey(_date)}',
                            textAlign: TextAlign.center),
                      const Text('设备本地日期', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                                key: const Key('jw-health-sync'),
                                onPressed: canSync ? _sync : null,
                                child: Text(_syncing ? '正在同步' : '同步设备数据')),
                          ]),
                      if (!canSync && !_syncing)
                        const Text('离线浏览 · 连接同一设备并登录后可同步',
                            textAlign: TextAlign.center),
                      if (_syncMessage != null) Text(_syncMessage!),
                      if (_loading) ...[
                        const LinearProgressIndicator(),
                        const Text('正在读取已保存数据…')
                      ],
                      if (_error != null) Text(_error!),
                      if (s != null) ...[
                        const SizedBox(height: 8),
                        Text(
                            '已保存 ${s.coverage.recordCount} 条 · ${s.coverage.hasPartialData ? '部分同步' : '本地记录'}',
                            textAlign: TextAlign.center),
                        if (s.coverage.selectedRecordIssues.isNotEmpty)
                          const Text('所选日期的部分记录存在质量或时间标记'),
                        if (s.coverage.storageIssues.isNotEmpty)
                          const Text('全局存储问题：本地保存或恢复存在异常，请查看来源详情'),
                      ],
                      _sourceDetails(s),
                      if (s != null) ...[
                        _goalsCard(s),
                        const SizedBox(height: 16),
                        _HealthCard(
                            key: const Key('jw-health-activity-card'),
                            title: '步数',
                            icon: 'steps',
                            color: const Color(0xffff4f38),
                            foreground: const Color(0xff090c23),
                            summary: s.period == JwHealthPeriod.week
                                ? '日均 ${healthNumber(s.stepsDayAverage)} 步'
                                : '${healthNumber(s.totals.steps)} 步',
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(spacing: 24, runSpacing: 8, children: [
                                    Text(
                                        '距离 ${healthNumber(s.totals.distanceMeters)} m'),
                                    Text(
                                        '能量 ${healthNumber(s.totals.energyKcal)} kcal')
                                  ]),
                                  if (s.period == JwHealthPeriod.week)
                                    Text(
                                        '周期合计 ${healthNumber(s.totals.steps)} 步 · 有效 ${s.stepsValidDayCount}/7 天'),
                                  JwHealthActivityChart(snapshot: s),
                                ])),
                        const SizedBox(height: 16),
                        _HealthCard(
                            key: const Key('jw-health-sleep-card'),
                            title: '睡眠',
                            icon: 'sleep',
                            color: const Color(0xff981af1),
                            summary: s.period == JwHealthPeriod.week
                                ? '日均 ${healthDuration(s.sleepDayAverage)}'
                                : healthDuration(s.totals.sleepMinutes),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (s.period == JwHealthPeriod.week)
                                    Text(
                                        '周期合计 ${healthDuration(s.totals.sleepMinutes)} · 有效 ${s.sleepValidDayCount}/7 天'),
                                  JwHealthSleepChart(snapshot: s),
                                  JwHealthSummaryCard(
                                      summaries: s.dailySummaries),
                                ])),
                        for (final metric in JwHealthMetric.values) ...[
                          const SizedBox(height: 16),
                          _metricCard(s, metric, capabilities)
                        ],
                        const SizedBox(height: 24),
                        Text('运动记录',
                            key: const Key('jw-health-sport-section'),
                            style: Theme.of(context).textTheme.titleLarge),
                        if (s.sportRecords.isEmpty)
                          const Card(
                              child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('暂无已保存运动记录'))),
                        for (final record in s.sportRecords)
                          Card(
                              child: ListTile(
                                  key:
                                      Key('jw-health-sport-${record.recordId}'),
                                  leading: const Icon(Icons.directions_run),
                                  title: Text(jwHealthSportTitle(record)),
                                  subtitle: Text(jwHealthSportOverview(record)),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          settings: const RouteSettings(
                                              name: '/jw-health-sport'),
                                          builder: (_) => JwHealthSportPage(
                                              record: record))))),
                      ],
                    ]))));
  }

  Widget _sourceDetails(JwHealthSnapshot? s) => ExpansionTile(
          key: const Key('jw-health-source-details'),
          tilePadding: EdgeInsets.zero,
          title: const Text('来源详情与原始记录'),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设备：${widget.deviceKey}'),
            const Text('来源：设备已保存记录；不代表设备全部数据'),
            if (s?.coverage.hasPartialData == true) const Text('包含未完成同步的部分记录'),
            if (s?.coverage.selectedRecordIssues.isNotEmpty == true)
              Text('所选记录标记：${s!.coverage.selectedRecordIssues.join('、')}'),
            if (s?.coverage.storageIssues.isNotEmpty == true)
              Text('全局存储标记：${s!.coverage.storageIssues.join('、')}'),
            TextButton(
                key: const Key('jw-health-raw'),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        settings:
                            const RouteSettings(name: '/jw-history-records'),
                        builder: (_) =>
                            JwHistoryRecordsPage(deviceKey: widget.deviceKey))),
                child: const Text('原始记录')),
          ]);

  Widget _goalsCard(JwHealthSnapshot s) {
    final goals = _goals;
    final values = [
      s.totals.steps?.toDouble(),
      s.totals.energyKcal,
      s.totals.sleepMinutes
    ];
    final targets = [
      goals?.steps?.toDouble(),
      goals?.energyKcal,
      goals?.sleepMinutes?.toDouble()
    ];
    const titles = ['步数', '能量', '睡眠'], units = ['步', 'kcal', 'min'];
    const goalNames = ['steps', 'energy', 'sleep'];
    const goalColors = [
      Color(0xffff4f38),
      Color(0xfffac980),
      Color(0xff971af1)
    ];
    final ratios = [
      for (var i = 0; i < 3; i++)
        values[i] != null && targets[i] != null
            ? values[i]! / targets[i]!
            : null
    ];
    final summary =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.period == JwHealthPeriod.day ? '每日目标' : '过去七天目标记录',
          style: Theme.of(context).textTheme.titleLarge),
      for (var i = 0; i < 3; i++)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  key: Key('jw-health-goal-legend-${goalNames[i]}'),
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5, right: 8),
                  decoration: BoxDecoration(
                      color: goalColors[i], shape: BoxShape.circle)),
              Expanded(
                  child: Text(targets[i] == null
                      ? '${titles[i]} · 未设置目标'
                      : s.period == JwHealthPeriod.day
                          ? '${titles[i]} · ${ratios[i] == null ? '暂无数据' : '${healthNumber(ratios[i]! * 100, 0)}%'} · 目标 ${healthNumber(targets[i])} ${units[i]}'
                          : '${titles[i]} · ${s.days.where((d) {
                              final t = d.totals;
                              final v = i == 0
                                  ? t.steps?.toDouble()
                                  : i == 1
                                      ? t.energyKcal
                                      : t.sleepMinutes;
                              return v != null && v >= targets[i]!;
                            }).length} 天达标 · 每日 ${healthNumber(targets[i])} ${units[i]}'))
            ])),
    ]);
    return Card(
        key: const Key('jw-health-goals-card'),
        color: Colors.white,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.period == JwHealthPeriod.week) ...[
                Wrap(
                    key: const Key('jw-health-week-rings'),
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final day in s.days)
                        SizedBox(
                            width: 70,
                            child: Column(children: [
                              Text(jwHealthDayKey(day.date).substring(5)),
                              JwHealthGoalRings(dimension: 56, ratios: [
                                day.totals.steps != null && targets[0] != null
                                    ? day.totals.steps! / targets[0]!
                                    : null,
                                day.totals.energyKcal != null &&
                                        targets[1] != null
                                    ? day.totals.energyKcal! / targets[1]!
                                    : null,
                                day.totals.sleepMinutes != null &&
                                        targets[2] != null
                                    ? day.totals.sleepMinutes! / targets[2]!
                                    : null,
                              ]),
                            ]))
                    ]),
                const SizedBox(height: 16),
                summary,
              ] else
                LayoutBuilder(
                    builder: (context, c) => c.maxWidth >= 320 &&
                            MediaQuery.textScalerOf(context).scale(1) <= 1.3
                        ? Row(children: [
                            JwHealthGoalRings(dimension: 96, ratios: ratios),
                            const SizedBox(width: 20),
                            Expanded(child: summary)
                          ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Center(
                                    child: JwHealthGoalRings(
                                        dimension: 96, ratios: ratios)),
                                const SizedBox(height: 12),
                                summary
                              ])),
              if (_goalError != null) Text(_goalError!),
              const SizedBox(height: 8),
              const Text('用户设置 · HoneyBox 本地目标',
                  style: TextStyle(fontSize: 12)),
              TextButton(
                  key: const Key('jw-health-goal-editor'),
                  onPressed: _loading ? null : _editGoals,
                  child: const Text('设置本地目标')),
              const Text('仅保存在此应用，不修改手表目标', style: TextStyle(fontSize: 12)),
            ])));
  }

  Widget _metricCard(
      JwHealthSnapshot s, JwHealthMetric metric, JwCapabilities? capabilities) {
    final supported = capabilities == null
        ? null
        : switch (metric) {
            JwHealthMetric.heartRate => capabilities.heartRate,
            JwHealthMetric.bloodOxygen => capabilities.bloodOxygen,
            JwHealthMetric.skinTemperature => capabilities.temperature,
            JwHealthMetric.hrv => capabilities.hrv,
            JwHealthMetric.pressure => capabilities.pressureMonitor,
            JwHealthMetric.bloodPressure => capabilities.bloodPressure,
          };
    final series = s.metrics[metric]!;
    final info = _metricInfo[metric]!;
    final deviceSummary =
        JwHealthSummaryCard(summaries: s.dailySummaries, metric: metric);
    final secondary = series.samples.isEmpty
        ? null
        : series.samples
            .map((e) => e.secondaryValue)
            .whereType<double>()
            .toList();
    final average = series.average;
    final summary = metric == JwHealthMetric.bloodPressure &&
            secondary != null &&
            secondary.isNotEmpty
        ? '${healthNumber(average)}/${healthNumber(secondary.reduce((a, b) => a + b) / secondary.length)} ${info.unit}'
        : '${healthNumber(average)} ${info.unit}';
    return _HealthCard(
        key: Key('jw-health-metric-${metric.name}'),
        title: info.title,
        icon: info.icon,
        color: info.color,
        foreground: info.foreground,
        summary: summary,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (series.samples.isEmpty)
            Text(deviceSummary.hasValues
                ? '暂无原始采样'
                : supported == false
                    ? '当前设备不支持${info.title}；此日期无已保存有效数据'
                    : '暂无有效${info.title}数据')
          else ...[
            Text(
                '原始有效样本平均 · ${series.samples.length} 个${supported == false ? ' · 当前能力未支持，仍可查看已保存数据' : ''}'),
            JwHealthSampleChart(
                series: series,
                start: s.start,
                end: s.endExclusive,
                unit: info.unit,
                foreground: info.seriesColor),
            TextButton(
                key: Key('jw-health-samples-${metric.name}'),
                style: TextButton.styleFrom(foregroundColor: info.foreground),
                onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => SafeArea(
                        child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * .7,
                            child: Column(children: [
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('${info.title} · 原始样本')),
                              Expanded(
                                  child: ListView.builder(
                                      itemCount: series.samples.length,
                                      itemBuilder: (context, i) {
                                        final sample = series.samples[i];
                                        return ListTile(
                                            title: Text(
                                                '${healthNumber(sample.value)}${sample.secondaryValue == null ? '' : '/${healthNumber(sample.secondaryValue)}'} ${info.unit}'),
                                            subtitle: Text(
                                                '${jwHealthDayKey(sample.time)} ${healthClock(sample.time)} · 设备本地时间'));
                                      }))
                            ])))),
                child: const Text('查看样本')),
          ],
          deviceSummary,
          if (metric == JwHealthMetric.bloodPressure)
            const Text('最小和最大值为收缩压；样本同时显示舒张压'),
          if (metric == JwHealthMetric.hrv && series.samples.isNotEmpty)
            const Text('SDNN · 原始样本均值；每日摘要中位数不计入此均值'),
          if (metric == JwHealthMetric.skinTemperature)
            const Text('设备皮温，不是核心体温'),
          if (metric == JwHealthMetric.pressure) const Text('固件压力值，无医疗分级'),
        ]));
  }
}

class _MetricInfo {
  const _MetricInfo(this.title, this.icon, this.unit, this.color,
      [this.foreground = Colors.white]);
  final String title, icon, unit;
  final Color color, foreground;
  Color get seriesColor => switch (icon) {
        'hr' => const Color(0xff650c25),
        'ox' => const Color(0xff554013),
        'te' => const Color(0xff594500),
        'hrv' => const Color(0xff702323),
        'stress' => const Color(0xff004c38),
        _ => const Color(0xff593300),
      };
}

const _metricInfo = {
  JwHealthMetric.heartRate:
      _MetricInfo('心率', 'hr', 'bpm', Color(0xffff2d55), Color(0xff090c23)),
  JwHealthMetric.bloodOxygen:
      _MetricInfo('血氧', 'ox', '%', Color(0xfff1b72c), Color(0xff090c23)),
  JwHealthMetric.skinTemperature:
      _MetricInfo('皮温', 'te', '°C', Color(0xffffc009), Color(0xff090c23)),
  JwHealthMetric.hrv:
      _MetricInfo('HRV', 'hrv', 'ms', Color(0xfff95151), Color(0xff090c23)),
  JwHealthMetric.pressure:
      _MetricInfo('压力', 'stress', '固件值', Color(0xff00d99f), Color(0xff090c23)),
  JwHealthMetric.bloodPressure:
      _MetricInfo('血压', 'bp', 'mmHg', Color(0xffec8b00), Color(0xff090c23)),
};

class _HealthCard extends StatelessWidget {
  const _HealthCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.color,
      required this.summary,
      required this.child,
      this.foreground = Colors.white});
  final String title, icon, summary;
  final Color color, foreground;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: DefaultTextStyle(
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: foreground),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final titleRow =
                          Row(mainAxisSize: MainAxisSize.min, children: [
                        ClipOval(
                            child: Image.asset(
                                'assets/images/wofit_icon_friend_$icon.png',
                                width: 36,
                                height: 36,
                                excludeFromSemantics: true)),
                        const SizedBox(width: 10),
                        Flexible(
                            child: Text(title,
                                style: TextStyle(
                                    fontSize: 20, color: foreground))),
                      ]);
                      final headline = Text.rich(_headlineSpan(summary),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: foreground));
                      if (constraints.maxWidth < 300 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: titleRow),
                              const SizedBox(height: 8),
                              headline,
                            ]);
                      }
                      return Row(children: [
                        titleRow,
                        const SizedBox(width: 12),
                        Expanded(child: headline)
                      ]);
                    }),
                    Divider(
                        color: foreground == Colors.white
                            ? const Color(0xffd6aaff)
                            : const Color(0xff38251c),
                        height: 24),
                    child,
                  ]))));
}

TextSpan _headlineSpan(String value) {
  final spans = <TextSpan>[];
  var start = 0;
  for (final match
      in RegExp(r'步|bpm|%|°C|ms|mmHg|固件值|小时|分').allMatches(value)) {
    if (match.start > start) {
      spans.add(TextSpan(text: value.substring(start, match.start)));
    }
    spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)));
    start = match.end;
  }
  if (start < value.length) spans.add(TextSpan(text: value.substring(start)));
  return TextSpan(children: spans);
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({required this.initial, required this.save});
  final JwHealthGoals initial;
  final Future<void> Function(JwHealthGoals) save;
  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final _steps =
      TextEditingController(text: widget.initial.steps?.toString() ?? '');
  late final _energy =
      TextEditingController(text: widget.initial.energyKcal?.toString() ?? '');
  late final _sleep = TextEditingController(
      text: widget.initial.sleepMinutes?.toString() ?? '');
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _steps.dispose();
    _energy.dispose();
    _sleep.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      int? integer(TextEditingController c) =>
          c.text.trim().isEmpty ? null : int.parse(c.text.trim());
      final goals = JwHealthGoals(
          steps: integer(_steps),
          sleepMinutes: integer(_sleep),
          energyKcal: _energy.text.trim().isEmpty
              ? null
              : double.parse(_energy.text.trim()));
      goals.validate();
      setState(() {
        _saving = true;
        _error = null;
      });
      try {
        await widget.save(goals);
      } catch (_) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error = '保存失败，请重试';
          });
        }
        return;
      }
      if (mounted) Navigator.pop(context, goals);
    } catch (_) {
      setState(() => _error = '请输入正数，或留空清除目标');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('本地每日目标'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('用户设置 · HoneyBox 本地目标'),
            TextField(
                key: const Key('jw-health-goal-steps'),
                controller: _steps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '步数 · 步')),
            TextField(
                key: const Key('jw-health-goal-energy'),
                controller: _energy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '能量 · kcal')),
            TextField(
                key: const Key('jw-health-goal-sleep'),
                controller: _sleep,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '睡眠 · min')),
            if (_error != null) Text(_error!),
          ])),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
                key: const Key('jw-health-goal-save'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中' : '保存'))
          ]);
}
