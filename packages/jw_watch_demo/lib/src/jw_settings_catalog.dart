import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_settings_api_sheet.dart';
import 'jw_settings_app_theme.dart';

/// Demo 设置项实现状态（与设备能力无关）。
enum JwSettingsImplStatus {
  /// SDK 已有公开 API，可进二级页操作。
  sdkReady,

  /// SDK 尚未实现；UI 先占位。
  sdkUnsupported,

  /// 本轮明确不做（表盘 / OTA 等）。
  deferredThisSprint,
}

enum JwSettingsGroupId {
  shortcuts,
  settings,
  other,
}

enum JwSettingsItemId {
  findDevice,
  takePhoto,
  deviceControl,
  telephone,
  alarm,
  notifyRemind,
  eventRemind,
  healthMonitoring,
  doNotDisturb,
  language,
  unitSettings,
  screenDisplay,
  syncTime,
  userProfileGoals,
  watchFace,
  clearData,
  firmwareUpdate,
  disconnect,
}

final class JwSettingsItem {
  const JwSettingsItem({
    required this.id,
    required this.group,
    required this.title,
    required this.implStatus,
    this.icon = Icons.settings_outlined,
    this.iconAsset,
    this.subtitle,
    this.androidRef,
    this.apiCode,
    this.requiredFunctions = const [],
    this.ukOnly = true,
  });

  final JwSettingsItemId id;
  final JwSettingsGroupId group;
  final String title;
  final String? subtitle;
  final JwSettingsImplStatus implStatus;
  final IconData icon;

  /// App 复制过来的 png（`JwSettingsIcons.*`）；优先于 [icon]。
  final String? iconAsset;
  final String? androidRef;

  /// 非空时，点击设置行标题弹出公开 API sheet。
  final String? apiCode;
  final List<JWDeviceFunction> requiredFunctions;

  /// 仅 UK/JW 路径；false 表示 App 里可能偏 MY，Demo 仍展示但标注来源。
  final bool ukOnly;
}

final class JwSettingsGroup {
  const JwSettingsGroup({
    required this.id,
    required this.title,
    required this.items,
  });

  final JwSettingsGroupId id;
  final String title;
  final List<JwSettingsItem> items;
}

