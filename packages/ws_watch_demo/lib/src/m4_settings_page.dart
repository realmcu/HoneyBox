import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

/// Standalone simulator acceptance, or reuse the M3 page's connected watch.
class M4SettingsPage extends StatefulWidget {
  const M4SettingsPage(
      {super.key,
      this.watch,
      this.config = const WSConfig(simulationEnabled: true)});
  final WSWatch? watch;
  final WSConfig config;
  @override
  State<M4SettingsPage> createState() => _M4SettingsPageState();
}

class _M4SettingsPageState extends State<M4SettingsPage> {
  late final WSWatch _watch = widget.watch ?? WSWatch(config: widget.config);
  final _time = TextEditingController(
      text: WSWallClock.fromCalendar(DateTime.now()).toString());
  final _subscriptions = <StreamSubscription<dynamic>>[];
  WSLanguage _language = WSLanguage.simplifiedChinese;
  WSDisplayFormat _draft = WSDisplayFormat();
  final _frames = <WSFrameEvent>[];
  bool _busy = false;
  String? _result;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _subscriptions.add(_watch.stateChanges.listen((_) {
      if (mounted) setState(() {});
    }));
    _subscriptions.add(_watch.settings.changes.listen((_) {
      if (mounted) setState(() {});
    }));
    _subscriptions.add(_watch.debug.frames.listen((frame) {
      if (!mounted) return;
      setState(() {
        _frames.insert(0, frame);
        if (_frames.length > 40) _frames.removeLast();
      });
    }));
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    if (widget.watch == null) _watch.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _run(String success, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      await action();
      if (mounted) setState(() => _result = success);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  WSWallClock _parseTime() {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$')
        .firstMatch(_time.text);
    if (match == null) throw const FormatException('请输入 YYYY-MM-DD HH:mm:ss');
    final v = List.generate(6, (i) => int.parse(match.group(i + 1)!));
    return WSWallClock(
        year: v[0],
        month: v[1],
        day: v[2],
        hour: v[3],
        minute: v[4],
        second: v[5]);
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  Widget _choice<T>(String label, T value, List<T> known,
      String Function(T) describe, void Function(T) change, bool enabled) {
    final values = [if (!known.contains(value)) value, ...known];
    return InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: enabled),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text(describe(v))))
              .toList(),
          onChanged: enabled
              ? (v) {
                  if (v != null) setState(() => change(v));
                }
              : null,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _watch.state == WSConnectionState.ready;
    final enabled = ready && !_busy;
    final settings = _watch.settings;
    final observed = settings.observed;
    final languageEnabled =
        enabled && settings.languageSupport != WSFeatureSupport.unsupported;
    final displayEnabled = enabled &&
        settings.displayFormatSupport != WSFeatureSupport.unsupported;
    return Scaffold(
        appBar: AppBar(title: const Text('M4 设置')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('当前状态：${_watch.state.name}', key: const Key('m4-state')),
          const Text('模拟器读写验收；真实手表连接在 M7。写入成功只表示 ACK，实际值以读取或通知为准。'),
          Wrap(spacing: 8, children: [
            FilledButton(
                onPressed: !_busy &&
                        _watch.state == WSConnectionState.disconnected &&
                        _watch.config.simulationEnabled
                    ? () => _run('Simulator 已就绪',
                        () => _watch.connect(kWsWatchSimDeviceId))
                    : null,
                child: const Text('连接 Simulator')),
            OutlinedButton(
                onPressed:
                    !ready && _watch.state == WSConnectionState.disconnected
                        ? null
                        : () async {
                            try {
                              await _watch.disconnect();
                            } catch (e) {
                              if (mounted) setState(() => _error = e);
                            }
                          },
                child: const Text('断开 / 取消连接')),
          ]),
          if (_busy) const LinearProgressIndicator(),
          if (_result != null) Text(_result!, key: const Key('m4-result')),
          if (_error != null)
            SelectableText('$_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const Divider(),
          const Text('时间（设备本地年月日时分秒）'),
          TextField(
              controller: _time,
              enabled: enabled,
              decoration:
                  const InputDecoration(labelText: 'YYYY-MM-DD HH:mm:ss')),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: enabled
                    ? () => _run(
                        '时间写入已收到 ACK', () => settings.setTime(_parseTime()))
                    : null,
                child: const Text('写入指定时间')),
            OutlinedButton(
                onPressed: enabled
                    ? () => _run('手机对时已收到 ACK', settings.setTime)
                    : null,
                child: const Text('按手机时间对时')),
          ]),
          Text('最近时间通知：${observed.time ?? '暂无（时间不支持读取）'}'),
          const Divider(),
          Text('语言能力：${settings.languageSupport.name}（unknown 允许按规范尝试）'),
          _choice('待写入语言', _language, WSLanguage.knownValues,
              (v) => v.toString(), (v) => _language = v, languageEnabled),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: languageEnabled
                    ? () => _run('语言读取成功', () async {
                          final value = await settings.getLanguage();
                          if (mounted) setState(() => _language = value);
                        })
                    : null,
                child: const Text('读取语言')),
            OutlinedButton(
                onPressed: languageEnabled
                    ? () => _run(
                        '语言写入已收到 ACK', () => settings.setLanguage(_language))
                    : null,
                child: const Text('写入语言')),
          ]),
          Text('最近语言观测：${observed.language ?? '暂无'}'),
          const Divider(),
          Text('显示格式能力：${settings.displayFormatSupport.name}'),
          const Text('编辑表单不会自动跟随通知；读取可将设备完整值填入表单。'),
          _choice(
              '时制',
              _draft.hourSystem,
              WSHourSystem.knownValues,
              (v) => v.toString(),
              (v) => _draft = _draft.copyWith(hourSystem: v),
              displayEnabled),
          _choice(
              '日期格式',
              _draft.dateFormat,
              WSDateFormat.knownValues,
              (v) => v.toString(),
              (v) => _draft = _draft.copyWith(dateFormat: v),
              displayEnabled),
          _choice(
              '距离单位',
              _draft.distanceUnit,
              WSDistanceUnit.knownValues,
              (v) => v.toString(),
              (v) => _draft = _draft.copyWith(distanceUnit: v),
              displayEnabled),
          _choice(
              '体重单位',
              _draft.weightUnit,
              WSWeightUnit.knownValues,
              (v) => v.toString(),
              (v) => _draft = _draft.copyWith(weightUnit: v),
              displayEnabled),
          Text('本次完整写入 4B：${_hex(_draft.raw)}', key: const Key('m4-draft')),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: displayEnabled
                    ? () => _run('显示格式读取成功', () async {
                          final value = await settings.getDisplayFormat();
                          if (mounted) setState(() => _draft = value);
                        })
                    : null,
                child: const Text('读取显示格式')),
            OutlinedButton(
                onPressed: displayEnabled
                    ? () => _run('完整格式写入已收到 ACK',
                        () => settings.setDisplayFormat(_draft))
                    : null,
                child: const Text('写入完整格式')),
            OutlinedButton(
                onPressed: displayEnabled
                    ? () => _run('时制修改已收到 ACK（保留其余字段）',
                        () => settings.setHourSystem(_draft.hourSystem))
                    : null,
                child: const Text('仅改时制')),
            OutlinedButton(
                onPressed: displayEnabled
                    ? () => _run('距离修改已收到 ACK（保留其余字段）',
                        () => settings.setDistanceUnit(_draft.distanceUnit))
                    : null,
                child: const Text('仅改距离单位')),
            OutlinedButton(
                onPressed: displayEnabled
                    ? () => _run('并发修改完成，已重新读取', () async {
                          await Future.wait([
                            settings.setHourSystem(_draft.hourSystem),
                            settings.setDistanceUnit(_draft.distanceUnit)
                          ]);
                          final value = await settings.getDisplayFormat();
                          if (mounted) setState(() => _draft = value);
                        })
                    : null,
                child: const Text('并发修改时制与距离')),
          ]),
          Text('最近显示格式观测：${observed.displayFormat ?? '暂无'}'),
          if (observed.displayFormat != null)
            Text('观测原文：${_hex(observed.displayFormat!.raw)}'),
          const Text('便利接口每次读取完整值再修改一项；与手表端同时修改时，最终以重新读取为准。'),
          const Divider(),
          Text('最近收发帧（${_frames.length}/40）'),
          for (final frame in _frames.take(12))
            ListTile(
                dense: true,
                title: Text(
                    '${frame.direction.name} ${frame.kind.name} seq=${frame.seq ?? '-'}'),
                subtitle: Text(_hex(frame.raw))),
        ]));
  }
}
