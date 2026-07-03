import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/ble_provider.dart';
import '../../services/system_settings.dart';
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

class _ScanPageState extends ConsumerState<ScanPage>
    with WidgetsBindingObserver {
  final TextEditingController _filterCtrl =
      TextEditingController(text: _kDefaultFilter);
  String _filter = _kDefaultFilter;
  bool _onlyConnectable = false;
  String? _connectingId;
  bool _locationOff = false;
  late BleNotifier _bleNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bleNotifier = ref.read(bleNotifierProvider.notifier);
    _filterCtrl.addListener(() {
      if (_filter != _filterCtrl.text) {
        setState(() => _filter = _filterCtrl.text);
      }
    });
    _checkLocationService();
    Future.microtask(_bleNotifier.startScan);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _filterCtrl.dispose();
    _bleNotifier.stopScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when returning from the location settings screen; if the user
    // just enabled location, kick off a fresh scan automatically.
    if (state == AppLifecycleState.resumed) {
      final wasOff = _locationOff;
      _checkLocationService().then((_) {
        if (wasOff && !_locationOff) _bleNotifier.startScan();
      });
    }
  }

  /// Query the OS location-services (GPS) state. BLE scanning on Android needs
  /// it on; when off we surface the top-of-list reminder banner.
  Future<void> _checkLocationService() async {
    final status = await Permission.location.serviceStatus;
    final off = status == ServiceStatus.disabled;
    if (mounted && off != _locationOff) {
      setState(() => _locationOff = off);
    }
  }

  void _startScan() {
    _checkLocationService();
    _bleNotifier.startScan();
  }

  Future<void> _restartScan() async {
    await _checkLocationService();
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
        title: Text('扫描设备', style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          if (scanning)
            TextButton.icon(
              onPressed: _bleNotifier.stopScan,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('停止'),
              style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
            )
          else
            TextButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('扫描'),
              style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(cs, tt, all.length, devices.length, scanning),
          if (_locationOff) _buildLocationBanner(cs, tt),
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
      color: cs.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            TextField(
              controller: _filterCtrl,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.filter_alt_outlined,
                    size: 20, color: cs.onSurfaceVariant),
                hintText: '按名称或地址过滤',
                suffixIcon: _filter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _filterCtrl.clear,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilterChip(
                  label: const Text('eBadge'),
                  selected: _filter.trim() == _kDefaultFilter,
                  onSelected: (sel) =>
                      _filterCtrl.text = sel ? _kDefaultFilter : '',
                  backgroundColor: Colors.white,
                  selectedColor: cs.primaryContainer,
                  side: BorderSide.none,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('仅可连接'),
                  selected: _onlyConnectable,
                  onSelected: (sel) => setState(() => _onlyConnectable = sel),
                  backgroundColor: Colors.white,
                  selectedColor: cs.primaryContainer,
                  side: BorderSide.none,
                ),
                const Spacer(),
                if (scanning) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('$shown / $total',
                    style: tt.labelMedium?.copyWith(color: cs.onPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // One-line reminder (nRF-Connect style): brief message on the left, two
  // clickable text actions on the right — 打开 (open location settings) and
  // 说明 (explain why location is needed).
  Widget _buildLocationBanner(ColorScheme cs, TextTheme tt) {
    return Material(
      color: cs.error,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        child: Row(
          children: [
            Icon(Icons.location_off, color: cs.onError, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '定位未开启',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: cs.onError),
              ),
            ),
            _bannerAction(cs, '打开', SystemSettings.openLocationSettings),
            _bannerAction(cs, '说明', _showLocationInfo),
          ],
        ),
      ),
    );
  }

  Widget _bannerAction(ColorScheme cs, String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.onError,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _showLocationInfo() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('为什么需要定位？', textAlign: TextAlign.center),
        content: const Text(
          'Android 系统将扫描蓝牙(BLE)设备视为可能推断位置的行为，'
          '因此必须开启系统「定位」服务，App 才能搜索到附近的设备。\n\n'
          '本 App 仅用它来完成蓝牙扫描，不会收集或上传你的地理位置。',
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                SystemSettings.openLocationSettings();
              },
              child: const Text('去开启'),
            ),
          ),
        ],
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
                          onPressed: _startScan,
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
