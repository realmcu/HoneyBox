import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/wifi_provider.dart';

/// WiFi 配网 — open a local-only hotspot, push its SSID/password to the device
/// over BLE (CMD 0x0D), wait for the device to join and report its IP, then
/// open the TCP video link. On failure a TCP-only reconnect can be retriggered.
///
/// The hotspot + TCP link are owned by [WifiManager] (an app-scoped singleton)
/// so they survive navigating to the stream page.
class WifiPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const WifiPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends ConsumerState<WifiPage> {
  @override
  void initState() {
    super.initState();
    // Re-check the live WiFi / TCP state on entry so the page shows the current
    // status (not a stale phase or old failure) from a previous session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(wifiManagerProvider).refreshState();
    });
  }

  Future<bool> _ensurePermissions() async {
    // The local-hotspot provisioning flow is Android-only (startLocalOnlyHotspot
    // + NEARBY_WIFI_DEVICES / ACCESS_FINE_LOCATION). On non-Android platforms
    // there are no such runtime permissions to request, so report success and
    // let the underlying manager decide feature availability.
    if (!Platform.isAndroid) return true;
    // startLocalOnlyHotspot needs NEARBY_WIFI_DEVICES on Android 13+ and
    // ACCESS_FINE_LOCATION on older builds — request both, proceed if the
    // OS-relevant one is granted.
    final results = await [
      Permission.nearbyWifiDevices,
      Permission.location,
    ].request();
    final nearby = results[Permission.nearbyWifiDevices];
    final location = results[Permission.location];
    return (nearby?.isGranted ?? false) || (location?.isGranted ?? false);
  }

  Future<void> _provision() async {
    if (!await _ensurePermissions()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要「附近的设备」或定位权限才能开启本地热点')),
      );
      return;
    }
    await ref.read(wifiManagerProvider).provisionAndConnect();
  }

  Future<void> _reconnect() async {
    await ref.read(wifiManagerProvider).connectTcp();
  }

  Future<void> _disconnect() async {
    await ref.read(wifiManagerProvider).disconnect();
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label 已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(wifiManagerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('WiFi 配网')),
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, _) => _body(context, manager),
      ),
    );
  }

  Widget _body(BuildContext context, WifiManager m) {
    final cs = Theme.of(context).colorScheme;
    final phase = m.phase;
    final connected = m.isConnected;
    final busy = m.busy;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scrollable content — adapts to small screens / long error text so
          // the pinned bottom buttons never overflow.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusCard(context, m),
                  const SizedBox(height: 12),
                  if (m.hotspotInfo != null) ...[
                    _credentials(cs, m),
                    const SizedBox(height: 12),
                  ],
                  if (connected) _linkCard(cs, m),
                  if (phase == WifiPhase.failed && m.message != null) ...[
                    const SizedBox(height: 12),
                    Text(m.message!,
                        style: TextStyle(color: cs.error, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (connected)
            FilledButton.icon(
              onPressed: busy ? null : _disconnect,
              icon: const Icon(Icons.link_off),
              label: const Text('断开 WiFi'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: cs.error,
              ),
            )
          else ...[
            FilledButton.icon(
              onPressed: busy ? null : _provision,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(busy ? '配网中…' : '开启热点并配网连接'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: cs.primary,
              ),
            ),
            if (m.canReconnect && !busy) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _reconnect,
                icon: const Icon(Icons.refresh),
                label: Text('重新连接 ${m.deviceIp}:${m.devicePort}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context, WifiManager m) {
    final cs = Theme.of(context).colorScheme;
    final connected = m.isConnected;
    final active = m.hotspotInfo != null || connected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              connected
                  ? Icons.wifi
                  : (active ? Icons.wifi_tethering : Icons.wifi_tethering_off),
              color: connected
                  ? cs.primary
                  : (active ? cs.secondary : cs.outline),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _phaseTitle(m.phase, connected),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (m.message != null && m.phase != WifiPhase.failed) ...[
                    const SizedBox(height: 2),
                    Text(
                      m.message!,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (m.busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  String _phaseTitle(WifiPhase phase, bool connected) => switch (phase) {
        WifiPhase.idle => '未配网',
        WifiPhase.hotspotStarting => '正在开启热点…',
        WifiPhase.provisioning => '正在下发配置…',
        WifiPhase.deviceConnecting => '等待设备接入…',
        WifiPhase.tcpConnecting => '正在建立视频连接…',
        WifiPhase.connected => 'WiFi 视频已连接',
        WifiPhase.failed => '配网/连接失败',
      };

  Widget _linkCard(ColorScheme cs, WifiManager m) {
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _row('设备 IP', '${m.deviceIp}:${m.devicePort}', null),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.check_circle, color: cs.primary),
              title: const Text('视频通道已就绪', style: TextStyle(fontSize: 13)),
              subtitle: const Text('前往「流媒体」页，通道选择 WiFi 即可投屏',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentials(ColorScheme cs, WifiManager m) {
    final info = m.hotspotInfo!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _row('网络名称 (SSID)', info.ssid, () => _copy('SSID', info.ssid)),
            const Divider(height: 1),
            _row('密码', info.password, () => _copy('密码', info.password)),
            if (info.band != null) ...[
              const Divider(height: 1),
              _row('频段', info.band!, null),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, VoidCallback? onCopy) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        value.isEmpty ? '—' : value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
      trailing: onCopy == null
          ? null
          : IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: '复制',
              onPressed: onCopy,
            ),
    );
  }
}
