import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import 'widgets/device_tile.dart';

/// Default name filter — the app is built for eBadge devices, so we hide the
/// noise of surrounding BLE peripherals out of the box. Clearing the filter
/// (or the chip) reveals everything.
const String _kDefaultFilter = 'eBadge';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final TextEditingController _filterCtrl =
      TextEditingController(text: _kDefaultFilter);
  String _filter = _kDefaultFilter;
  bool _onlyConnectable = false;
  String? _connectingId;
  late BleNotifier _bleNotifier;

  @override
  void initState() {
    super.initState();
    _bleNotifier = ref.read(bleNotifierProvider.notifier);
    _filterCtrl.addListener(() {
      if (_filter != _filterCtrl.text) {
        setState(() => _filter = _filterCtrl.text);
      }
    });
    Future.microtask(_bleNotifier.startScan);
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _bleNotifier.stopScan();
    super.dispose();
  }

  Future<void> _restartScan() async {
    await _bleNotifier.startScan();
    // Keep the pull-to-refresh spinner up briefly so the gesture feels alive;
    // scanning itself continues in the background afterwards.
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  void _onConnect(ScanDevice device) {
    setState(() => _connectingId = device.deviceId);
    ref
        .read(bleNotifierProvider.notifier)
        .connect(device.deviceId, device.name)
        .then((success) {
      if (!mounted) return;
      // On success the root gate swaps to the device page automatically once
      // `connectedDeviceProvider` updates — no navigation needed here.
      if (!success) {
        setState(() => _connectingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接失败，请重试')),
        );
      }
    });
  }

  List<ScanDevice> _applyFilter(List<ScanDevice> all) {
    final q = _filter.trim().toLowerCase();
    return all.where((d) {
      if (_onlyConnectable && !d.connectable) return false;
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.deviceId.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bleState = ref.watch(bleNotifierProvider);
    final all = ref.watch(scannedDevicesProvider);
    final devices = _applyFilter(all);
    final scanning = bleState == BleState.scanning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描设备'),
        actions: [
          if (scanning)
            TextButton.icon(
              onPressed: _bleNotifier.stopScan,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('停止'),
            )
          else
            TextButton.icon(
              onPressed: _bleNotifier.startScan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('扫描'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(cs, tt, all.length, devices.length, scanning),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _restartScan,
              child: devices.isEmpty
                  ? _buildEmpty(cs, tt, scanning)
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return DeviceTile(
                          deviceId: device.deviceId,
                          name: device.name,
                          rssi: device.rssi,
                          connectable: device.connectable,
                          isConnecting: _connectingId == device.deviceId,
                          onConnect: _connectingId == null
                              ? () => _onConnect(device)
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    ColorScheme cs,
    TextTheme tt,
    int total,
    int shown,
    bool scanning,
  ) {
    return Material(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            TextField(
              controller: _filterCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.filter_alt_outlined, size: 20),
                hintText: '按名称或地址过滤',
                suffixIcon: _filter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _filterCtrl.clear,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilterChip(
                  label: const Text('eBadge'),
                  selected: _filter.trim() == _kDefaultFilter,
                  onSelected: (sel) =>
                      _filterCtrl.text = sel ? _kDefaultFilter : '',
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('仅可连接'),
                  selected: _onlyConnectable,
                  onSelected: (sel) => setState(() => _onlyConnectable = sel),
                ),
                const Spacer(),
                if (scanning) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('$shown / $total', style: tt.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs, TextTheme tt, bool scanning) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: scanning
                    ? [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(Icons.bluetooth_searching,
                              size: 36, color: cs.primary),
                        ),
                        const SizedBox(height: 24),
                        Text('正在搜索附近的 eBadge 设备…', style: tt.bodyLarge),
                        const SizedBox(height: 12),
                        Text('下拉可重新扫描', style: tt.bodySmall),
                      ]
                    : [
                        Icon(Icons.bluetooth_disabled,
                            size: 64, color: cs.outline),
                        const SizedBox(height: 16),
                        Text('未发现设备', style: tt.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _filter.trim().isEmpty
                              ? '请确保设备已开启并靠近手机'
                              : '没有匹配「$_filter」的设备，可清除过滤条件',
                          style: tt.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _bleNotifier.startScan,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新扫描'),
                        ),
                      ],
              ),
            ),
          ),
        );
      },
    );
  }
}
