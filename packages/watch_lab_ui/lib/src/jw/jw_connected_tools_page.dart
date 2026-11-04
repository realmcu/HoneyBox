import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import '../transport/jw_transport_helpers.dart';

/// L0/L1 tools using an existing JW connection (no second scan/connect).
class JwConnectedToolsPage extends StatefulWidget {
  const JwConnectedToolsPage({super.key, required this.connection});

  final WatchBleConnection connection;

  @override
  State<JwConnectedToolsPage> createState() => _JwConnectedToolsPageState();
}

class _JwConnectedToolsPageState extends State<JwConnectedToolsPage> {
  final hex = TextEditingController();
  final entries = <String>[];
  final subscriptions = <StreamSubscription<dynamic>>[];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    subscriptions.add(widget.connection.received
        .listen((b) => log('RX ${_hex(b)}')));
  }

  void log(Object value) {
    if (!mounted) return;
    setState(() {
      entries.insert(0, '${DateTime.now().toIso8601String()} $value');
      if (entries.length > 200) entries.removeLast();
    });
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  Future<void> action(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
    } catch (error) {
      log(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.connection;
    return Scaffold(
      appBar: AppBar(title: const Text('L0 · 原始字节')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MTU ${c.mtu} · write ${c.writeLimits.maxWriteLength}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                            log('JW 电量 ${await readJwBattery(c)}%');
                          }),
                  child: const Text('JW 电量'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                            log('JW 语言 ${await queryJwLanguage(c)}');
                          }),
                  child: const Text('JW 语言'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hex,
                    decoration: const InputDecoration(
                      labelText: '十六进制字节',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                            final text = hex.text.replaceAll(RegExp(r'\s'), '');
                            if (text.isEmpty ||
                                text.length.isOdd ||
                                !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
                              throw const FormatException('请输入完整 hex');
                            }
                            final bytes = Uint8List.fromList([
                              for (var i = 0; i < text.length; i += 2)
                                int.parse(text.substring(i, i + 2), radix: 16)
                            ]);
                            await c.write(bytes);
                            log('TX ${_hex(bytes)}');
                          }),
                  child: const Text('发送'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('日志'),
            Expanded(
              child: ListView(
                children: [
                  for (final e in entries)
                    SelectableText(e,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
