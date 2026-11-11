import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_app_day_chart_bundle.dart';
import 'ws_data_catalog.dart';
import 'ws_data_detail_page.dart';
import 'ws_data_home_chart.dart';
import 'ws_data_home_icons.dart';
import 'ws_data_home_header.dart';
import 'ws_data_home_presentation.dart';
import 'ws_demo_controller.dart';
import 'ws_demo_time.dart';
import 'ws_history_sync_run_controller.dart';
import 'ws_history_sync_state.dart';
import 'ws_settings_app_widgets.dart';
import 'ws_settings_catalog.dart';
import 'ws_settings_app_theme.dart';
import 'compat/ws_demo_compat.dart';

const _kDataHomeIconSize = 40.0;

/// 图表列表错落（App `st_home_deep` / `st_home_low`），在 `#EDF0FA` 底上用中性灰 + 白 + 轻阴影分块。
abstract final class WsDataHomeCardColors {
  /// 偶数序（含第一条）：中性浅灰，与顶区白卡区分
  static const low = Color(0xFFF9F9F9);
  /// 奇数序：白卡
  static const deep = Color(0xFFFFFFFF);
  static const cardShadow = Color(0x14171C3C);
  static const cardElevation = 1.0;
}

/// 数据 Tab 首页：轻量同步条 + 图表模式卡片（今日小图 + 最近一条）。
class WsDataHomePage extends StatefulWidget {
  const WsDataHomePage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WsDataHomePage> createState() => _JwDataHomePageState();
}

class _JwDataHomePageState extends State<WsDataHomePage> {
  late final WsHistorySyncRunController _sync;
  final Map<WsDataTypeId, WsDataHomeCardData> _cards = {};
  var _loadingCards = false;
  Object? _cardError;
  WSTodayActivitySummary? _todaySummary;
  var _loadingToday = false;
  var _resettingMarkers = false;
  Future<void>? _todayRefreshInFlight;

  WSDemoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _sync = WsHistorySyncRunController();
    _sync.addListener(_onSyncChanged);
    controller.addListener(_onControllerChanged);
    unawaited(_refreshCards());
    unawaited(_refreshTodaySummary());
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
    unawaited(_refreshTodaySummary());
  }

  void _onSyncChanged() {
    if (!mounted) return;
    setState(() {});
    if (_sync.state.phase == WsHistorySyncPhase.success) {
      unawaited(_refreshCards());
      unawaited(_refreshTodaySummary());
    }
  }

  bool _todaySummarySupported() {
    final info = controller.functionInfo;
    if (info == null) return true;
    return info.supports(WSDeviceFunction.todayAdjust);
  }

  Future<void> _refreshTodaySummary() {
    final inFlight = _todayRefreshInFlight;
    if (inFlight != null) return inFlight;
    final run = _refreshTodaySummaryOnce();
    _todayRefreshInFlight = run;
    return run.whenComplete(() => _todayRefreshInFlight = null);
  }

  /// 直连 [WSWatchSession.today]，避免走 Controller 触发 notify → 死循环刷 0x60。
  Future<void> _refreshTodaySummaryOnce() async {
    final session = controller.session;
    if (session == null || !controller.state.isReady) {
      if (!mounted) return;
      setState(() {
        _todaySummary = null;
        _loadingToday = false;
      });
      return;
    }
    if (!_todaySummarySupported()) {
      if (!mounted) return;
      setState(() {
        _todaySummary = null;
        _loadingToday = false;
      });
      return;
    }
    setState(() => _loadingToday = true);
    try {
      final snapshot = await session.today.queryToday();
      if (!mounted) return;
      setState(() {
        _todaySummary = wsDemoTodaySummaryFromSnapshot(snapshot);
        _loadingToday = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingToday = false);
    }
  }

  bool _deviceSupports(WsDataTypeItem item) {
    final info = controller.functionInfo;
    if (info == null || item.requiredFunctions.isEmpty) return true;
    return item.requiredFunctions.any(info.supports);
  }

  Future<void> _refreshCards() async {
    setState(() {
      _loadingCards = true;
      _cardError = null;
    });
    try {
      final next = <WsDataTypeId, WsDataHomeCardData>{};
      final session = controller.session;
      final scope = session?.historyScope;
      if (session == null || scope == null) {
        if (!mounted) return;
        setState(() {
          _cards.clear();
          _loadingCards = false;
          _cardError = null;
        });
        return;
      }
      for (final item in jwDataCatalog()) {
        next[item.id] = await jwDataLoadHomeCard(
          store: session.historyStore,
          scope: scope,
          item: item,
        );
      }
      if (!mounted) return;
      setState(() {
        _cards
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
        SnackBar(content: Text(describeWSDemoError(e))),
      );
    }
  }

  Future<void> _resetSyncMarkers() async {
    final session = controller.session;
    if (session == null || !controller.state.isReady) return;
    if (_sync.state.isActive) return;
    setState(() => _resettingMarkers = true);
    try {
      await _sync.resetDeviceSyncMarkers(session);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置同步标记，可重新同步历史数据')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeWSDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _resettingMarkers = false);
    }
  }

  void _openDetail(WsDataTypeItem item) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WsDataDetailPage(
            controller: controller,
            item: item,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = jwDataCatalog();
    final sessionReady = controller.session != null && controller.state.isReady;
    return Theme(
      data: WsSettingsAppTheme.theme(Theme.of(context)),
      child: ListView(
        key: const Key('jw.demo.page.data'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            '数据',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: WsSettingsAppTheme.title,
            ),
          ),
          const SizedBox(height: 12),
          WsDataHomeHeader(
            syncState: _sync.state,
            summary: _todaySummary,
            loadingSummary: _loadingToday,
            todaySupported: _todaySummarySupported(),
            sessionReady: sessionReady,
            syncing: _sync.state.isActive,
            resettingMarkers: _resettingMarkers,
            onSync: _sync.state.isActive ? null : () => unawaited(_startSync()),
            onResetMarkers:
                _sync.state.isActive ? null : () => unawaited(_resetSyncMarkers()),
          ),
          if (_cardError != null) ...[
            const SizedBox(height: 8),
            Text(
              describeWSDemoError(_cardError!),
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < catalog.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _DataHomeChartCard(
              item: catalog[i],
              data: _cards[catalog[i].id],
              deviceUnsupported: !_deviceSupports(catalog[i]),
              stripedBackground: i.isOdd,
              onTap: () => _openDetail(catalog[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataHomeChartCard extends StatelessWidget {
  const _DataHomeChartCard({
    required this.item,
    required this.data,
    required this.deviceUnsupported,
    required this.stripedBackground,
    required this.onTap,
  });

  final WsDataTypeItem item;
  final WsDataHomeCardData? data;
  final bool deviceUnsupported;
  final bool stripedBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = jwDataDayStart(DateTime.now());
    final fallback = jwDataHomePresentationFallback(item.id);
    final presentation = deviceUnsupported
        ? fallback
        : (data?.presentation ?? fallback);
    final chartBundle = deviceUnsupported
        ? WsAppDayChartBundle.build(id: item.id, rows: const [], day: today)
        : (data?.bundle ??
            WsAppDayChartBundle.build(
              id: item.id,
              rows: const [],
              day: today,
            ));
    final cardBg = stripedBackground
        ? WsDataHomeCardColors.deep
        : WsDataHomeCardColors.low;
    final valueMuted =
        presentation.primaryValue == WsDataHomeCardPresentation.emptyToken;

    return Material(
      color: cardBg,
      elevation: WsDataHomeCardColors.cardElevation,
      shadowColor: WsDataHomeCardColors.cardShadow,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(WsSettingsAppTheme.itemRadius),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WsDataHomeIcons.image(
                    item.id,
                    width: _kDataHomeIconSize,
                    height: _kDataHomeIconSize,
                    fallback: item.icon,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: WsSettingsAppTheme.title,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (deviceUnsupported)
                              const WsSettingsStatusChip(
                                WsSettingsImplStatus.sdkReady,
                                deviceUnsupported: true,
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    presentation.primaryValue,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: valueMuted
                                          ? WsSettingsAppTheme.muted
                                          : WsSettingsAppTheme.title,
                                    ),
                                  ),
                                  if (presentation.primaryUnit != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      presentation.primaryUnit!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: WsSettingsAppTheme.subtitle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                        ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  presentation.subtitleLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: WsSettingsAppTheme.subtitle,
                                  ),
                                ),
                              ),
                              if (presentation.subtitleTrailing != null)
                                Text(
                                  presentation.subtitleTrailing!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: WsSettingsAppTheme.muted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WsDataHomeChart(bundle: chartBundle),
            ],
          ),
        ),
      ),
    );
  }
}
