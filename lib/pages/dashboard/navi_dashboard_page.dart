import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ble_provider.dart';
import '../../providers/navi_projection_provider.dart';

/// 导航投屏仪表盘页面。
///
/// BLE 连接后展示设备信息、Profile 验证结果和投屏控制。
class NaviDashboardPage extends ConsumerStatefulWidget {
  const NaviDashboardPage({super.key});

  @override
  ConsumerState<NaviDashboardPage> createState() => _NaviDashboardPageState();
}

class _NaviDashboardPageState extends ConsumerState<NaviDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = ref.watch(connectedDeviceProvider);
    final navi = ref.watch(naviProjectionProvider);
    final profileOk = ref.watch(naviProjectionProvider.notifier).available;

    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 设备信息卡片 ──
          _DeviceCard(info: info, cs: cs, tt: tt),
          const SizedBox(height: 12),

          // ── Profile 验证卡片 ──
          _ProfileCard(available: profileOk, cs: cs, tt: tt),
          const SizedBox(height: 12),

          // ── 投屏控制卡片 ──
          _ProjectionCard(
            state: navi,
            profileOk: profileOk,
            notifier: ref.read(naviProjectionProvider.notifier),
            cs: cs,
            tt: tt,
          ),

          // ── 状态详情 ──
          if (navi == NaviProjState.projecting ||
              navi == NaviProjState.error) ...[
            const SizedBox(height: 12),
            _StatusCard(
              notifier: ref.read(naviProjectionProvider.notifier),
              cs: cs,
              tt: tt,
            ),
          ],
        ],
      ),
    );
  }
}

// ── 设备信息卡片 ──

class _DeviceCard extends StatelessWidget {
  final ConnectedDeviceInfo? info;
  final ColorScheme cs;
  final TextTheme tt;

  const _DeviceCard({required this.info, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth_connected, color: cs.primary),
                const SizedBox(width: 8),
                Text('已连接设备', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(info?.name ?? '—',
                style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            if (info != null) ...[
              const SizedBox(height: 4),
              Text('MTU: ${info!.mtu}',
                  style: tt.bodySmall?.copyWith(color: cs.outline)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Profile 验证卡片 ──

class _ProfileCard extends StatelessWidget {
  final bool available;
  final ColorScheme cs;
  final TextTheme tt;

  const _ProfileCard(
      {required this.available, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    final ok = available;
    return Card(
      color: ok ? cs.primaryContainer : cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.cancel,
              color: ok ? cs.primary : cs.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导航投屏 Profile',
                    style: tt.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ok
                        ? 'FFD1-FFD4 特征已就绪，支持 BLE 导航投屏'
                        : '设备缺少 FFD1-FFD4 特征，不支持 BLE 导航投屏',
                    style: tt.bodySmall?.copyWith(
                      color: ok ? cs.onPrimaryContainer : cs.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 投屏控制卡片 ──

class _ProjectionCard extends StatelessWidget {
  final NaviProjState state;
  final bool profileOk;
  final NaviProjectionNotifier notifier;
  final ColorScheme cs;
  final TextTheme tt;

  const _ProjectionCard({
    required this.state,
    required this.profileOk,
    required this.notifier,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final projecting = state == NaviProjState.projecting;
    final opening = state == NaviProjState.opening;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  projecting ? Icons.cast_connected : Icons.cast,
                  color: projecting ? cs.primary : cs.outline,
                ),
                const SizedBox(width: 8),
                Text('投屏控制', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            if (projecting || opening) ...[
              FilledButton.icon(
                onPressed: projecting ? () => notifier.stopProjection() : null,
                icon: projecting
                    ? const Icon(Icons.stop)
                    : const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                label: Text(projecting ? '停止投屏' : '握手中…'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: cs.error,
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: profileOk && state != NaviProjState.error
                    ? () => notifier.startProjection()
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(profileOk ? '开始投屏' : 'Profile 不可用'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: profileOk ? cs.primary : cs.outline,
                ),
              ),
              if (state == NaviProjState.error) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => notifier.startProjection(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ],
            if (!profileOk) ...[
              const SizedBox(height: 8),
              Text(
                '请确保对端固件已实现导航投屏 Profile\n(Service FFD0, 特征 FFD1-FFD4)',
                style: tt.bodySmall?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 状态详情卡片 ──

class _StatusCard extends StatelessWidget {
  final NaviProjectionNotifier notifier;
  final ColorScheme cs;
  final TextTheme tt;

  const _StatusCard({
    required this.notifier,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('状态详情', style: tt.titleSmall),
            const Divider(height: 16),
            _row('已发送帧', '${notifier.sentFrames}', tt),
            _row('已发送数据',
                '${(notifier.sentBytes / 1024).toStringAsFixed(1)} KB', tt),
            _row('投屏状态', notifier.isProjecting ? '运行中' : '待命中', tt),
            if (notifier.lastError != null) ...[
              const SizedBox(height: 4),
              Text(
                '错误: ${notifier.lastError}',
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodySmall),
          Text(value,
              style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
