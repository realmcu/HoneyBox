import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

import '../transport/ble_permissions.dart';
import '../transport/jw_scan_filter.dart';

/// JW scan/connect strip: filters [isJwCandidate] (wristband + FD50 services).
class JwBleConnectionPanel extends StatefulWidget {
  const JwBleConnectionPanel({
    super.key,
    required this.onConnectionChanged,
  });

  final ValueChanged<WatchBleConnection?> onConnectionChanged;

  @override
  State<JwBleConnectionPanel> createState() => _JwBleConnectionPanelState();
}

class _JwBleConnectionPanelState extends State<JwBleConnectionPanel> {
  final scanner = WatchBleScanner();
  final subscriptions = <StreamSubscription<dynamic>>[];
  List<WatchBleAdvertisement> devices = [];
  WatchBleConnection? connection;
  bool busy = false;
  String? statusLine;
  StreamSubscription<WatchTransportState>? _connectionStateSub;

  @override
  void initState() {
    super.initState();
    subscriptions.add(scanner.results.listen((value) {
      if (mounted) setState(() => devices = value.where(isJwCandidate).toList());
    }));
    subscriptions.add(scanner.errors.listen((e) => setState(() => statusLine = '$e')));
  }

  Future<void> action(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
    } catch (error) {
      setState(() => statusLine = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    await ensureBleLabPermissions();
    await scanner.stop();
    await scanner.start(services: jwBleScanServiceUuids);
    setState(() => statusLine = '扫描 JW 设备（${jwWristbandServiceUuid.substring(0, 8)}… / fd50）');
  }

  Future<void> connect(WatchBleAdvertisement device) async {
    await scanner.stop();
    await _disposeConnection();
    final wire = WatchBleTransport(config: WatchBleConfig(profile: jwDiagnosticProfile()))
        .createConnection(
            WatchDeviceTarget(transportId: 'ble', deviceId: device.deviceId));
    connection = wire;
    await _connectionStateSub?.cancel();
    _connectionStateSub = wire.stateChanges.listen((state) {
      if (mounted) {
        setState(() => statusLine =
            '${state.name} · write=${wire.writeLimits.maxWriteLength} · mtu=${wire.mtu}');
      }
    });
    await wire.connect();
    widget.onConnectionChanged(wire);
    setState(() => statusLine = '已连接 ${device.name} ${device.deviceId}');
  }

  Future<void> _disposeConnection() async {
    widget.onConnectionChanged(null);
    final old = connection;
    connection = null;
    if (old != null) await old.dispose();
  }

  @override
  void dispose() {
    unawaited(_connectionStateSub?.cancel());
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(scanner.dispose());
    connection?.dispose().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = connection?.state == WatchTransportState.connected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('连接', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '仅列出广播含 Realtek FF（000001ff…）或 FD50 涂鸦服务的设备',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy || connected ? null : () => action(scan),
                  child: const Text('扫描'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => action(scanner.stop),
                  child: const Text('停止'),
                ),
                OutlinedButton(
                  onPressed: busy || connection == null
                      ? null
                      : () => action(() async {
                            await _disposeConnection();
                            setState(() => statusLine = '已断开');
                          }),
                  child: const Text('断开'),
                ),
              ],
            ),
            if (statusLine != null) ...[
              const SizedBox(height: 8),
              Text(statusLine!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
            SizedBox(
              height: 160,
              child: devices.isEmpty
                  ? Center(
                      child: Text(
                        connected ? '已连接' : '未发现 JW 设备',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (_, i) {
                        final d = devices[i];
                        return ListTile(
                          dense: true,
                          title: Text('${d.name.isEmpty ? "未命名" : d.name} (${d.rssi})'),
                          subtitle: Text(d.deviceId, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: TextButton(
                            onPressed: busy || connected ? null : () => action(() => connect(d)),
                            child: const Text('连接'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