/// 对齐 `WatchDetailFragment` 信息架构（UK/JW）。
List<JwSettingsGroup> jwSettingsCatalog() => const [
      JwSettingsGroup(
        id: JwSettingsGroupId.shortcuts,
        title: '常用功能',
        items: [
          JwSettingsItem(
            id: JwSettingsItemId.findDevice,
            group: JwSettingsGroupId.shortcuts,
            title: '查找设备',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.vibration,
            iconAsset: JwSettingsIcons.findDevice,
            androidRef: 'FindDeviceActivity',
            apiCode: JwSettingsApiExamples.findDevice,
            requiredFunctions: [JWDeviceFunction.findDevice],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.takePhoto,
            group: JwSettingsGroupId.shortcuts,
            title: '摇摇拍照',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.camera_alt_outlined,
            iconAsset: JwSettingsIcons.takePhoto,
            androidRef: 'TakePhotoActivity',
            apiCode: JwSettingsApiExamples.takePhoto,
            requiredFunctions: [JWDeviceFunction.cameraControl],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.deviceControl,
            group: JwSettingsGroupId.shortcuts,
            title: '设备控制',
            subtitle: '查找手机、音乐、天气',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.phone_android_outlined,
            androidRef: 'MainApplication / 控制监听',
            apiCode: JwSettingsApiExamples.controlLab,
            requiredFunctions: [
              JWDeviceFunction.findPhone,
              JWDeviceFunction.musicControl,
            ],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.telephone,
            group: JwSettingsGroupId.shortcuts,
            title: '电话功能',
            implStatus: JwSettingsImplStatus.sdkUnsupported,
            icon: Icons.call_outlined,
            iconAsset: JwSettingsIcons.telephone,
            androidRef: 'TelephoneFunctionActivity',
          ),
          JwSettingsItem(
            id: JwSettingsItemId.alarm,
            group: JwSettingsGroupId.shortcuts,
            title: '闹钟',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.alarm_outlined,
            iconAsset: JwSettingsIcons.alarm,
            androidRef: 'ClockSettingActivity',
            apiCode: JwSettingsApiExamples.alarm,
            // 设备只会有一种闹钟协议；标准 / 标签由 SDK 按能力自动选择。
            requiredFunctions: [
              JWDeviceFunction.alarm,
              JWDeviceFunction.alarm2,
            ],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.notifyRemind,
            group: JwSettingsGroupId.shortcuts,
            title: '消息提醒',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.notifications_outlined,
            iconAsset: JwSettingsIcons.notifyRemind,
            androidRef: 'NotifyRemindSettingActivity',
            apiCode: JwSettingsApiExamples.notifyRemind,
            requiredFunctions: [JWDeviceFunction.notifyReminder],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.eventRemind,
            group: JwSettingsGroupId.shortcuts,
            title: '事件提醒',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.event_note_outlined,
            iconAsset: JwSettingsIcons.eventRemind,
            androidRef: 'EventReminderActivity',
            apiCode: JwSettingsApiExamples.eventRemind,
            // 入口对齐 App：久坐 /（Demo 并入）勿扰；任一能力即可进入。
            requiredFunctions: [
              JWDeviceFunction.longSitReminder,
              JWDeviceFunction.disturb,
            ],
          ),
        ],
      ),
      JwSettingsGroup(
        id: JwSettingsGroupId.settings,
        title: '设置',
        items: [
          JwSettingsItem(
            id: JwSettingsItemId.healthMonitoring,
            group: JwSettingsGroupId.settings,
            title: '健康与监测',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.monitor_heart_outlined,
            iconAsset: JwSettingsIcons.healthMonitoring,
          ),
          JwSettingsItem(
            id: JwSettingsItemId.language,
            group: JwSettingsGroupId.settings,
            title: '设备语言',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.language_outlined,
            iconAsset: JwSettingsIcons.language,
            androidRef: 'DeviceLanguageSettingsActivity',
            apiCode: JwSettingsApiExamples.language,
            requiredFunctions: [JWDeviceFunction.multiLanguage],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.unitSettings,
            group: JwSettingsGroupId.settings,
            title: '单位设置',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.straighten_outlined,
            iconAsset: JwSettingsIcons.unitSettings,
            androidRef: 'UnitSettingActivity',
            apiCode: JwSettingsApiExamples.unitSystem,
          ),
          JwSettingsItem(
            id: JwSettingsItemId.screenDisplay,
            group: JwSettingsGroupId.settings,
            title: '屏幕与显示',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.brightness_medium_outlined,
            iconAsset: JwSettingsIcons.screenDisplay,
            androidRef: 'ScreenDisplayActivity',
            apiCode: JwSettingsApiExamples.screenDisplay,
            requiredFunctions: [JWDeviceFunction.lightDuration],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.syncTime,
            group: JwSettingsGroupId.settings,
            title: '同步时间',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.update_outlined,
            iconAsset: JwSettingsIcons.syncTime,
            apiCode: JwSettingsApiExamples.syncTime,
          ),
          JwSettingsItem(
            id: JwSettingsItemId.userProfileGoals,
            group: JwSettingsGroupId.settings,
            title: '用户资料与目标',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.person_outline,
            iconAsset: JwSettingsIcons.userProfile,
            apiCode: JwSettingsApiExamples.userProfileGoals,
          ),
        ],
      ),
      JwSettingsGroup(
        id: JwSettingsGroupId.other,
        title: '其他',
        items: [
          JwSettingsItem(
            id: JwSettingsItemId.watchFace,
            group: JwSettingsGroupId.other,
            title: '表盘',
            implStatus: JwSettingsImplStatus.deferredThisSprint,
            icon: Icons.watch_outlined,
            iconAsset: JwSettingsIcons.watchFace,
            androidRef: 'UKWatchFaceActivity',
            requiredFunctions: [JWDeviceFunction.customUi],
          ),
          JwSettingsItem(
            id: JwSettingsItemId.clearData,
            group: JwSettingsGroupId.other,
            title: '清除数据',
            implStatus: JwSettingsImplStatus.sdkReady,
            icon: Icons.delete_outline,
            iconAsset: JwSettingsIcons.clearData,
            androidRef: 'WatchDetailFragment.showResetDeviceDialog',
            apiCode: JwSettingsApiExamples.clearDeviceData,
          ),
          JwSettingsItem(
            id: JwSettingsItemId.firmwareUpdate,
            group: JwSettingsGroupId.other,
            title: '固件升级',
            implStatus: JwSettingsImplStatus.deferredThisSprint,
            icon: Icons.system_update_alt_outlined,
            iconAsset: JwSettingsIcons.firmwareUpdate,
            androidRef: 'UpgradeActivity',
            requiredFunctions: [JWDeviceFunction.ota],
          ),
          // 断开连接：主页底部主题色大按钮，不进列表卡片。
        ],
      ),
    ];

/// 仅非「可用」状态需要展示标签；`sdkReady` 返回 null。
String? jwSettingsImplStatusLabel(JwSettingsImplStatus status) =>
    switch (status) {
      JwSettingsImplStatus.sdkReady => null,
      JwSettingsImplStatus.sdkUnsupported => 'SDK 未支持',
      JwSettingsImplStatus.deferredThisSprint => '本轮不实现',
    };
