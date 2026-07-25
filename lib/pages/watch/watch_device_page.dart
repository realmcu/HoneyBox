import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/app_drawer.dart';
import '../device/widgets/action_card.dart';

/// Watch 应用连接设备后的主页 —— 结构对齐 eBadge 的 [DevicePage]：
/// 顶部已连接状态条 + Watch 状态摘要卡 + 2×2 功能网格。
///
/// 四张功能卡（表盘推送 / 通知转发 / 运动·健康 / 固件 OTA）当前都指向各自的
/// 占位子页。摘要卡里的电量 / 固件版本 / 当前表盘需要通过 BLE 从设备回读，
/// 协议尚未接入前显示占位符 "—"，不展示假数据。
class WatchDevicePage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const WatchDevicePage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<WatchDevicePage> createState() => _WatchDevicePageState();
}

class _WatchDevicePageState extends ConsumerState<WatchDevicePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onDisconnectTap() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('断开连接', textAlign: TextAlign.center),
        content: const Text('确认断开设备连接？'),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(bleNotifierProvider.notifier).disconnect();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  child: const Text('断开'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                  ),
                  child: const Text('取消'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _open(String route) {
    Navigator.pushNamed(
      context,
      route,
      arguments: {
        'deviceName': widget.deviceName,
        'deviceId': widget.deviceId,
      },
    );
  }

  static const _actions = [
    _ActionItem(
        icon: Icons.palette_outlined, title: '表盘推送', route: '/watch-face'),
    _ActionItem(
        icon: Icons.notifications_active_outlined,
        title: '通知转发',
        route: '/watch-notification'),
    _ActionItem(
        icon: Icons.favorite_outline,
        title: '运动 / 健康',
        route: '/watch-health'),
    _ActionItem(
        icon: Icons.system_update_alt,
        title: '固件 OTA 升级',
        route: '/watch-ota'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.5,
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          TextButton.icon(
            onPressed: _onDisconnectTap,
            icon: Icon(Icons.link_off, size: 18, color: cs.error),
            label: const Text('断开'),
            style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 已连接状态条 —— 与 DevicePage 顶部一致的样式。
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.watch_outlined,
                          color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('已连接',
                              style: tt.titleSmall
                                  ?.copyWith(color: cs.secondary)),
                          const SizedBox(height: 2),
                          Text(widget.deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  tt.bodySmall?.copyWith(color: cs.outline)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _open('/wifi'),
                      icon: const Icon(Icons.wifi_tethering, size: 18),
                      label: const Text('WiFi 配网'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              // Watch 状态摘要卡（青绿渐变，Watch 专属 accent）。
              _WatchSummaryCard(deviceName: widget.deviceName),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  physics: const BouncingScrollPhysics(),
                  children: _actions
                      .map((a) => ActionCard(
                            icon: a.icon,
                            title: a.title,
                            onTap: () => _open(a.route),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Watch 专属的状态摘要卡。电量 / 固件 / 当前表盘需通过 BLE 从设备回读，
/// 协议接入前统一显示 "—"，避免展示假数据。
class _WatchSummaryCard extends StatelessWidget {
  final String deviceName;

  const _WatchSummaryCard({required this.deviceName});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.watchAccent, AppTheme.watchAccentDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.watchAccent.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.watch, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前表盘 · —',
                    style: tt.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _SummaryChip(icon: Icons.battery_full, label: '电量 —'),
                    _SummaryChip(icon: Icons.memory, label: '固件 —'),
                    _SummaryChip(
                        icon: Icons.bluetooth_connected, label: 'BLE 已连接'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String title;
  final String route;
  const _ActionItem(
      {required this.icon, required this.title, required this.route});
}
