import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/jw_device_provider.dart';
import '../../services/jw/history/jw_history_models.dart';
import '../../services/jw/jw_models.dart';
import 'health/jw_health_page.dart';

const jwHistoryTypeLabels = {
  JwHistoryType.steps: '计步',
  JwHistoryType.sleep: '睡眠',
  JwHistoryType.heartTemperature: '心率与皮温',
  JwHistoryType.bloodPressure: '血压',
  JwHistoryType.exercise: '运动',
  JwHistoryType.bloodOxygen: '血氧',
  JwHistoryType.hrv: 'HRV',
  JwHistoryType.pressure: '压力',
  JwHistoryType.metabolism: '代谢摘要',
  JwHistoryType.readiness: 'Readiness'
};
const _terminal = {
  JwHistoryPhase.completed,
  JwHistoryPhase.failed,
  JwHistoryPhase.cancelled,
  JwHistoryPhase.disconnected
};
const _phases = {
  JwHistoryPhase.idle: '等待同步',
  JwHistoryPhase.starting: '开始同步',
  JwHistoryPhase.receivingTraditional: '接收历史数据',
  JwHistoryPhase.receivingModern: '接收健康摘要',
  JwHistoryPhase.committing: '保存本轮',
  JwHistoryPhase.confirming: '确认传输',
  JwHistoryPhase.completed: '本轮完成',
  JwHistoryPhase.failed: '同步失败',
  JwHistoryPhase.cancelled: '同步已取消',
  JwHistoryPhase.disconnected: '连接中断'
};

class JwHistoryOverview extends StatelessWidget {
  const JwHistoryOverview(
      {super.key,
      required this.state,
      required this.onSync,
      required this.onCancel,
      required this.onBrowse});
  final JwDeviceState state;
  final VoidCallback onSync, onCancel, onBrowse;
  @override
  Widget build(BuildContext context) {
    final p = state.historyProgress;
    final active = p != null &&
        !_terminal.contains(p.phase) &&
        p.phase != JwHistoryPhase.idle;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('历史记录', style: Theme.of(context).textTheme.titleLarge),
      Wrap(spacing: 8, children: [
        FilledButton(
            key: const Key('jw-history-sync'),
            onPressed: state.canWrite ? onSync : null,
            child: const Text('同步历史')),
        if (active)
          OutlinedButton(onPressed: onCancel, child: const Text('取消同步')),
        TextButton(onPressed: onBrowse, child: const Text('查看已保存记录'))
      ]),
      if (p != null) ...[
        Text(_phases[p.phase]!),
        for (final e in p.counts.entries)
          Text(
              '${jwHistoryTypeLabels[e.key]}：接收 ${e.value.received} · 新增保存 ${e.value.newlyPersisted}'),
        if (p.phase == JwHistoryPhase.completed)
          const Text('已保存本轮；设备全部数据是否取尽尚未证实'),
        if (p.error != null) Text('未完成本轮：${p.error}'),
        if (_terminal.contains(p.phase) && p.phase != JwHistoryPhase.completed)
          const Text('已保存的部分记录可离线查看；重新连接不保证补齐缺失记录。')
      ],
    ]);
  }
}

class JwHistoryRecordTile extends StatelessWidget {
  const JwHistoryRecordTile(
      {super.key, required this.record, required this.partial});
  final JwHistoryRecord record;
  final bool partial;
  String _value(String k, String unit) {
    final v = record.values[k];
    return v == null ? '无有效数据' : '$v${unit.isEmpty ? '' : ' $unit'}';
  }

