import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

/// Uses the public M3 API. No SDK internals or HoneyBox services are imported.
class M3ConnectionPage extends StatefulWidget {
  const M3ConnectionPage(
      {super.key, this.config = const WSConfig(simulationEnabled: true)});
  final WSConfig config;
  @override
  State<M3ConnectionPage> createState() => _M3ConnectionPageState();
}

class _M3ConnectionPageState extends State<M3ConnectionPage> {
  late final WSWatch _watch = WSWatch(config: widget.config);
  late final WSScanner _scanner = WSWatch.scanner(config: widget.config);
  final _user = TextEditingController();
  final _stages = <WSConnectionChange>[];
  final _frames = <WSFrameEvent>[];
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<WSScanDevice> _devices = [];
  bool _realScan = false, _busy = false;
  Object? _error;
  String? _result;
  String? _identitySource;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(_watch.stateChanges.listen((change) {
      if (mounted) {
        setState(() {
          _stages.add(change);
          if (_stages.length > 80) _stages.removeAt(0);
        });
      }
    }));
    _subscriptions.add(_watch.debug.frames.listen((frame) {
      if (mounted) {
        setState(() {
          _frames.insert(0, frame);
          if (_frames.length > 60) _frames.removeLast();
        });
      }
    }));
    _subscriptions.add(_scanner.results.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    }));
    _subscriptions.add(_scanner.errors.listen((error) {
      if (mounted) setState(() => _error = error);
    }));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _scanner.dispose();
    _watch.dispose();
    _user.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      await action();
      if (mounted) setState(() => _result = '$label：成功');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _result = '$label：失败';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(WSScanDevice device) => _run('连接', () async {
        _identitySource = _user.text.isEmpty ? 'SDK 默认（持久化）' : '接入方传入';
        _stages.clear();
        _frames.clear();
        await _scanner.stop();
        await _watch.connect(device.deviceId,
            userId: _user.text.isEmpty ? null : _user.text);
      });
  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  @override
  Widget build(BuildContext context) {
    final ready = _watch.state == WSConnectionState.ready;
    final disconnected = _watch.state == WSConnectionState.disconnected;
    final info = _watch.deviceInfo;
    return Scaffold(
      appBar: AppBar(title: const Text('M3 扫描与连接')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('当前状态：${_watch.state.name}',
            key: const Key('m3-state'),
            style: Theme.of(context).textTheme.titleLarge),
        Text(widget.config.simulationEnabled
            ? '模拟模式已开启：虚拟设备无需蓝牙权限。'
            : '模拟模式未开启。'),
        const Text('本阶段可验收 Simulator 的正式连接流程；真实 UART 手表连接在 M7 验收。'),
        TextField(
            controller: _user,
            enabled: disconnected && !_busy,
            decoration: const InputDecoration(
                labelText: '用户 ID（可留空）',
                helperText: '留空使用持久化的默认 ID；1～32 字节 ASCII')),
        SwitchListTile(
            title: const Text('同时扫描真实蓝牙广播'),
            value: _realScan,
            subtitle: const Text('由宿主提供蓝牙权限；扫描失败不影响 Simulator'),
            onChanged: !_busy && disconnected
                ? (v) => setState(() => _realScan = v)
                : null),
        FilledButton.icon(
            onPressed: !_busy && disconnected
                ? () => _run('扫描', () async {
                      await _scanner.stop();
                      await _scanner.start(includeRealDevices: _realScan);
                    })
                : null,
            icon: const Icon(Icons.search),
            label: const Text('扫描设备')),
        for (final device in _devices)
          Card(
              child: ListTile(
                  title:
                      Text(device.name.isEmpty ? device.deviceId : device.name),
                  subtitle: Text(
                      '${device.deviceId} · ${device.isSimulated ? '内存模拟设备' : '${device.rssi} dBm · 真机连接待 M7'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: !_busy && disconnected && device.isSimulated
                      ? () => _connect(device)
                      : null)),
        Wrap(spacing: 8, children: [
          OutlinedButton(
              onPressed: !disconnected
                  ? () async {
                      try {
                        await _watch.disconnect();
                      } catch (e) {
                        if (mounted) setState(() => _error = e);
                      }
                    }
                  : null,
              child: const Text('断开 / 取消连接')),
          OutlinedButton(
              onPressed:
                  ready && !_busy ? () => _run('解绑', _watch.unbind) : null,
              child: const Text('解绑')),
        ]),
        if (_result != null) Text(_result!),
        if (_error != null)
          SelectableText('$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_watch.userId != null)
          SelectableText('当前用户 ID：${_watch.userId}\n来源：$_identitySource'),
        const Divider(),
        const Text('连接状态时间线'),
        for (var i = 0; i < _stages.length; i++)
          ListTile(
              dense: true,
              title: Text(_stages[i].current.name),
              subtitle: Text(
                  '${_stages[i].at.toIso8601String()}${i == 0 ? '' : ' · 上阶段 ${_stages[i].at.difference(_stages[i - 1].at).inMilliseconds} ms'}'
                  '${_stages[i].reason == null ? '' : '\n${_stages[i].reason}'}')),
        if (info != null) ...[
          const Divider(),
          const Text('设备信息'),
          SelectableText(
              '型号：${info.model}\n固件：${info.firmwareVersion}\n协议：${info.protocolVersion}\n硬件：${info.hardwareVersion}\nMAC：${info.btMac}\n序列号：${info.serialNumber}'),
          const SizedBox(height: 8),
          const Text('设备能力：128 bit'),
          SelectableText(_hex(_watch.capabilities!.raw)),
          const Text('功能位分配待规范确认，各项状态为 unknown；全零不解释为全部不支持。'),
        ],
        const Divider(),
        Text('最近收发帧（${_frames.length}/60）'),
        for (final frame in _frames.take(20))
          ListTile(
              dense: true,
              title: Text(
                  '${frame.direction.name} ${frame.kind.name} seq=${frame.seq ?? '-'}'),
              subtitle: Text(_hex(frame.raw))),
      ]),
    );
  }
}
