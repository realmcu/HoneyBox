import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'debug/debug_capture.dart';

/// Opens the lightweight Raw debugger (方案 A：半屏，无多 Tab 大页).
Future<void> showDemoRawDebugSheet(
  BuildContext context, {
  required WSWatch watch,
  required DemoDebugCapture capture,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: DemoRawDebugSheet(watch: watch, capture: capture),
    ),
  );
}

class DemoRawDebugSheet extends StatefulWidget {
  const DemoRawDebugSheet(
      {super.key, required this.watch, required this.capture});
  final WSWatch watch;
  final DemoDebugCapture capture;

  @override
  State<DemoRawDebugSheet> createState() => _DemoRawDebugSheetState();
}

class _DemoRawDebugSheetState extends State<DemoRawDebugSheet> {
  final _l2 = TextEditingController(text: '02 00 03 00 01 01');
  final _replyL2 = TextEditingController(text: '02 00 03 00 02 02');
  final _protocolSearch = TextEditingController();
  bool _waitReply = true, _busy = false, _showProtocols = false;
  String? _message;
  StreamSubscription<WSConnectionChange>? _states;

  @override
  void initState() {
    super.initState();
    _states = widget.watch.stateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _states?.cancel();
    _l2.dispose();
    _replyL2.dispose();
    _protocolSearch.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_busy &&
      (widget.watch.state == WSConnectionState.ready ||
          widget.watch.isSimulationLabOpen);

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final request = l2HexToRawRequest(_l2.text);
      WSReplyAddress? reply;
      if (_waitReply) {
        reply = l2HexToReplyAddress(_replyL2.text);
        if (reply.cmd != request.cmd ||
            reply.version != request.version ||
            reply.key != request.key) {
          throw const FormatException('回应地址须与请求的 cmd/version/key 一致');
        }
      }
      final value = await widget.capture.run('Raw', () async {
        final result = await widget.watch.debug.sendRaw(WSRawRequest(
            cmd: request.cmd,
            version: request.version,
            key: request.key,
            settingOpcode: request.settingOpcode,
            data: request.data,
            replyAddress: reply,
            replyTimeout: _waitReply ? const Duration(seconds: 5) : null));
        return result == null
            ? 'L1 ACK'
            : '回应操作数据：${debugHex(result)}';
      });
      if (mounted) setState(() => _message = '成功 · $value');
    } catch (e) {
      if (mounted) setState(() => _message = '${e.runtimeType}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyProtocol(WSProtocolView protocol) {
    if (protocol.address.direction != WSWireDirection.phoneToDevice) {
      setState(() => _message = '仅 phone→device 条目可填入请求 hex');
      return;
    }
    final hex = debugHex(exampleRequestHex(protocol.address));
    setState(() {
      _l2.text = hex;
      _waitReply = protocol.address.cmd == 2 &&
          protocol.address.settingOpcode == 1;
      if (_waitReply) {
        _replyL2.text = debugHex(exampleReplyHex(protocol.address));
      }
      _message = '已带入 ${protocol.name}，可改 hex 后发送';
    });
  }

  List<WSProtocolView> get _filteredProtocols {
    final q = _protocolSearch.text.toLowerCase();
    return widget.watch.debug.protocols
        .where((p) =>
            p.status == WSProtocolStatus.active &&
            p.address.direction == WSWireDirection.phoneToDevice &&
            '${p.name} ${p.address} ${p.specRef}'.toLowerCase().contains(q))
        .take(40)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return SizedBox(
        height: maxHeight,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
                    Text('Raw 调试',
                        style: theme.textTheme.titleLarge,
                        key: const Key('raw-sheet-title')),
                    Text('状态：${widget.watch.state.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    const Text(
                        'L2 请求 hex（空格分隔，不含 L1）。设置类含操作码；读语言示例：02 00 03 00 01 01'),
                    TextField(
                        controller: _l2,
                        enabled: !_busy,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'L2 请求 hex',
                            border: OutlineInputBorder()),
                        key: const Key('raw-l2-request')),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('等待完整回应'),
                        value: _waitReply,
                        onChanged:
                            _busy ? null : (v) => setState(() => _waitReply = v)),
                    if (_waitReply)
                      TextField(
                          controller: _replyL2,
                          enabled: !_busy,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'L2 回应地址 hex（device→phone）',
                              border: OutlineInputBorder()),
                          key: const Key('raw-l2-reply')),
                    FilledButton(
                        onPressed: _canSend ? _send : null,
                        key: const Key('raw-send'),
                        child: const Text('发送 Raw')),
                    if (!_canSend && widget.watch.state != WSConnectionState.ready)
                      Text('请先在 M3 连接进入 ready，或使用 M2 实验室。',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error)),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(_message!,
                          key: const Key('raw-result')),
                    ],
                    const Divider(height: 32),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('从协议表带入'),
                        trailing: Icon(_showProtocols
                            ? Icons.expand_less
                            : Icons.expand_more),
                        onTap: () =>
                            setState(() => _showProtocols = !_showProtocols)),
                    if (_showProtocols) ...[
                      TextField(
                          controller: _protocolSearch,
                          decoration: const InputDecoration(
                              labelText: '搜索 active 请求',
                              border: OutlineInputBorder(),
                              isDense: true),
                          onChanged: (_) => setState(() {})),
                      for (final p in _filteredProtocols)
                        ListTile(
                            dense: true,
                            title: Text(p.name, maxLines: 1),
                            subtitle: Text('${p.address}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => _applyProtocol(p)),
                    ],
            ],
        ),
    );
  }
}

