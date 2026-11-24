import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/app_strings.dart';
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
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(strings.settingsSectionStorage,
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
              child: Text(strings.settingsSectionBluetooth,
                  style:
                      theme.textTheme.titleSmall?.copyWith(color: cs.primary)),
            ),
            _gattCacheCard(theme, cs),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(strings.settingsSectionDebug,
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
                  child: Text(AppStrings.of(context).settingsCacheLimit,
                      style: theme.textTheme.titleMedium),
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
            Text(
                AppStrings.of(context)
                    .settingsUsedOf(formatFileSize(used), limitMB),
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
        title: Text(AppStrings.of(context).settingsManageCache),
        subtitle: FutureBuilder<int>(
          future: _usage,
          builder: (context, snap) => Text(
            snap.hasData
                ? AppStrings.of(context)
                    .settingsManageCacheUsed(formatFileSize(snap.data!))
                : AppStrings.of(context).settingsManageCacheHint,
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
        title: Text(AppStrings.of(context).settingsGattClear),
        subtitle: Text(
          connected == null
              ? AppStrings.of(context).settingsGattClearNoDevice
              : AppStrings.of(context).settingsGattClearWith(connected.name),
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
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.settingsGattClearDialogTitle,
            textAlign: TextAlign.center),
        content: Text(strings.settingsGattClearDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.clear),
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
      content: Text(
          ok ? strings.settingsGattClearDone : strings.settingsGattClearFailed),
    ));
  }

  /// 「调试模式」开关卡片。打开后扫描列表首行注入虚拟 eBadge-debug 设备,
  /// 便于无实物调试 UI/交互;虚拟连接不会发送任何真实数据。
  Widget _debugModeCard(ThemeData theme, ColorScheme cs, AppSettings settings) {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: const Icon(Icons.bug_report_outlined),
        title: Text(AppStrings.of(context).settingsDebugMode),
        subtitle: Text(
          AppStrings.of(context).settingsDebugModeBody,
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
