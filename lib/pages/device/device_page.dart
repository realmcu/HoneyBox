import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import 'widgets/action_card.dart';

class DevicePage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const DevicePage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends ConsumerState<DevicePage>
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
        // Two full-width buttons stacked vertically — identical style, distinct
        // colors (destructive on top, neutral cancel below).
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
                    // Clearing the connection makes the root gate fall back to
                    // the scanner automatically.
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
    _ActionItem(icon: Icons.image_outlined, title: '图片', route: '/image'),
    _ActionItem(
        icon: Icons.chat_bubble_outline, title: '弹幕', route: '/danmaku'),
    _ActionItem(
        icon: Icons.movie_creation_outlined, title: '视频 / GIF', route: '/video'),
    _ActionItem(
        icon: Icons.live_tv_outlined, title: '流媒体', route: '/stream'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          TextButton.icon(
            onPressed: _onDisconnectTap,
            icon: const Icon(Icons.link_off, size: 18),
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
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.bluetooth_connected,
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

class _ActionItem {
  final IconData icon;
  final String title;
  final String route;
  const _ActionItem(
      {required this.icon, required this.title, required this.route});
}
