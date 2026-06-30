import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import 'widgets/device_tile.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage>
    with SingleTickerProviderStateMixin {
  String? _connectingDeviceId;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late BleNotifier _bleNotifier;

  @override
  void initState() {
    super.initState();
    _bleNotifier = ref.read(bleNotifierProvider.notifier);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    Future.microtask(() {
      _bleNotifier.startScan();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bleNotifier.stopScan();
    super.dispose();
  }

  void _onDeviceTap(String deviceId, String name) {
    setState(() => _connectingDeviceId = deviceId);
    ref
        .read(bleNotifierProvider.notifier)
        .connect(deviceId, name)
        .then((success) {
      if (!mounted) return;
      if (success) {
        Navigator.pushReplacementNamed(context, '/device', arguments: {
          'deviceId': deviceId,
          'deviceName': name,
        });
      } else {
        setState(() => _connectingDeviceId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('搜索设备')),
      body: Consumer(
        builder: (context, ref, _) {
          final devices = ref.watch(scannedDevicesProvider);
          final bleState = ref.watch(bleNotifierProvider);

          if (devices.isEmpty && bleState == BleState.scanning) {
            return _buildEmptyScanning(cs, tt);
          }
          if (devices.isEmpty) {
            return _buildEmptyIdle(cs, tt);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary
                              .withValues(alpha: _pulseAnimation.value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '发现 ${devices.length} 个设备',
                      style: tt.titleMedium?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isConnecting = _connectingDeviceId == device.deviceId;
                    return DeviceTile(
                      deviceId: device.deviceId,
                      name: device.name,
                      rssi: device.rssi,
                      isConnecting: isConnecting,
                      onTap: isConnecting
                          ? null
                          : () => _onDeviceTap(device.deviceId, device.name),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyScanning(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Icon(Icons.bluetooth_searching,
                    size: 36, color: cs.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('正在搜索附近的 eBadge 设备…', style: tt.bodyLarge),
          const SizedBox(height: 12),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyIdle(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text('未找到设备', style: tt.titleMedium),
          const SizedBox(height: 8),
          Text('请确保设备已开启并靠近手机', style: tt.bodyMedium),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.read(bleNotifierProvider.notifier).startScan();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新扫描'),
          ),
        ],
      ),
    );
  }
}