Uint8List exampleRequestHex(WSProtocolAddress address) {
  final data = address.cmd == 2 && address.settingOpcode == 1
      ? Uint8List(0)
      : Uint8List(0);
  return _encodeL2(address, data);
}

Uint8List exampleReplyHex(WSProtocolAddress request) {
  if (request.cmd != 2 || request.settingOpcode != 1) {
    return Uint8List(0);
  }
  return _encodeL2(
      WSProtocolAddress(
          cmd: request.cmd,
          version: request.version,
          key: request.key,
          settingOpcode: 2,
          direction: WSWireDirection.deviceToPhone),
      Uint8List(0));
}

Uint8List _encodeL2(WSProtocolAddress address, Uint8List data) {
  address.validate();
  final value = [
    if (address.settingOpcode != null) address.settingOpcode!,
    ...data,
  ];
  return Uint8List.fromList([
    address.cmd,
    address.version << 4,
    address.key,
    value.length >> 8,
    value.length & 255,
    ...value,
  ]);
}

({int cmd, int version, int key, int? settingOpcode, Uint8List data})
    l2HexToFields(String text) {
  final bytes = parseDebugHex(text);
  if (bytes.length < 5) {
    throw const FormatException('L2 hex 至少 5 字节（含 Length）');
  }
  final cmd = bytes[0];
  final version = bytes[1] >> 4;
  if ((bytes[1] & 0x0f) != 0) {
    throw const FormatException('Version 须在高 4 bit，低 4 bit 为 0');
  }
  final key = bytes[2];
  final length = (bytes[3] << 8) | bytes[4];
  if (bytes.length != 5 + length) {
    throw const FormatException('Length 与后续字节不匹配');
  }
  final value = bytes.sublist(5);
  if (cmd == 2) {
    if (value.isEmpty) {
      throw const FormatException('设置命令缺少操作码');
    }
    return (
      cmd: cmd,
      version: version,
      key: key,
      settingOpcode: value[0],
      data: Uint8List.fromList(value.sublist(1)),
    );
  }
  return (
    cmd: cmd,
    version: version,
    key: key,
    settingOpcode: null,
    data: Uint8List.fromList(value),
  );
}

WSRawRequest l2HexToRawRequest(String text) {
  final f = l2HexToFields(text);
  return WSRawRequest(
      cmd: f.cmd,
      version: f.version,
      key: f.key,
      settingOpcode: f.settingOpcode,
      data: f.data);
}

WSReplyAddress l2HexToReplyAddress(String text) {
  final f = l2HexToFields(text);
  return WSProtocolAddress(
      cmd: f.cmd,
      version: f.version,
      key: f.key,
      settingOpcode: f.settingOpcode,
      direction: WSWireDirection.deviceToPhone);
}
