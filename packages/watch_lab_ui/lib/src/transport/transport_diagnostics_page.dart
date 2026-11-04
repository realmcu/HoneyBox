import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import 'ble_permissions.dart';
import 'jw_transport_helpers.dart';

/// Which GATT profile the transport diagnostics page uses by default.
enum TransportProfileMode {
  /// JW Realtek FF only (JW Watch Lab tab).
  jwOnly,

  /// Nordic UART only (WS transport smoke).
  wsUartOnly,

  /// Dropdown to switch JW / WS (standalone example / advanced).
  selectable,
}

/// L0 transport lab: scan, connect, raw bytes, optional JW frame probes.
class TransportDiagnosticsPage extends StatefulWidget {
  const TransportDiagnosticsPage({
    super.key,
    this.profileMode = TransportProfileMode.selectable,
    this.title = '传输诊断',
  });

  final TransportProfileMode profileMode;
  final String title;

  @override
  State<TransportDiagnosticsPage> createState() =>
      _TransportDiagnosticsPageState();
}

class _TransportDiagnosticsPageState extends State<TransportDiagnosticsPage> {
  final scanner = WatchBleScanner();
  final hex = TextEditingController();
  final entries = <String>[];
  final subscriptions = <StreamSubscription<dynamic>>[];
  List<WatchBleAdvertisement> devices = [];
  WatchBleConnection? connection;
  bool busy = false;
  late bool wsProfile;

  @override
  void initState() {
    super.initState();
    wsProfile = switch (widget.profileMode) {
      TransportProfileMode.jwOnly => false,
      TransportProfileMode.wsUartOnly => true,
      TransportProfileMode.selectable => false,
    };
    subscriptions.add(scanner.results.listen((value) {
      if (mounted) setState(() => devices = value);
    }));
    subscriptions.add(scanner.errors.listen(log));
  }

  void log(Object value) {
    if (!mounted) return;
    setState(() {
      entries.insert(0, '${DateTime.now().toIso8601String()} $value');
      if (entries.length > 200) entries.removeLast();
    });
  }

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

  Future<void> scan() async {
    await ensureBleLabPermissions();
    await scanner.stop();
    await scanner.start();
    log('扫描开始');
  }

  WatchBleProfile _activeProfile() =>
      wsProfile ? wsUartDiagnosticProfile() : jwDiagnosticProfile();

  bool get _jwProbesEnabled =>
      !wsProfile && widget.profileMode != TransportProfileMode.wsUartOnly;

  List<WatchBleAdvertisement> get _visibleDevices {
    if (widget.profileMode == TransportProfileMode.jwOnly) {
      return devices.where(isJwCandidate).toList();
    }
    return devices;
  }

  Future<void> connect(WatchBleAdvertisement device) async {
    await scanner.stop();
    await connection?.dispose();
    final profile = _activeProfile();
    final wire = WatchBleTransport(config: WatchBleConfig(profile: profile))
        .createConnection(
            WatchDeviceTarget(transportId: 'ble', deviceId: device.deviceId));
    connection = wire;
    subscriptions
        .add(wire.received.listen((bytes) => log('RX ${_hex(bytes)}')));
    subscriptions.add(wire.stateChanges.listen((state) => log(
        '${state.name}; write limit=${wire.writeLimits.maxWriteLength}')));
    await wire.connect();
    log('已连接 ${device.name} ${device.deviceId}');
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  Future<void> send() async {
    final text = hex.text.replaceAll(RegExp(r'\s'), '');
    if (text.isEmpty ||
        text.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
      throw const FormatException('请输入完整十六进制字节');
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < text.length; i += 2)
        int.parse(text.substring(i, i + 2), radix: 16)
    ]);
    await connection!.write(bytes);
    log('TX ${_hex(bytes)}');
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(scanner.dispose());
    connection?.dispose().ignore();
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = connection?.state == WatchTransportState.connected;
    final showProfilePicker =
        widget.profileMode == TransportProfileMode.selectable;
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton(
                            onPressed:
                                busy || connected ? null : () => action(scan),
                            child: const Text('扫描')),
                        OutlinedButton(
                            onPressed: busy ? null : () => action(scanner.stop),
                            child: const Text('停止扫描')),
                        OutlinedButton(
                            onPressed: busy || connection == null
                                ? null
                                : () => action(() async {
                                      await connection!.dispose();
                                      log('已释放连接');
                                    }),
                            child: const Text('断开')),
                        if (showProfilePicker)
                          DropdownButton<bool>(
                              value: wsProfile,
                              items: const [
                                DropdownMenuItem(
                                    value: false, child: Text('JW Realtek FF')),
                                DropdownMenuItem(
                                    value: true, child: Text('WS UART'))
                              ],
                              onChanged: busy || connected
                                  ? null
                                  : (value) =>
                                      setState(() => wsProfile = value!)),
                      ]),
                  SizedBox(
                      height: 180,
                      child: ListView(children: [
                        for (final device in _visibleDevices)
                          ListTile(
                              dense: true,
                              title: Text(
                                  '${device.name.isEmpty ? "未命名设备" : device.name} (${device.rssi})'),
                              subtitle: Text(device.deviceId),
                              trailing: TextButton(
                                  onPressed: busy || connected
                                      ? null
                                      : () => action(() => connect(device)),
                                  child: const Text('连接')))
                      ])),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                            width: 200,
                            child: TextField(
                                controller: hex,
                                decoration: const InputDecoration(
                                    labelText: '原始十六进制字节',
                                    isDense: true))),
                        FilledButton(
                            onPressed:
                                busy || !connected ? null : () => action(send),
                            child: const Text('发送')),
                        if (_jwProbesEnabled) ...[
                          OutlinedButton(
                              onPressed: busy || !connected
                                  ? null
                                  : () => action(() async {
                                        log('JW 电量：${await readJwBattery(connection!)}%');
                                      }),
                              child: const Text('JW 电量')),
                          OutlinedButton(
                              onPressed: busy || !connected
                                  ? null
                                  : () => action(() async {
                                        log('JW 语言：${await queryJwLanguage(connection!)}');
                                      }),
                              child: const Text('JW 语言')),
                        ],
                      ]),
                  const SizedBox(height: 12),
                  const Text('收发与状态日志（最近 200 条）'),
                  Expanded(
                      child: ListView(children: [
                    for (final entry in entries)
                      SelectableText(entry,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12))
                  ])),
                ])));
  }
}
