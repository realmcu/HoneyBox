// device_features.dart
//
// 功能选择界面(DevicePage)上的卡片目录。
//
// 目录单独成文件,是因为**「哪类设备有哪些功能」是两类设备之间唯一的差别** —— 页面
// 本身(顶部设备栏、网格布局、返回/断开)对两者完全一致。把它抽出来之后,加一类
// 设备或给某类设备加一张卡片都不用碰页面结构,也才测得住:卡片集合是这段需求的
// 主体,藏在页面的私有常量里就没法在不搭整棵 widget 树的情况下验证。

import 'package:flutter/material.dart';

import '../../services/device_type_store.dart';

/// 一张功能卡片:图标 + 标题 + 路由,以及它对该类设备是否可见。
class DeviceFeature {
  const DeviceFeature({
    required this.icon,
    required this.title,
    required this.route,
    required this.types,
  });

  final IconData icon;
  final String title;

  /// 命名路由,参数统一是 `{deviceName, deviceId}`(见 `app.dart`)。
  final String route;

  /// 这张卡片对哪些设备类型可见。
  ///
  /// 用集合而不是单个类型:同一个功能将来完全可能两类设备都有(比如 Wi-Fi 配网
  /// 这种看设备固件而不是看产品线的能力),届时只改这里一行。
  final Set<DeviceType> types;

  bool showsFor(DeviceType type) => types.contains(type);
}

/// 全部功能卡片,按界面上的展示顺序。
const List<DeviceFeature> kDeviceFeatures = [
  DeviceFeature(
    icon: Icons.image_outlined,
    title: '图片',
    route: '/image',
    types: {DeviceType.demo},
  ),
  DeviceFeature(
    icon: Icons.chat_bubble_outline,
    title: '弹幕',
    route: '/danmaku',
    types: {DeviceType.demo},
  ),
  DeviceFeature(
    icon: Icons.movie_creation_outlined,
    title: '视频 / GIF',
    route: '/video',
    types: {DeviceType.demo},
  ),
  DeviceFeature(
    icon: Icons.burst_mode_outlined,
    title: '多图轮播',
    route: '/slideshow',
    types: {DeviceType.demo},
  ),
  // 拍照投屏 — Apple-style AirPlay/screen-mirroring glyph.
  DeviceFeature(
    icon: Icons.airplay,
    title: '拍照投屏',
    route: '/stream',
    types: {DeviceType.demo},
  ),
  // OTA 升级 — reserved; the internal page is intentionally empty for now.
  DeviceFeature(
    icon: Icons.system_update_alt,
    title: 'OTA 升级',
    route: '/ota',
    types: {DeviceType.demo},
  ),
  // 协议调试 — eBadge 私有协议(f48affc0 服务)的收发调试台。
  //
  // **只挂在 Mi 上**:Demo 样机跑的是业务功能那一套,调试台对它没有意义;而 Mi
  // 目前除了这个收发台还没有别的功能可列 —— 把 Demo 那几张卡片也摆出来只会让人
  // 点进一个这台机器不认的页面。
  DeviceFeature(
    icon: Icons.terminal,
    title: '协议调试',
    route: '/ebadge-debug',
    types: {DeviceType.mi},
  ),
];

/// [type] 这类设备该列出的卡片,保持 [kDeviceFeatures] 的顺序。
List<DeviceFeature> deviceFeaturesFor(DeviceType type) =>
    kDeviceFeatures.where((f) => f.showsFor(type)).toList(growable: false);
