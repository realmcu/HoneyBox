import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_demo_controller.dart';
import 'ws_demo_dialogs.dart';
import 'ws_device_pages.dart';
import 'ws_event_reminder_page.dart';
import 'ws_find_device_page.dart';
import 'ws_address_book_page.dart';
import 'ws_control_lab_page.dart';
import 'ws_take_photo_page.dart';
import 'ws_notify_remind_page.dart';
import 'ws_settings_app_widgets.dart';
import 'ws_settings_basic_pages.dart';
import 'ws_settings_catalog.dart';
import 'ws_settings_health_monitoring_page.dart';
import 'ws_settings_pages.dart';
import 'ws_settings_placeholder_page.dart';
import 'ws_settings_app_theme.dart';

/// Opens App-like settings as a full-screen route (功能 Tab 深链复用)。
void openWsSettingsHub(BuildContext context, WSDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => Theme(
          data: WsSettingsAppTheme.theme(Theme.of(ctx)),
          child: Scaffold(
            backgroundColor: WsSettingsAppTheme.background,
            appBar: AppBar(title: const Text('设备设置')),
            body: WsSettingsHomePage(controller: controller),
          ),
        ),
      ),
    ),
  );
}

/// 对齐 `WatchDetailFragment` 的设置主页（嵌入设置 Tab）。
class WsSettingsHomePage extends StatefulWidget {
  const WsSettingsHomePage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WsSettingsHomePage> createState() => _JwSettingsHomePageState();
}

class _JwSettingsHomePageState extends State<WsSettingsHomePage> {
  WSDemoController get controller => widget.controller;

  bool _deviceSupports(WsSettingsItem item) {
    final info = controller.functionInfo;
    if (info == null || item.requiredFunctions.isEmpty) return true;
    return item.requiredFunctions.any(info.supports);
  }

  var _syncingTime = false;

  Future<void> _confirmDisconnect() async {
    final ok = await WsDemoDialogs.showMessage(
      context,
      title: '断开连接',
      detail: '确认断开当前设备？',
      negativeText: '取消',
      positiveText: '断开',
    );
    if (ok != true || !mounted) return;
    await controller.disconnect();
  }

