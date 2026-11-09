import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_demo_dialogs.dart';
import 'jw_device_pages.dart';
import 'jw_event_reminder_page.dart';
import 'jw_find_device_page.dart';
import 'jw_control_lab_page.dart';
import 'jw_take_photo_page.dart';
import 'jw_notify_remind_page.dart';
import 'jw_settings_app_widgets.dart';
import 'jw_settings_basic_pages.dart';
import 'jw_settings_catalog.dart';
import 'jw_settings_health_monitoring_page.dart';
import 'jw_settings_pages.dart';
import 'jw_settings_placeholder_page.dart';

/// Opens App-like settings as a full-screen route (功能 Tab 深链复用)。
void openJwSettingsHub(BuildContext context, JWDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => Theme(
          data: JwSettingsAppTheme.theme(Theme.of(ctx)),
          child: Scaffold(
            backgroundColor: JwSettingsAppTheme.background,
            appBar: AppBar(title: const Text('设备设置')),
            body: JwSettingsHomePage(controller: controller),
          ),
        ),
      ),
    ),
  );
}

/// 对齐 `WatchDetailFragment` 的设置主页（嵌入设置 Tab）。
class JwSettingsHomePage extends StatefulWidget {
  const JwSettingsHomePage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JwSettingsHomePage> createState() => _JwSettingsHomePageState();
}

class _JwSettingsHomePageState extends State<JwSettingsHomePage> {
  JWDemoController get controller => widget.controller;

  bool _deviceSupports(JwSettingsItem item) {
    final info = controller.state.functionInfo;
    if (info == null || item.requiredFunctions.isEmpty) return true;
    return item.requiredFunctions.any(info.supports);
  }

  var _syncingTime = false;

  Future<void> _confirmDisconnect() async {
    final ok = await JwDemoDialogs.showMessage(
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
    final ok = await JwDemoDialogs.showMessage(
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
        SnackBar(content: Text(describeJWDemoError(e))),
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
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _syncingTime = false);
    }
  }

  void _open(JwSettingsItem item) {
    final deviceUnsupported = !_deviceSupports(item);
    if (deviceUnsupported &&
        item.implStatus == JwSettingsImplStatus.sdkReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备不支持该功能。')),
      );
      return;
    }

    if (item.implStatus != JwSettingsImplStatus.sdkReady) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JwSettingsPlaceholderPage(
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
    if (item.id == JwSettingsItemId.syncTime) {
      unawaited(_syncTimeNow());
      return;
    }

    // 清除数据：对齐 App 确认弹窗后直接下发 RESET。
    if (item.id == JwSettingsItemId.clearData) {
      unawaited(_confirmClearDeviceData());
      return;
    }

    final page = switch (item.id) {
      JwSettingsItemId.findDevice =>
        JwFindDevicePage(controller: controller),
      JwSettingsItemId.takePhoto =>
        JwTakePhotoPage(controller: controller),
      JwSettingsItemId.deviceControl =>
        JwControlLabPage(controller: controller),
      JwSettingsItemId.notifyRemind =>
        JwNotifyRemindPage(controller: controller),
      JwSettingsItemId.eventRemind =>
        JwEventReminderPage(controller: controller),
      JwSettingsItemId.alarm =>
        JWAlarmsSettingsPage(controller: controller),
      JwSettingsItemId.healthMonitoring =>
        JwHealthMonitoringPage(controller: controller),
      JwSettingsItemId.language =>
        JwLanguageSettingsPage(controller: controller),
      JwSettingsItemId.unitSettings =>
        JwUnitSettingsPage(controller: controller),
      JwSettingsItemId.screenDisplay =>
        JwScreenDisplayPage(controller: controller),
      JwSettingsItemId.userProfileGoals =>
        JWProfileGoalsPage(controller: controller),
      _ => null,
    };

    if (page == null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JwSettingsPlaceholderPage(
            title: item.title,
            status: JwSettingsImplStatus.sdkUnsupported,
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
          data: JwSettingsAppTheme.theme(Theme.of(context)),
          child: Material(
            color: JwSettingsAppTheme.background,
            child: ListView(
              key: const Key('jw.demo.page.settings'),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _DeviceOverviewCard(
                  device: device,
                  onOpenDeviceInfo: () => openJwDeviceHub(context, controller),
                ),
                for (final group in groups) ...[
                  JwSettingsSectionHeader(group.title),
                  // 对齐 App：标题下每项独立圆角卡，首项也有 8dp marginTop。
                  for (final item in group.items)
                    JwSettingsRow(
                      item: item,
                      deviceUnsupported: !_deviceSupports(item),
                      marginTop: JwSettingsAppTheme.itemGap,
                      onTap: () => _open(item),
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    JwSettingsAppTheme.pagePaddingH,
                    20,
                    JwSettingsAppTheme.pagePaddingH,
                    8,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton(
                      key: const Key('jw.demo.settings.disconnect'),
                      style: FilledButton.styleFrom(
                        backgroundColor: JwSettingsAppTheme.positiveButton,
                        foregroundColor: JwSettingsAppTheme.positiveButtonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            JwSettingsAppTheme.itemRadius,
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
    required this.onOpenDeviceInfo,
  });

  final JWDeviceInfo? device;
  final VoidCallback onOpenDeviceInfo;

  @override
  Widget build(BuildContext context) {
    final name = device?.name ?? 'JW 设备';
    final mac = device?.deviceMac ?? '—';
    final firmware = device?.firmware;
    final battery = device?.battery;
    return JwSettingsItemCard(
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
                child: JwSettingsIcons.image(
                  JwSettingsIcons.watchFace,
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
                      style: JwSettingsAppTheme.itemTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(mac, style: JwSettingsAppTheme.itemValue),
                    if (firmware != null || battery != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (firmware != null) '固件 $firmware',
                          if (battery != null) '电量 $battery%',
                        ].join(' · '),
                        style: JwSettingsAppTheme.itemValue.copyWith(
                          color: JwSettingsAppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              JwSettingsIcons.image(
                JwSettingsIcons.chevron,
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