  String get _summary {
    switch (record.type) {
      case JwHistoryType.steps:
        return '步数：${_value('steps', '步')} · 距离：${_value('distanceMeters', 'm')} · 能量：${_value('energyCalories', 'cal')}';
      case JwHistoryType.sleep:
        return '睡眠阶段：${const [
          '未佩戴',
          '浅睡',
          '深睡',
          '清醒',
          'REM'
        ][record.values['mode'] as int]}';
      case JwHistoryType.heartTemperature:
        return '心率：${_value('heartRateBpm', 'BPM')} · 皮温：${_value('skinTemperatureCelsius', '°C')}';
      case JwHistoryType.bloodPressure:
        return '血压：${_value('systolicMmHg', '')}/${_value('diastolicMmHg', 'mmHg')} · 心率：${_value('heartRateBpm', 'BPM')}';
      case JwHistoryType.exercise:
        return '模式：${record.values['mode']} · 时长：${_value('durationMinutes', 'min')} ${_value('durationSeconds', 's')} · 步数：${_value('steps', '步')} · 距离：${_value('distanceMeters', 'm')} · 能量：${_value('energyCalories', 'cal')}';
      case JwHistoryType.bloodOxygen:
        return '血氧：${_value('percent', '%')}';
      case JwHistoryType.hrv:
        return 'SDNN：${_value('sdnnMilliseconds', 'ms')}';
      case JwHistoryType.pressure:
        return '压力：${_value('value', '')}';
      case JwHistoryType.metabolism:
        return '步数：${_value('steps', '步')} · 能量：${_value('energyKilocalories', 'kcal')} · 睡眠：${_value('sleepMinutes', 'min')} · 皮温：${_value('skinTemperatureMeanCelsius', '°C')} · SDNN：${_value('sdnnMedianMs', 'ms')}';
      case JwHistoryType.readiness:
        return record.values['availability'] == 5
            ? '基线学习中 · 基线 ${record.values['baselineNights']} 晚'
            : record.values['score'] == null
                ? 'Readiness：无有效数据（状态 ${record.values['availability']}）'
                : 'Readiness：${_value('score', '分')} · SDNN：${_value('sdnnMedianMs', 'ms')}';
    }
  }

  String get _source {
    final s = record.sourceTime;
    final local = s['localEpochSeconds'] ?? s['dayEpochSeconds'];
    if (local is int) {
      return DateTime.utc(2000)
          .add(Duration(seconds: local))
          .toIso8601String()
          .replaceAll('T', ' ')
          .replaceAll('Z', '');
    }
    final minute = s['minute'];
    if (minute is int) {
      return '${record.day} ${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}:${(s['second'] ?? 0).toString().padLeft(2, '0')}';
    }
    return record.day;
  }

  @override
  Widget build(BuildContext context) => ListTile(
      isThreeLine: partial,
      title: Text(_summary),
      subtitle: Text('$_source · 设备本地时间${partial ? '\n未完成同步：仅保存部分记录' : ''}'));
}

class JwHistoryRecordsPage extends ConsumerStatefulWidget {
  const JwHistoryRecordsPage(
      {super.key,
      required this.deviceKey,
      this.initialType = JwHistoryType.steps});
  final String deviceKey;
  final JwHistoryType initialType;
  @override
  ConsumerState<JwHistoryRecordsPage> createState() =>
      _JwHistoryRecordsPageState();
}

class _JwHistoryRecordsPageState extends ConsumerState<JwHistoryRecordsPage> {
  late JwHistoryType _type = widget.initialType;
  String? _day;
  int _offset = 0;
  int _generation = 0;

