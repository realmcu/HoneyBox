import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'debug/debug_scope.dart';

/// M2 内存模拟实验室：打开传输会话、语言读写、查看帧与上报。
///
/// 不是 M3 正式连接，不会进入 [WSConnectionState.ready]。
class M2SimulationLabPage extends StatefulWidget {
  const M2SimulationLabPage({super.key});

  static const labConfig = WSConfig(simulationEnabled: true);

  @override
  State<M2SimulationLabPage> createState() => _M2SimulationLabPageState();
}

class _M2SimulationLabPageState extends State<M2SimulationLabPage> {
  late final WSWatch _watch = WSWatch(config: M2SimulationLabPage.labConfig);
  final _languageController = TextEditingController(text: '7');
  final _frames = <WSFrameEvent>[];
  final _reports = <WSDeviceReport>[];
  StreamSubscription<WSFrameEvent>? _frameSub;
  StreamSubscription<WSDeviceReport>? _reportSub;
  bool _busy = false;
  String? _lastResult;
  Object? _lastError;

  static const _maxLogLines = 40;

  @override
  void dispose() {
    _frameSub?.cancel();
    _reportSub?.cancel();
    _languageController.dispose();
    _watch.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _lastError = null;
      _lastResult = null;
    });
    try {
      await DemoDebugScope.runAction(_watch, label, action);
      if (mounted) {
        setState(() => _lastResult = '$label：成功');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _lastError = error;
          _lastResult = '$label：失败';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _listenDebug() {
    _frameSub?.cancel();
    _reportSub?.cancel();
    _frameSub = _watch.debug.frames.listen((event) {
      setState(() {
        _frames.insert(0, event);
        if (_frames.length > _maxLogLines) {
          _frames.removeRange(_maxLogLines, _frames.length);
        }
      });
    });
    _reportSub = _watch.debug.reports.listen((report) {
      setState(() {
        _reports.insert(0, report);
        if (_reports.length > 20) {
          _reports.removeRange(20, _reports.length);
        }
      });
    });
  }

  Future<void> _openLab() async {
    await _run('打开实验室', () async {
      await _watch.openSimulationLab();
      _listenDebug();
    });
  }

  Future<void> _closeLab() async {
    await _run('关闭实验室', () async {
      await _watch.closeSimulationLab();
      await _frameSub?.cancel();
      await _reportSub?.cancel();
      _frameSub = null;
      _reportSub = null;
      setState(() {
        _frames.clear();
        _reports.clear();
      });
    });
  }

  int? _parseLanguageCode() {
    final text = _languageController.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 0 || value > 255) return null;
    return value;
  }

  Future<void> _setLanguage() async {
    final code = _parseLanguageCode();
    if (code == null) {
      setState(() {
        _lastResult = '语言码无效（0–255）';
        _lastError = null;
      });
      return;
    }
    await _run('设置语言 $code', () async {
      await _watch.labSetLanguage(code);
    });
  }

  Future<void> _getLanguage() async {
    await _run('读取语言', () async {
      final code = await _watch.labGetLanguage();
      if (mounted) {
        setState(() => _lastResult = '读取语言：$code');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = _watch.isSimulationLabOpen;
    return DemoDebugScaffold(
      watch: _watch,
      appBar: AppBar(title: const Text('M2 模拟实验室')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const ListTile(
              leading: Icon(Icons.science_outlined),
              title: Text('M2 模拟实验室'),
              subtitle: Text('内存模拟传输 · 非正式蓝牙连接 · 不会进入 ready'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy || open ? null : _openLab,
                child: const Text('打开实验室'),
              ),
              OutlinedButton(
                onPressed: _busy || !open ? null : _closeLab,
                child: const Text('关闭实验室'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _languageController,
            enabled: open && !_busy,
            decoration: const InputDecoration(
              labelText: '语言编码 (0–255)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _busy || !open ? null : _setLanguage,
                child: const Text('设置语言'),
              ),
              FilledButton.tonal(
                onPressed: _busy || !open ? null : _getLanguage,
                child: const Text('读取语言'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_lastResult != null)
            Card(
              child: ListTile(
                title: Text(_lastResult!),
                subtitle: _lastError != null ? Text('$_lastError') : null,
              ),
            ),
          const DemoActionCard(),
          Text('帧日志 (${_frames.length})', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (_frames.isEmpty)
            Text(
              open ? '等待收发…' : '打开实验室后显示 Link/Session 帧',
              style: theme.textTheme.bodySmall,
            )
          else
            ..._frames.map(
              (e) => ListTile(
                dense: true,
                title: Text(
                  '${e.direction.name} ${e.kind.name}'
                  '${e.seq != null ? ' seq=${e.seq}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                subtitle: Text(
                  e.keys
                      .map((k) =>
                          '${k.address.cmd.toRadixString(16)}:${k.address.key.toRadixString(16)} ${k.name ?? ''}')
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('设备上报 (${_reports.length})', style: theme.textTheme.titleSmall),
          if (_reports.isNotEmpty)
            ..._reports.take(5).map(
                  (r) => ListTile(
                    dense: true,
                    title: Text(r.kind.name, style: theme.textTheme.bodySmall),
                    subtitle: Text('${r.data.length} B'),
                  ),
                ),
        ],
      ),
    );
  }
}
