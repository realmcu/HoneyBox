import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../i18n/app_strings.dart';
import '../../providers/ble_provider.dart';
import '../../providers/current_app_provider.dart';
import '../../services/jw/jw_scan_policy.dart';
import '../../services/app_settings.dart';
import '../../services/system_settings.dart';
import '../shared/app_drawer.dart';
import 'scan_device_order.dart';
import 'widgets/device_tile.dart';

/// Fallback device-name filter used when a caller doesn't specify one.
const String _kFallbackFilter = 'eBadge';

/// 调试模式下注入扫描列表的虚拟设备。id 前缀 `DEBUG:` 触发
/// [BleNotifier.connect] 的旁路(不调用真实 BLE 栈)。
class ScanPage extends ConsumerStatefulWidget {
  /// BLE-name prefix filter applied by default when the page opens.
  final String defaultDeviceFilter;

  /// AppBar title (e.g. "eBadge" / "Watch"). Used verbatim.
  final String appTitle;
  final bool acceptJwCandidates;
  final bool defaultOnlyNamed;
  final bool defaultOnlyConnectable;
  final bool defaultSortBySignal;
  final bool showBackButton;
  final ValueChanged<ScanDevice>? onDeviceSelected;
  final VoidCallback? onBrowseSavedHistory;

  /// Optional advertised service UUID used by the BLE stack to restrict scan
  /// results to devices belonging to this application.
  final String? requiredServiceUuid;

  const ScanPage({
    super.key,
    this.defaultDeviceFilter = _kFallbackFilter,
    this.appTitle = 'eBadge',
    this.acceptJwCandidates = false,
    this.defaultOnlyNamed = false,
    this.defaultOnlyConnectable = false,
    this.defaultSortBySignal = false,
    this.showBackButton = false,
    this.onDeviceSelected,
    this.onBrowseSavedHistory,
    this.requiredServiceUuid,
  });

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TextEditingController _filterCtrl =
      TextEditingController(text: widget.defaultDeviceFilter);
  late String _filter = widget.defaultDeviceFilter;
  late bool _onlyConnectable = widget.defaultOnlyConnectable;
  late bool _onlyNamed = widget.defaultOnlyNamed;
  late bool _sortBySignal = widget.defaultSortBySignal;
  bool _filterEdited = false;
  String? _connectingId;
  bool _locationOff = false;
  late BleNotifier _bleNotifier;