  JwHistoryPage? _page;
  JwHistoryInventory? _inventory;
  String? _error;
  bool _loading = true;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load({bool refreshInventory = true}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    final type = _type;
    try {
      final store = await ref.read(jwHistoryStoreProvider.future);
      final inventory = refreshInventory || _inventory == null
          ? await store.inventory(widget.deviceKey)
          : _inventory!;
      final days = inventory.daysByType[type.name] ?? [];
      final day = _day ??
          (days.isEmpty
              ? DateTime.now().toIso8601String().substring(0, 10)
              : days.last);
      final page =
          await store.query(widget.deviceKey, type, day: day, offset: _offset);
      if (!mounted || generation != _generation) return;
      setState(() {
        _inventory = inventory;
        _day = day;
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final daily =
        _type == JwHistoryType.readiness || _type == JwHistoryType.metabolism;
    final rows = page == null
        ? <JwHistoryRecord>[]
        : (daily ? page.latestBySourceIdentity : page.records);
    final days = _inventory?.daysByType[_type.name] ?? [];
    return Scaffold(
        appBar: AppBar(title: const Text('已保存历史')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 16, children: [
                DropdownButton<JwHistoryType>(
                    value: _type,
                    items: [
                      for (final t in JwHistoryType.values)
                        DropdownMenuItem(
                            value: t, child: Text(jwHistoryTypeLabels[t]!))
                    ],
                    onChanged: (t) {
                      if (t == null) return;
                      setState(() {
                        _type = t;
                        _day = null;
                        _offset = 0;
                        _page = null;
                      });
                      _load();
                    }),
                DropdownButton<String>(
                    value: days.contains(_day) ? _day : null,
                    hint: const Text('无保存日期'),
                    items: [
                      for (final day in days.reversed)
                        DropdownMenuItem(value: day, child: Text(day))
                    ],
                    onChanged: (d) {
                      if (d == null) return;
                      setState(() {
                        _day = d;
                        _offset = 0;
                      });
                      _load(refreshInventory: false);
                    }),
                IconButton(
                    tooltip: '刷新',
                    onPressed: _loading ? null : () => _load(),
                    icon: const Icon(Icons.refresh))
              ])),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Text('无法读取历史：$_error'),
                  TextButton(
                      onPressed: () {
                        ref.invalidate(jwHistoryStoreProvider);
                        _load();
                      },
                      child: const Text('重试'))
                ])),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('时间按设备本地时间显示；离线数据不保证包含设备全部记录。')),
          Expanded(
              child: rows.isEmpty
                  ? Center(child: Text(_loading ? '读取中' : '该日没有已保存记录'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (ctx, i) => JwHistoryRecordTile(
                          record: rows[i],
                          partial: page!.partialRecordIds
                              .contains(rows[i].recordId)))),
          if (page != null && !daily)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                  onPressed: _loading || _offset == 0
                      ? null
                      : () {
                          setState(() =>
                              _offset = (_offset - 100).clamp(0, 1 << 30));
                          _load(refreshInventory: false);
                        },
                  child: const Text('上一页')),
              Text('${_offset + 1}–${_offset + rows.length} / ${page.total}'),
              TextButton(
                  onPressed: _loading || _offset + 100 >= page.total
                      ? null
                      : () {
                          setState(() => _offset += 100);
                          _load(refreshInventory: false);
                        },
                  child: const Text('下一页'))
            ]),
        ]));
  }
}

/// Uses persisted data attribution keys, independent of any BLE connection.
class JwSavedHistoryDevicesPage extends ConsumerStatefulWidget {
  const JwSavedHistoryDevicesPage({super.key});
  @override
  ConsumerState<JwSavedHistoryDevicesPage> createState() =>
      _JwSavedHistoryDevicesPageState();
}

class _JwSavedHistoryDevicesPageState
    extends ConsumerState<JwSavedHistoryDevicesPage> {
  List<String>? _keys;
  String? _error;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _keys = null;
      _error = null;
    });
    try {
      final store = await ref.read(jwHistoryStoreProvider.future);
      final keys = await store.deviceKeys();
      if (mounted) setState(() => _keys = keys);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('已保存历史')),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('无法读取历史：$_error'),
              TextButton(
                  onPressed: () {
                    ref.invalidate(jwHistoryStoreProvider);
                    _load();
                  },
                  child: const Text('重试'))
            ]))
          : _keys == null
              ? const Center(child: CircularProgressIndicator())
              : _keys!.isEmpty
                  ? const Center(child: Text('暂无已保存的 JW 设备'))
                  : ListView(children: [
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('选择设备查看本地记录；无需连接手表。')),
                      for (final key in _keys!)
                        ListTile(
                            leading: const Icon(Icons.watch),
                            title: Text(
                                key.startsWith('jw:') ? key.substring(3) : key),
                            key: Key('jw-saved-health-$key'),
                            subtitle: const Text('健康概览 · 离线可查看'),
                            trailing: IconButton(
                                key: Key('jw-saved-raw-$key'),
                                tooltip: '查看原始记录',
                                icon: const Icon(Icons.list_alt),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        settings: const RouteSettings(
                                            name: '/jw-history-records'),
                                        builder: (_) => JwHistoryRecordsPage(
                                            deviceKey: key)))),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    settings:
                                        const RouteSettings(name: '/jw-health'),
                                    builder: (_) =>
                                        JwHealthPage(deviceKey: key))))
                    ]));
}
