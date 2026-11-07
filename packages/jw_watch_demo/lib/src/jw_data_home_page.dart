import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_data_catalog.dart';
import 'jw_data_detail_page.dart';
import 'jw_data_mock.dart';
import 'jw_demo_controller.dart';
import 'jw_history_pages.dart';
import 'jw_history_sync_run_controller.dart';
import 'jw_history_sync_state.dart';
import 'jw_settings_app_widgets.dart';
import 'jw_settings_catalog.dart';

/// 数据 Tab 首页：轻量同步条 + 全量类型卡片（最近一条来自本地 DB）。
class JwDataHomePage extends StatefulWidget {
  const JwDataHomePage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JwDataHomePage> createState() => _JwDataHomePageState();
}

class _JwDataHomePageState extends State<JwDataHomePage> {
  late final JwHistorySyncRunController _sync;
  final Map<JwDataTypeId, String> _summaries = {};
  var _loadingCards = false;
  Object? _cardError;
  var _useMock = JwDataMock.enabledByDefault;

  JWDemoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _sync = JwHistorySyncRunController();
    _sync.addListener(_onSyncChanged);
    controller.addListener(_onControllerChanged);
    unawaited(_refreshCards());
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    controller.removeListener(_onControllerChanged);
    _sync.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    unawaited(_refreshCards());
  }

  void _onSyncChanged() {
    if (!mounted) return;
    setState(() {});
    if (_sync.state.phase == JwHistorySyncPhase.success) {
      unawaited(_refreshCards());
    }
  }

  bool _deviceSupports(JwDataTypeItem item) {
    final info = controller.state.functionInfo;
    if (info == null || item.requiredFunctions.isEmpty) return true;
    return item.requiredFunctions.any(info.supports);
  }

  Future<void> _refreshCards() async {
    setState(() {
      _loadingCards = true;
      _cardError = null;
    });
    try {
      final next = <JwDataTypeId, String>{};
      if (_useMock) {
        for (final item in jwDataCatalog()) {
          next[item.id] = JwDataMock.cardSummary(item.id);
        }
      } else {
        final session = controller.session;
        final scope = session?.historyScope;
        if (session == null || scope == null) {
          if (!mounted) return;
          setState(() {
            _summaries.clear();
            _loadingCards = false;
            _cardError = null;
          });
          return;
        }
        for (final item in jwDataCatalog()) {
          next[item.id] = await jwDataQueryCardSummary(
            store: session.historyStore,
            scope: scope,
            id: item.id,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _summaries
          ..clear()
          ..addAll(next);
        _loadingCards = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cardError = e;
        _loadingCards = false;
      });
    }
  }

  void _setUseMock(bool value) {
    if (_useMock == value) return;
    setState(() => _useMock = value);
    unawaited(_refreshCards());
  }

  Future<void> _startSync() async {
    final session = controller.session;
    if (session == null || !controller.state.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完成连接与登录')),
      );
      return;
    }
    try {
      await _sync.start(session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    }
  }

  void _openDetail(JwDataTypeItem item) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JwDataDetailPage(
            controller: controller,
            item: item,
            useMock: _useMock,
          ),
        ),
      ),
    );
  }

  String _syncStatusText(JwHistorySyncRunState state) {
    return switch (state.phase) {
      JwHistorySyncPhase.idle => '点击同步拉取设备健康历史',
      JwHistorySyncPhase.syncing => state.awaitingDevicePlan
          ? '同步中：等待设备计划…'
          : '同步中 ${state.receivedWire}/${state.totalWire}',
      JwHistorySyncPhase.success =>
        '同步完成 · 收到 ${state.receivedWire} 条',
      JwHistorySyncPhase.failed =>
        '同步失败：${state.failure?.message ?? '未知错误'}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final catalog = jwDataCatalog();
    final syncing = _sync.state.isActive;
    return Theme(
      data: JwSettingsAppTheme.theme(Theme.of(context)),
      child: ListView(
        key: const Key('jw.demo.page.data'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            '数据',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: JwSettingsAppTheme.title,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: JwSettingsAppTheme.card,
            borderRadius: BorderRadius.circular(JwSettingsAppTheme.itemRadius),
            child: SwitchListTile(
              key: const Key('jw.demo.data.mock_toggle'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text(
                '模拟数据',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: JwSettingsAppTheme.title,
                ),
              ),
              subtitle: Text(
                _useMock ? '当前按本地库查询形状注入预览数据' : '当前读取真实本地库',
                style: const TextStyle(
                  fontSize: 12,
                  color: JwSettingsAppTheme.subtitle,
                ),
              ),
              value: _useMock,
              onChanged: _setUseMock,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: JwSettingsAppTheme.card,
            borderRadius: BorderRadius.circular(JwSettingsAppTheme.itemRadius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '健康数据同步',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: JwSettingsAppTheme.title,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _useMock
                              ? '模拟模式下同步不会写入预览数据'
                              : _syncStatusText(_sync.state),
                          style: const TextStyle(
                            fontSize: 13,
                            color: JwSettingsAppTheme.subtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('jw.demo.data.sync_debug'),
                    onPressed: () => openJwHistoryHub(context, controller),
                    child: const Text('详情'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    key: const Key('jw.demo.data.sync_start'),
                    onPressed: (_useMock || syncing)
                        ? null
                        : () => unawaited(_startSync()),
                    style: FilledButton.styleFrom(
                      backgroundColor: JwSettingsAppTheme.positiveButton,
                      foregroundColor: JwSettingsAppTheme.positiveButtonText,
                      minimumSize: const Size(72, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          JwSettingsAppTheme.buttonRadius,
                        ),
                      ),
                    ),
                    child: Text(syncing ? '同步中' : '同步'),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingCards) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_cardError != null) ...[
            const SizedBox(height: 8),
            Text(
              describeJWDemoError(_cardError!),
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: catalog.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final item = catalog[index];
              final supported = _deviceSupports(item);
              final summary = _summaries[item.id] ?? '—';
              return _DataTypeCard(
                item: item,
                summary: summary,
                deviceUnsupported: !supported,
                onTap: () => _openDetail(item),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DataTypeCard extends StatelessWidget {
  const _DataTypeCard({
    required this.item,
    required this.summary,
    required this.deviceUnsupported,
    required this.onTap,
  });

  final JwDataTypeItem item;
  final String summary;
  final bool deviceUnsupported;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: JwSettingsAppTheme.card,
      borderRadius: BorderRadius.circular(JwSettingsAppTheme.itemRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('jw.demo.data.card.${item.id.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 22, color: JwSettingsAppTheme.title),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: JwSettingsAppTheme.title,
                      ),
                    ),
                  ),
                  if (deviceUnsupported)
                    const JwSettingsStatusChip(
                      JwSettingsImplStatus.sdkReady,
                      deviceUnsupported: true,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: summary == '暂无数据' || summary == '—'
                      ? JwSettingsAppTheme.muted
                      : JwSettingsAppTheme.subtitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