  // Polls the OS location-service state so we can react (stop/resume scanning)
  // even when it's toggled from quick-settings without leaving the app.
  Timer? _locationPoll;
  // Drives the short left-right shake of the "location off" banner when the
  // user tries to scan while location is disabled.
  late final AnimationController _shakeCtl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bleNotifier = ref.read(bleNotifierProvider.notifier);
    _filterCtrl.addListener(() {
      if (_filter != _filterCtrl.text) {
        setState(() {
          _filter = _filterCtrl.text;
          _filterEdited = true;
        });
      }
    });
    _shakeCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Reconcile scanning with the location-service state up front, then keep
    // watching it while this page is alive.
    Future.microtask(() async {
      await _checkLocationService();
      if (mounted && !_locationOff) {
        _bleNotifier.startScan(serviceUuid: widget.requiredServiceUuid);
      }
    });
    _locationPoll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkLocationService(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationPoll?.cancel();
    _shakeCtl.dispose();
    _filterCtrl.dispose();
    // Publish scan state after consumers finish unmounting. A synchronous
    // notifier update here can rebuild an already defunct sibling element.
    Future.microtask(() {
      if (_bleNotifier.mounted) _bleNotifier.stopScan();
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check immediately when returning to the app (e.g. from the location
    // settings screen). _checkLocationService() itself stops or resumes the
    // scan on the on→off / off→on transitions.
    if (state == AppLifecycleState.resumed) {
      _checkLocationService();
    }
  }

  /// Query the OS location-services (GPS) state. BLE scanning on Android needs
  /// it on, so this drives the top-of-list reminder banner *and* the scan:
  /// turning location off stops scanning; turning it back on resumes it
  /// immediately.
  Future<void> _checkLocationService() async {
    // Location-services gating is an Android BLE-scan requirement only. On
    // Windows/other desktops there is no such coupling, so never let a
    // location-off state block scanning there.
    if (!Platform.isAndroid) {
      if (_locationOff) setState(() => _locationOff = false);
      return;
    }
    final status = await Permission.location.serviceStatus;
    if (!mounted) return;
    final off = status == ServiceStatus.disabled;
    if (off == _locationOff) return; // no change since last check
    setState(() => _locationOff = off);
    if (off) {
      _bleNotifier.stopScan();
    } else {
      _bleNotifier.startScan(serviceUuid: widget.requiredServiceUuid);
    }
  }

  void _startScan() {
    // Location off → don't scan; nudge the user with a shake of the banner.
    if (_locationOff) {
      _shakeBanner();
      return;
    }
    _bleNotifier.startScan(serviceUuid: widget.requiredServiceUuid);
  }

  void _shakeBanner() => _shakeCtl.forward(from: 0);

  Future<void> _restartScan() async {
    await _checkLocationService();
    // Location off → skip the scan (and nudge the banner) but still resolve so
    // the pull-to-refresh spinner retracts.
    if (_locationOff) {
      _shakeBanner();
    } else {
      await _bleNotifier.startScan(serviceUuid: widget.requiredServiceUuid);
    }
    // Keep the pull-to-refresh spinner up briefly so the gesture feels alive;
    // scanning itself continues in the background afterwards.
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  void _onConnect(ScanDevice device) {
    if (widget.onDeviceSelected != null) {
      _bleNotifier.stopScan();
      widget.onDeviceSelected!(device);
      return;
    }
    setState(() => _connectingId = device.deviceId);
    ref
        .read(bleNotifierProvider.notifier)
        .connect(device.deviceId, device.name,
            allowJw: widget.acceptJwCandidates,
            ownerApp: ref.read(currentAppProvider)?.name)
        .then((success) {
      if (!mounted) return;
      // On success the root gate swaps to the device page automatically once
      // `connectedDeviceProvider` updates — no navigation needed here.
      if (!success) {
        setState(() => _connectingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).scanConnectFailed)),
        );
      }
    });
  }

  List<ScanDevice> _applyFilter(List<ScanDevice> all) {
    final q = _filter.trim().toLowerCase();
    final filtered = all.where((d) {
      return JwScanPolicy.matches(
          query: q,
          isDefaultWatchFilter: widget.acceptJwCandidates &&
              !_filterEdited &&
              widget.defaultDeviceFilter == 'Watch',
          device: d,
          onlyNamed: _onlyNamed,
          onlyConnectable: _onlyConnectable);
    }).toList();
    return _sortBySignal ? sortedScanDevicesBySignal(filtered) : filtered;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bleState = ref.watch(bleNotifierProvider);
    final all = ref.watch(scannedDevicesProvider);
    // 调试模式:注入当前应用的虚拟设备,让它也走 _applyFilter,
    // 语义上和真实设备一致(输入不匹配的过滤词一并被隐藏)。
    final debugOn = ref.watch(appSettingsProvider).debugMode;
    final debugDevice = ScanDevice(
      deviceId: '$kDebugDeviceIdPrefix${widget.appTitle.toLowerCase()}-debug',
      name: '${widget.appTitle}-debug',
      rssi: -42,
      connectable: true,
      debug: true,
    );
    final base = debugOn ? <ScanDevice>[debugDevice, ...all] : all;
    final devices = _applyFilter(base);
    final scanning = bleState == BleState.scanning;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBack = widget.showBackButton && canPop;

    return Scaffold(
      drawer: showBack ? null : const AppDrawer(),
      // Let a rightward swipe from the left half of the screen open the drawer.
      drawerEdgeDragWidth:
          showBack ? 0 : MediaQuery.sizeOf(context).width * 0.5,
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        // 两行标题:应用名 + 页面用途。单行 'Watch · Scan devices' 在英文下会被
        // 右侧三个操作按钮挤成 'Wat…'。
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleMedium?.copyWith(color: cs.onPrimary)),
            Text(AppStrings.of(context).scanSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall
                    ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.85))),
          ],
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          // 「已保存历史」收进溢出菜单:它是低频操作,而写成文字按钮时会把标题挤成
          // 'Wat…'(英文下尤其明显)。
          if (widget.onBrowseSavedHistory != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.onPrimary),
              tooltip: AppStrings.of(context).scanSavedHistory,
              onSelected: (_) => widget.onBrowseSavedHistory!(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'history',
                  child: Text(AppStrings.of(context).scanSavedHistory),
                ),
              ],
            ),
          if (scanning)
            TextButton.icon(
              onPressed: _bleNotifier.stopScan,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(AppStrings.of(context).stop),
              style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
            )
          else
            TextButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(AppStrings.of(context).scanScan),
              style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(cs, tt, all.length, devices.length, scanning),
          if (_locationOff) _buildLocationBanner(cs, tt),
          _buildFilterChips(cs),
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
                          key: ValueKey(device.deviceId),
                          deviceId: device.deviceId,
                          manufacturerData: device.manufacturerData,
                          name: device.name,
                          rssi: device.rssi,
                          connectable: device.connectable,
                          debug: device.debug,
                          actionLabel: widget.onDeviceSelected == null
                              ? AppStrings.of(context).scanConnect
                              : AppStrings.of(context).scanSelect,
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

  // Blue header: the filter input with the scanned-device count sitting to its
  // right, all on a single row.
  Widget _buildSearchBar(
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
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _filterCtrl,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.filter_alt_outlined,
                      size: 20, color: cs.onSurfaceVariant),
                  hintText: AppStrings.of(context).scanFilterHint,
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
            ),
            const SizedBox(width: 12),
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
            // Fixed width + tabular figures so the count doesn't reflow (and
            // jiggle the input's right edge) as the digit count changes.
            SizedBox(
              width: 60,
              child: Text(
                '$shown / $total',
                textAlign: TextAlign.end,
                style: tt.labelMedium?.copyWith(
                  color: cs.onPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter toggles moved out of the blue header to the top of the results
  // list — compact, large-radius pills on the page background.
  Widget _buildFilterChips(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.defaultDeviceFilter.isNotEmpty)
              _filterChip(
                cs,
                label: widget.appTitle,
                selected: _filter.trim() == widget.defaultDeviceFilter,
                onSelected: (sel) =>
                    _filterCtrl.text = sel ? widget.defaultDeviceFilter : '',
              ),
            _filterChip(
              cs,
              label: AppStrings.of(context).scanOnlyConnectable,
              selected: _onlyConnectable,
              onSelected: (sel) => setState(() => _onlyConnectable = sel),
            ),
            if (widget.defaultOnlyNamed)
              _filterChip(
                cs,
                label: AppStrings.of(context).scanOnlyNamed,
                selected: _onlyNamed,
                onSelected: (sel) => setState(() => _onlyNamed = sel),
              ),
            if (widget.defaultSortBySignal)
              _filterChip(
                cs,
                label: AppStrings.of(context).scanSortBySignal,
                selected: _sortBySignal,
                onSelected: (sel) => setState(() => _sortBySignal = sel),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    ColorScheme cs, {
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 12),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: cs.surface,
      selectedColor: cs.primaryContainer,
      side: BorderSide(color: cs.outline),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            // Shake the icon + text together, but not the bar itself — the red
            // background stays put so no white shows at the edges. The 9px
            // swing stays within the 16px left padding, so nothing spills out.
            Expanded(
              child: AnimatedBuilder(
                animation: _shakeCtl,
                builder: (context, child) {
                  // Decaying left-right oscillation that settles back.
                  final t = _shakeCtl.value;
                  final dx = math.sin(t * math.pi * 8) * 9 * (1 - t);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: cs.onError, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.of(context).scanLocationOff,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(color: cs.onError),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _bannerAction(cs, AppStrings.of(context).open,
                SystemSettings.openLocationSettings),
            _bannerAction(
                cs, AppStrings.of(context).scanWhy, _showLocationInfo),
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
        title:
            Text(AppStrings.of(ctx).scanWhyTitle, textAlign: TextAlign.center),
        content: Text(AppStrings.of(ctx).scanWhyBody),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                SystemSettings.openLocationSettings();
              },
              child: Text(AppStrings.of(ctx).scanTurnOn),
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
                        Text(
                            AppStrings.of(context)
                                .scanSearching(widget.appTitle),
                            style: tt.bodyLarge),
                        const SizedBox(height: 12),
                        Text(AppStrings.of(context).scanPullToRescan,
                            style: tt.bodySmall),
                      ]
                    : [
                        Icon(Icons.bluetooth_disabled,
                            size: 64, color: cs.outline),
                        const SizedBox(height: 16),
                        Text(AppStrings.of(context).scanNoDevices,
                            style: tt.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _filter.trim().isEmpty
                              ? AppStrings.of(context).scanEnsureOn
                              : AppStrings.of(context).scanNoMatch(_filter),
                          style: tt.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _startScan,
                          icon: const Icon(Icons.refresh),
                          label: Text(AppStrings.of(context).scanRescan),
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
