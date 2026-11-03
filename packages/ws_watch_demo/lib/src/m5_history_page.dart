import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'debug/debug_scope.dart';

/// M5 acceptance with the default persistent store, or an existing M3 watch.
class M5HistoryPage extends StatefulWidget {
  const M5HistoryPage(
      {super.key,
      this.watch,
      this.config = const WSConfig(simulationEnabled: true)});
  final WSWatch? watch;
  final WSConfig config;
  @override
  State<M5HistoryPage> createState() => _M5HistoryPageState();
}

class _M5HistoryPageState extends State<M5HistoryPage> {
  late final WSWatch _watch = widget.watch ?? WSWatch(config: widget.config);
  final _device = TextEditingController(text: kWsWatchSimDeviceId);
  final _user = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _limit = TextEditingController(text: '100');
  StreamSubscription<WSConnectionChange>? _state;
  StreamSubscription<WSSyncProgress>? _progressSub;
  WSSyncSession? _sync;
  WSSyncProgress? _progress;
  WSSyncResult? _result;
  WSHistoryType _type = WSHistoryType.steps;
  List<WSHistoryRecord> _records = [];
  List<WSSyncLog> _logs = [];
  bool _busy = false, _descending = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _state = _watch.stateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _state?.cancel();
    _progressSub?.cancel();
    _sync?.cancel();
    if (widget.watch == null) _watch.dispose();
    for (final c in [_device, _user, _from, _to, _limit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await DemoDebugScope.runAction(_watch, '历史数据操作', action);
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  WSWallClock? _time(String text) {
    if (text.trim().isEmpty) return null;
    return WSWallClock.fromCalendar(DateTime.parse(text.trim()));
  }

  WSRecordQuery _query() => WSRecordQuery(
      deviceId: _device.text.trim(),
      userId: _user.text.trim().isEmpty ? null : _user.text.trim(),
      from: _time(_from.text),
      to: _time(_to.text),
      limit: _limit.text.trim().isEmpty ? null : int.parse(_limit.text.trim()),
      descending: _descending);
  Future<void> _load() async {
    final query = _query();
    final rows = <WSHistoryRecord>[
      ...(_type == WSHistoryType.steps
          ? await _watch.data.steps.query(query)
          : await _watch.data.heartRate.query(query))
    ];
    final logs = await _watch.data
        .syncLogs(deviceId: query.deviceId, userId: query.userId);
    if (mounted) {
      setState(() {
        _records = rows;
        _logs = logs;
      });
    }
  }

  Future<void> _start() async {
    _result = null;
    _progress = null;
    final sync = _watch.data.sync(type: _type);
    _sync = sync;
    final previousProgress = _progressSub;
    _progressSub = sync.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    await previousProgress?.cancel();
    try {
      final result = await sync.result;
      if (mounted) setState(() => _result = result);
      await _load();
    } finally {
      _sync = null;
    }
  }

  Widget _field(String label, TextEditingController controller) => TextField(
      controller: controller,
      enabled: !_busy,
      decoration: InputDecoration(labelText: label));
  @override
  Widget build(BuildContext context) {
    final ready = _watch.state == WSConnectionState.ready;
    final p = _progress;
    return DemoDebugScaffold(
        watch: _watch,
        appBar: AppBar(title: const Text('M5 历史数据')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('当前状态：${_watch.state.name}', key: const Key('m5-state')),
          const Text(
              '单类型同步：活动桶 / 心率。模拟数据日期为 2026-10-12；数据持久化到 SQLite，断开或重启后仍可查询。真实 BLE 在 M7。'),
          Wrap(spacing: 8, children: [
            FilledButton(
                onPressed: !_busy &&
                        _watch.state == WSConnectionState.disconnected &&
                        _watch.config.simulationEnabled
                    ? () => _run(() => _watch.connect(kWsWatchSimDeviceId))
                    : null,
                child: const Text('连接 Simulator')),
            OutlinedButton(
                onPressed: _watch.state != WSConnectionState.disconnected
                    ? () => _run(_watch.disconnect)
                    : null,
                child: const Text('断开连接')),
          ]),
          DropdownButton<WSHistoryType>(
              value: _type,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: WSHistoryType.steps, child: Text('活动桶（15 分钟）')),
                DropdownMenuItem(
                    value: WSHistoryType.heartRate, child: Text('心率'))
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() {
                          _type = v;
                          _records = [];
                        });
                      }
                    }),
          Wrap(spacing: 8, children: [
            FilledButton(
                onPressed: ready && !_busy ? () => _run(_start) : null,
                child: const Text('开始单类型同步')),
            OutlinedButton(
                onPressed: _sync != null ? () => _sync!.cancel() : null,
                child: const Text('取消同步')),
          ]),
          if (_busy) const LinearProgressIndicator(),
          if (p != null)
            Text(
                '阶段：${p.stage.name}\n预告 ${p.announced ?? '-'} / 收到 ${p.received} / 已入库 ${p.committed}\n新增 ${p.inserted} / 重复 ${p.duplicates} / 解码失败 ${p.decodeFailures}\n待处理 ${p.pendingBytes} B',
                key: const Key('m5-progress')),
          if (_result != null)
            SelectableText(
                '结果：${_result!.status.name} · 确认 ${_result!.confirmation.name}\n${_result!.reason?.name ?? ''} ${_result!.message ?? ''}',
                key: const Key('m5-result')),
          if (_message != null)
            SelectableText(_message!, key: const Key('m5-message')),
          const DemoActionCard(),
          const Divider(),
          const Text('本地查询 / 删除（与连接状态无关）'),
          _field('设备 ID（必填）', _device),
          _field('用户 ID（留空查询该设备所有用户）', _user),
          _field('起始时间（包含，可留空，如 2026-10-12 08:30:00）', _from),
          _field('结束时间（不包含，可留空）', _to),
          _field('条数上限（留空不限，0 不匹配记录）', _limit),
          SwitchListTile(
              title: const Text('时间倒序'),
              value: _descending,
              onChanged: _busy ? null : (v) => setState(() => _descending = v)),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: !_busy ? () => _run(_load) : null,
                child: const Text('查询记录与日志')),
            OutlinedButton(
                onPressed: !_busy
                    ? () => _run(() async {
                          final query = _query();
                          final count = _type == WSHistoryType.steps
                              ? await _watch.data.steps.delete(query)
                              : await _watch.data.heartRate.delete(query);
                          await _load();
                          if (mounted) {
                            setState(() => _message = '已删除 $count 条记录（当前过滤条件）');
                          }
                        })
                    : null,
                child: const Text('删除当前条件记录')),
          ]),
          Text('本地记录：${_records.length} 条', key: const Key('m5-count')),
          for (final r in _records)
            ListTile(
                dense: true,
                title: Text('${r.recordTime}'),
                subtitle: Text(
                    '${r is WSStepRecord ? '步数 ${r.steps ?? "无效"} · 距离 ${r.distanceMeters ?? "无效"} m · 热量 ${r.caloriesDeciKcal == null ? "无效" : r.caloriesDeciKcal! / 10} kcal · 心率 ${r.averageHeartRate ?? "无效"} · mode ${r.mode} flags ${r.flags}' : '心率 ${(r as WSHeartRateRecord).bpm ?? "无效"} bpm'}\n用户 ${r.userId} · 原文 ${r.raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}')),
          const Divider(),
          Text('最近同步日志：${_logs.length} 条'),
          for (final log in _logs)
            ListTile(
                dense: true,
                title: Text('${log.result.name} · ${log.confirmation.name}'),
                subtitle: Text(
                    '${log.startedAt}\n${log.receivedJson}\n${log.reason ?? ""}')),
        ]));
  }
}
