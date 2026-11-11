import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_settings_api_sheet.dart';
import 'ws_settings_app_theme.dart';
import 'compat/ws_demo_compat.dart';

/// Demo 设置项实现状态（与设备能力无关）。
enum WsSettingsImplStatus {
  /// SDK 已有公开 API，可进二级页操作。
  sdkReady,

  /// SDK 尚未实现；UI 先占位。
  sdkUnsupported,

  /// 本轮明确不做（表盘 / OTA 等）。
  deferredThisSprint,
}

enum WsSettingsGroupId {
  shortcuts,
  settings,
  other,
}

enum WsSettingsItemId {
  findDevice,
  takePhoto,
  deviceControl,
  addressBook,
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

final class WsSettingsItem {
  const WsSettingsItem({
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

  final WsSettingsItemId id;
  final WsSettingsGroupId group;
  final String title;
  final String? subtitle;
  final WsSettingsImplStatus implStatus;
  final IconData icon;

  /// App 复制过来的 png（`WsSettingsIcons.*`）；优先于 [icon]。
  final String? iconAsset;
  final String? androidRef;

  /// 非空时，点击设置行标题弹出公开 API sheet。
  final String? apiCode;
  final List<WSDeviceFunction> requiredFunctions;

  /// 仅 UK/JW 路径；false 表示 App 里可能偏 MY，Demo 仍展示但标注来源。
  final bool ukOnly;
}

final class WsSettingsGroup {
  const WsSettingsGroup({
    required this.id,
    required this.title,
    required this.items,
  });

  final WsSettingsGroupId id;
  final String title;
  final List<WsSettingsItem> items;
}

/// 对齐 `WatchDetailFragment` 信息架构（UK/JW）。
List<WsSettingsGroup> jwSettingsCatalog() => const [
      WsSettingsGroup(
        id: WsSettingsGroupId.shortcuts,
        title: '常用功能',
        items: [
          WsSettingsItem(
            id: WsSettingsItemId.findDevice,
            group: WsSettingsGroupId.shortcuts,
            title: '查找设备',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.vibration,
            iconAsset: WsSettingsIcons.findDevice,
            androidRef: 'FindDeviceActivity',
            apiCode: WsSettingsApiExamples.findDevice,
            requiredFunctions: [WSDeviceFunction.findDevice],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.takePhoto,
            group: WsSettingsGroupId.shortcuts,
            title: '遥控拍照',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.camera_alt_outlined,
            iconAsset: WsSettingsIcons.takePhoto,
            androidRef: 'TakePhotoActivity',
            apiCode: WsSettingsApiExamples.takePhoto,
            requiredFunctions: [WSDeviceFunction.cameraControl],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.deviceControl,
            group: WsSettingsGroupId.shortcuts,
            title: '设备控制',
            subtitle: '查找手机、音乐、天气',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.phone_android_outlined,
            androidRef: 'MainApplication / 控制监听',
            apiCode: WsSettingsApiExamples.controlLab,
            requiredFunctions: [
              WSDeviceFunction.findPhone,
              WSDeviceFunction.musicControl,
            ],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.addressBook,
            group: WsSettingsGroupId.shortcuts,
            title: '通讯录',
            subtitle: '模拟联系人同步到手表',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.contacts_outlined,
            iconAsset: WsSettingsIcons.telephone,
            androidRef: 'AddressBookActivity',
            apiCode: WsSettingsApiExamples.addressBook,
            requiredFunctions: [WSDeviceFunction.addressBook],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.alarm,
            group: WsSettingsGroupId.shortcuts,
            title: '闹钟',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.alarm_outlined,
            iconAsset: WsSettingsIcons.alarm,
            androidRef: 'ClockSettingActivity',
            apiCode: WsSettingsApiExamples.alarm,
            // 设备只会有一种闹钟协议；标准 / 标签由 SDK 按能力自动选择。
            requiredFunctions: [
              WSDeviceFunction.alarm,
              WSDeviceFunction.alarm2,
            ],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.notifyRemind,
            group: WsSettingsGroupId.shortcuts,
            title: '消息提醒',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.notifications_outlined,
            iconAsset: WsSettingsIcons.notifyRemind,
            androidRef: 'NotifyRemindSettingActivity',
            apiCode: WsSettingsApiExamples.notifyRemind,
            requiredFunctions: [WSDeviceFunction.notifyReminder],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.eventRemind,
            group: WsSettingsGroupId.shortcuts,
            title: '事件提醒',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.event_note_outlined,
            iconAsset: WsSettingsIcons.eventRemind,
            androidRef: 'EventReminderActivity',
            apiCode: WsSettingsApiExamples.eventRemind,
            // 入口对齐 App：久坐 /（Demo 并入）勿扰；任一能力即可进入。
            requiredFunctions: [
              WSDeviceFunction.longSitReminder,
              WSDeviceFunction.disturb,
            ],
          ),
        ],
      ),
      WsSettingsGroup(
        id: WsSettingsGroupId.settings,
        title: '设置',
        items: [
          WsSettingsItem(
            id: WsSettingsItemId.healthMonitoring,
            group: WsSettingsGroupId.settings,
            title: '健康与监测',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.monitor_heart_outlined,
            iconAsset: WsSettingsIcons.healthMonitoring,
          ),
          WsSettingsItem(
            id: WsSettingsItemId.language,
            group: WsSettingsGroupId.settings,
            title: '设备语言',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.language_outlined,
            iconAsset: WsSettingsIcons.language,
            androidRef: 'DeviceLanguageSettingsActivity',
            apiCode: WsSettingsApiExamples.language,
            requiredFunctions: [WSDeviceFunction.multiLanguage],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.unitSettings,
            group: WsSettingsGroupId.settings,
            title: '单位设置',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.straighten_outlined,
            iconAsset: WsSettingsIcons.unitSettings,
            androidRef: 'UnitSettingActivity',
            apiCode: WsSettingsApiExamples.unitSystem,
          ),
          WsSettingsItem(
            id: WsSettingsItemId.screenDisplay,
            group: WsSettingsGroupId.settings,
            title: '屏幕与显示',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.brightness_medium_outlined,
            iconAsset: WsSettingsIcons.screenDisplay,
            androidRef: 'ScreenDisplayActivity',
            apiCode: WsSettingsApiExamples.screenDisplay,
            requiredFunctions: [WSDeviceFunction.lightDuration],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.syncTime,
            group: WsSettingsGroupId.settings,
            title: '同步时间',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.update_outlined,
            iconAsset: WsSettingsIcons.syncTime,
            apiCode: WsSettingsApiExamples.syncTime,
          ),
          WsSettingsItem(
            id: WsSettingsItemId.userProfileGoals,
            group: WsSettingsGroupId.settings,
            title: '用户资料与目标',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.person_outline,
            iconAsset: WsSettingsIcons.userProfile,
            apiCode: WsSettingsApiExamples.userProfileGoals,
          ),
        ],
      ),
      WsSettingsGroup(
        id: WsSettingsGroupId.other,
        title: '其他',
        items: [
          WsSettingsItem(
            id: WsSettingsItemId.watchFace,
            group: WsSettingsGroupId.other,
            title: '表盘',
            implStatus: WsSettingsImplStatus.deferredThisSprint,
            icon: Icons.watch_outlined,
            iconAsset: WsSettingsIcons.watchFace,
            androidRef: 'UKWatchFaceActivity',
            requiredFunctions: [WSDeviceFunction.customUi],
          ),
          WsSettingsItem(
            id: WsSettingsItemId.clearData,
            group: WsSettingsGroupId.other,
            title: '清除数据',
            implStatus: WsSettingsImplStatus.sdkReady,
            icon: Icons.delete_outline,
            iconAsset: WsSettingsIcons.clearData,
            androidRef: 'WatchDetailFragment.showResetDeviceDialog',
            apiCode: WsSettingsApiExamples.clearDeviceData,
          ),
          WsSettingsItem(
            id: WsSettingsItemId.firmwareUpdate,
            group: WsSettingsGroupId.other,
            title: '固件升级',
            implStatus: WsSettingsImplStatus.deferredThisSprint,
            icon: Icons.system_update_alt_outlined,
            iconAsset: WsSettingsIcons.firmwareUpdate,
            androidRef: 'UpgradeActivity',
            requiredFunctions: [WSDeviceFunction.ota],
          ),
          // 断开连接：主页底部主题色大按钮，不进列表卡片。
        ],
      ),
    ];

/// 仅非「可用」状态需要展示标签；`sdkReady` 返回 null。
String? jwSettingsImplStatusLabel(WsSettingsImplStatus status) =>
    switch (status) {
      WsSettingsImplStatus.sdkReady => null,
      WsSettingsImplStatus.sdkUnsupported => 'SDK 未支持',
      WsSettingsImplStatus.deferredThisSprint => '本轮不实现',
    };
