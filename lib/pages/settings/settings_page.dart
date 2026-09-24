import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ble_provider.dart';
import '../../providers/current_app_provider.dart';
import '../../services/app_settings.dart';
import '../../services/file_cache.dart';
import '../launcher/app_catalog.dart';
import '../shared/file_send_layout.dart';

/// 设置 — application preferences. Currently the local send-cache: a size cap
/// (adjustable 5–50 MB) and an entry into the cache-management list.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<int> _usage = Future.value(0);

  /// 正在清 GATT 缓存(见 [_onPurgeGattCache])。期间禁掉入口并显示 spinner ——
  /// 这一步要重新发现服务,连点两次会让两轮发现互相打断。
  bool _purging = false;

  @override
  void initState() {
    super.initState();
    _refreshUsage();
  }

  void _refreshUsage() {
    setState(() {
      _usage = ref.read(fileCacheProvider).totalSize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final currentApp = ref.watch(currentAppProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('存储',
                style: theme.textTheme.titleSmall?.copyWith(color: cs.primary)),
          ),
          _cacheLimitCard(theme, cs, settings),
          const SizedBox(height: 12),
          _manageCard(theme, cs),
          // 蓝牙组只给 eBadge:清 GATT 缓存要一条到设备的临时连接,而这一节讲的
          // 故障(固件新增服务后 App 读到旧服务表)也只在 eBadge 这条产品线上遇到过。
          if (currentApp == AppId.ebadge) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('蓝牙',
                  style:
                      theme.textTheme.titleSmall?.copyWith(color: cs.primary)),
            ),
            _gattCacheCard(theme, cs),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('调试',
                  style:
                      theme.textTheme.titleSmall?.copyWith(color: cs.primary)),
            ),
            _debugModeCard(theme, cs, settings),
          ],
        ],
      ),
    );
  }

  Widget _cacheLimitCard(
      ThemeData theme, ColorScheme cs, AppSettings settings) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sd_storage_outlined,
                    size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('本地缓存上限', style: theme.textTheme.titleMedium),
                ),
                Text('${settings.cacheLimitMB} MB',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            _CacheLimitSlider(
              value: settings.cacheLimitMB,
              onCommitted: (mb) async {
                ref.read(appSettingsProvider.notifier).setCacheLimitMB(mb);
                // Lowering the cap may put us over budget — prune immediately.
                await ref.read(fileCacheProvider).enforceLimit();
                if (mounted) _refreshUsage();
              },
            ),
            _usageRow(theme, cs, settings.cacheLimitMB),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _usageRow(ThemeData theme, ColorScheme cs, int limitMB) {
    return FutureBuilder<int>(
      future: _usage,
      builder: (context, snap) {
        final used = snap.data ?? 0;
        final limitBytes = limitMB * 1024 * 1024;
        final frac = limitBytes > 0 ? (used / limitBytes).clamp(0.0, 1.0) : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text('已用 ${formatFileSize(used)} / $limitMB MB',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        );
      },
    );
  }

  Widget _manageCard(ThemeData theme, ColorScheme cs) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: const Text('管理本地缓存'),
        subtitle: FutureBuilder<int>(
          future: _usage,
          builder: (context, snap) => Text(
            snap.hasData ? '当前已用 ${formatFileSize(snap.data!)}' : '查看并删除已缓存的文件',
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).pushNamed('/cache');
          _refreshUsage(); // deletions there change usage
        },
      ),
    );
  }

  /// 「清除服务缓存」卡片。
  ///
  /// 要解决的问题:Android 按设备地址把 GATT 服务表缓存在系统里,跨 App、跨重启
  /// 存活。设备固件新增服务后,`discoverServices()` 仍然交回旧表 —— 它「成功」了,
  /// 只是答的是昨天的实情。现象是某个能力凭空变成不支持(投屏的 FFC4/FFC5 就这么
  /// 消失过,而同一台设备在无缓存的电脑上枚举得一清二楚)。
  ///
  /// **副标题明写「不一定成功」**,这不是谦辞:底层是反射调
  /// `BluetoothGatt.refresh()`(Google 从未公开的方法),部分 ROM 直接忽略。不写清
  /// 的话,点完没变化的人只会以为是别的地方坏了,而真正的下一步(清系统蓝牙数据)
  /// 永远不会被想到。
  Widget _gattCacheCard(ThemeData theme, ColorScheme cs) {
    final connected = ref.watch(connectedDeviceProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.bluetooth_searching),
        title: const Text('清除服务缓存'),
        subtitle: Text(
          connected == null
              ? '需先连接设备。用于设备升级固件后 App 仍识别不到新功能的情况。'
              : '设备升级固件后若 App 仍提示不支持某功能(如投屏),点此重新读取'
                  '${connected.name} 的服务表。不一定成功 —— 部分机型会忽略该操作。',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: _purging
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        enabled: connected != null && !_purging,
        onTap: connected == null || _purging ? null : _onPurgeGattCache,
      ),
    );
  }

  /// 清缓存 + 重新发现服务。先确认,因为它会短暂打断与设备的通信。
  Future<void> _onPurgeGattCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除服务缓存？', textAlign: TextAlign.center),
        content: const Text(
          'App 将丢弃 Android 为这台设备缓存的服务表，并重新读取一次。\n\n'
          '期间与设备的通信会短暂中断，请勿在传输文件或投屏时操作。\n\n'
          '注意：部分机型不支持该操作，清除可能不生效。若清除后仍识别不到新功能，'
          '可到系统设置里清除「蓝牙」应用的数据，或先取消配对再重新连接。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _purging = true);
    final ok = await ref.read(bleManagerProvider).refreshServices();
    if (!mounted) return;
    setState(() => _purging = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '已重新读取服务表。若功能仍不可用，请断开后重新连接，'
              '或在系统设置里清除「蓝牙」应用数据'
          : '操作失败：设备可能已断开，或该机型不支持清除缓存'),
    ));
  }

  /// 「调试模式」开关卡片。打开后扫描列表首行注入虚拟 eBadge-debug 设备,
  /// 便于无实物调试 UI/交互;虚拟连接不会发送任何真实数据。
  Widget _debugModeCard(ThemeData theme, ColorScheme cs, AppSettings settings) {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: const Icon(Icons.bug_report_outlined),
        title: const Text('调试模式'),
        subtitle: Text(
          '扫描列表首行会出现虚拟设备 eBadge-debug,用于无实物调试 UI 及交互。'
          '虚拟连接不会发送任何真实数据。',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        value: settings.debugMode,
        onChanged: (v) =>
            ref.read(appSettingsProvider.notifier).setDebugMode(v),
      ),
    );
  }
}

/// Slider that reports its value continuously while dragging (for a live label)
/// but only commits — persisting + pruning — on release, avoiding a disk write
/// per drag tick.
class _CacheLimitSlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onCommitted;
  const _CacheLimitSlider({required this.value, required this.onCommitted});

  @override
  State<_CacheLimitSlider> createState() => _CacheLimitSliderState();
}

class _CacheLimitSliderState extends State<_CacheLimitSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final v = (_dragValue ?? widget.value.toDouble())
        .clamp(kMinCacheLimitMB.toDouble(), kMaxCacheLimitMB.toDouble());
    return Slider(
      value: v,
      min: kMinCacheLimitMB.toDouble(),
      max: kMaxCacheLimitMB.toDouble(),
      divisions: kMaxCacheLimitMB - kMinCacheLimitMB,
      label: '${v.round()} MB',
      onChanged: (nv) => setState(() => _dragValue = nv),
      onChangeEnd: (nv) {
        setState(() => _dragValue = null);
        widget.onCommitted(nv.round());
      },
    );
  }
}
