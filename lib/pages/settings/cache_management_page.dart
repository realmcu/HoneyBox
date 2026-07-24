import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_settings.dart';
import '../../services/file_cache.dart';
import '../shared/cache_ui.dart';
import '../shared/file_send_layout.dart';

/// 本地缓存 — lists every cached send artifact (optionally filtered by kind),
/// with per-item and clear-all deletion. Total usage vs. the configured cap is
/// shown at the top.
class CacheManagementPage extends ConsumerStatefulWidget {
  const CacheManagementPage({super.key});

  @override
  ConsumerState<CacheManagementPage> createState() =>
      _CacheManagementPageState();
}

class _CacheManagementPageState extends ConsumerState<CacheManagementPage> {
  late Future<List<CacheEntry>> _future;
  int _filterIdx = 0; // index into _filters

  // Filter categories. Carousels are stored in the 视频 pool tagged
  // src=slideshow, so they're split out from plain 视频 by inspecting that
  // param rather than by CacheKind alone.
  final List<({String label, bool Function(CacheEntry) test})> _filters = [
    (label: '全部', test: (_) => true),
    (label: CacheKind.image.label, test: (e) => e.kind == CacheKind.image),
    (label: CacheKind.danmaku.label, test: (e) => e.kind == CacheKind.danmaku),
    (
      label: CacheKind.video.label,
      test: (e) => e.kind == CacheKind.video && e.params['src'] != 'slideshow',
    ),
    (
      label: '多图轮播',
      test: (e) => e.kind == CacheKind.video && e.params['src'] == 'slideshow',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(fileCacheProvider).list();
    if (mounted) setState(() {});
  }

  Future<void> _delete(CacheEntry e) async {
    await ref.read(fileCacheProvider).delete(e.file);
    _reload();
  }

  // Tapping a row opens a full preview sheet (still image / looping video); if
  // the user deletes from there, refresh the list to reflect it.
  Future<void> _openPreview(CacheEntry e) async {
    final deleted = await showCachePreview(context, e);
    if (deleted == true) _reload();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('将删除全部本地缓存文件，此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(fileCacheProvider).clear();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final limitMB = ref.watch(appSettingsProvider).cacheLimitMB;

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地缓存'),
        actions: [
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空',
          ),
        ],
      ),
      body: FutureBuilder<List<CacheEntry>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final used = all.fold<int>(0, (sum, e) => sum + e.size);
          final shown = all.where(_filters[_filterIdx].test).toList();

          return Column(
            children: [
              _usageHeader(theme, cs, used, limitMB, all.length),
              _filterRow(),
              const Divider(height: 1),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text('暂无缓存',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      )
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _tile(theme, cs, shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _usageHeader(
      ThemeData theme, ColorScheme cs, int used, int limitMB, int count) {
    final limitBytes = limitMB * 1024 * 1024;
    final frac = limitBytes > 0 ? (used / limitBytes).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('共 $count 项',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('已用 ${formatFileSize(used)} / $limitMB MB',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (int i = 0; i < _filters.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_filters[i].label),
                labelStyle: const TextStyle(fontSize: 12),
                selected: _filterIdx == i,
                onSelected: (_) => setState(() => _filterIdx = i),
                showCheckmark: false,
                backgroundColor: cs.surface,
                selectedColor: cs.primaryContainer,
                side: BorderSide(color: cs.outline),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(ThemeData theme, ColorScheme cs, CacheEntry e) {
    return ListTile(
      onTap: () => _openPreview(e),
      leading: CacheThumb(entry: e),
      title: Text('${e.kind.label} · ${cacheParamSummary(e)}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${cacheTimeLabel(e.time)} · ${formatFileSize(e.size)}',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: cs.error),
        tooltip: '删除',
        onPressed: () => _delete(e),
      ),
    );
  }
}