  Future<void> _confirmClearDeviceData() async {
    final ok = await WsDemoDialogs.showMessage(
      context,
      title: '提示',
      detail:
          '此操作会清除你手表中所有数据。如果手表在恢复出厂设置后未重启，需要充电才能激活。',
      negativeText: '取消',
      positiveText: '确定',
      barrierDismissible: false,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.clearDeviceData(confirmed: true);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('已发送清除指令，设备将关机/重启')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(describeWSDemoError(e))),
      );
    }
  }

  Future<void> _syncTimeNow() async {
    if (_syncingTime) return;
    setState(() => _syncingTime = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.syncTime();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('当前时间已同步到设备')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(describeWSDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _syncingTime = false);
    }
  }

  void _open(WsSettingsItem item) {
    final deviceUnsupported = !_deviceSupports(item);
    if (deviceUnsupported &&
        item.implStatus == WsSettingsImplStatus.sdkReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备不支持该功能。')),
      );
      return;
    }

    if (item.implStatus != WsSettingsImplStatus.sdkReady) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WsSettingsPlaceholderPage(
            title: item.title,
            status: item.implStatus,
            androidRef: item.androidRef,
            detail: item.subtitle,
          ),
        ),
      );
      return;
    }

    // 同步时间：点击即写入，无二级页。
    if (item.id == WsSettingsItemId.syncTime) {
      unawaited(_syncTimeNow());
      return;
    }

    // 清除数据：对齐 App 确认弹窗后直接下发 RESET。
    if (item.id == WsSettingsItemId.clearData) {
      unawaited(_confirmClearDeviceData());
      return;
    }

    final page = switch (item.id) {
      WsSettingsItemId.findDevice =>
        WsFindDevicePage(controller: controller),
      WsSettingsItemId.takePhoto =>
        WsTakePhotoPage(controller: controller),
      WsSettingsItemId.deviceControl =>
        WsControlLabPage(controller: controller),
      WsSettingsItemId.addressBook =>
        WsAddressBookPage(controller: controller),
      WsSettingsItemId.notifyRemind =>
        WsNotifyRemindPage(controller: controller),
      WsSettingsItemId.eventRemind =>
        WsEventReminderPage(controller: controller),
      WsSettingsItemId.alarm =>
        WSAlarmsSettingsPage(controller: controller),
      WsSettingsItemId.healthMonitoring =>
        WsHealthMonitoringPage(controller: controller),
      WsSettingsItemId.language =>
        WsLanguageSettingsPage(controller: controller),
      WsSettingsItemId.unitSettings =>
        WsUnitSettingsPage(controller: controller),
      WsSettingsItemId.screenDisplay =>
        WsScreenDisplayPage(controller: controller),
      WsSettingsItemId.userProfileGoals =>
        WSProfileGoalsPage(controller: controller),
      _ => null,
    };

    if (page == null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WsSettingsPlaceholderPage(
            title: item.title,
            status: WsSettingsImplStatus.sdkUnsupported,
            androidRef: item.androidRef,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final groups = jwSettingsCatalog();
        final device = controller.state.device;
        return Theme(
          data: WsSettingsAppTheme.theme(Theme.of(context)),
          child: Material(
            color: WsSettingsAppTheme.background,
            child: ListView(
              key: const Key('jw.demo.page.settings'),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _DeviceOverviewCard(
                  device: device,
                  batteryPercent: controller.batteryPercent,
                  onOpenDeviceInfo: () => openJwDeviceHub(context, controller),
                ),
                for (final group in groups) ...[
                  WsSettingsSectionHeader(group.title),
                  // 对齐 App：标题下每项独立圆角卡，首项也有 8dp marginTop。
                  for (final item in group.items)
                    WsSettingsRow(
                      item: item,
                      deviceUnsupported: !_deviceSupports(item),
                      marginTop: WsSettingsAppTheme.itemGap,
                      onTap: () => _open(item),
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    WsSettingsAppTheme.pagePaddingH,
                    20,
                    WsSettingsAppTheme.pagePaddingH,
                    8,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton(
                      key: const Key('jw.demo.settings.disconnect'),
                      style: FilledButton.styleFrom(
                        backgroundColor: WsSettingsAppTheme.positiveButton,
                        foregroundColor: WsSettingsAppTheme.positiveButtonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            WsSettingsAppTheme.itemRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () => unawaited(_confirmDisconnect()),
                      child: const Text('断开连接'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeviceOverviewCard extends StatelessWidget {
  const _DeviceOverviewCard({
    required this.device,
    required this.batteryPercent,
    required this.onOpenDeviceInfo,
  });

  final WSDeviceInfo? device;
  final int? batteryPercent;
  final VoidCallback onOpenDeviceInfo;

  @override
  Widget build(BuildContext context) {
    final name = device?.name ?? 'WS 设备';
    final mac = device?.deviceMac ?? '—';
    final battery = batteryPercent;
    return WsSettingsItemCard(
      marginTop: 12,
      child: InkWell(
        key: const Key('jw.demo.settings.device_overview'),
        onTap: onOpenDeviceInfo,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: WsSettingsIcons.image(
                  WsSettingsIcons.watchFace,
                  width: 44,
                  height: 44,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: WsSettingsAppTheme.itemTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(mac, style: WsSettingsAppTheme.itemValue),
                    if (battery != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '电量 $battery%',
                        style: WsSettingsAppTheme.itemValue.copyWith(
                          color: WsSettingsAppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              WsSettingsIcons.image(
                WsSettingsIcons.chevron,
                width: 8,
                height: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
