import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/ebadge/ebadge_app_root.dart';
import 'pages/launcher/app_launcher_page.dart';
import 'pages/image/image_page.dart';
import 'pages/danmaku/danmaku_page.dart';
import 'pages/video/video_page.dart';
import 'pages/slideshow/slideshow_page.dart';
import 'pages/stream/stream_page.dart';
import 'pages/wifi/wifi_page.dart';
import 'pages/chip_config/chip_config_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/settings/cache_management_page.dart';
import 'pages/ota/ota_page.dart';

class EbadgeApp extends StatelessWidget {
  const EbadgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoneyBox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // The home is a single connection-aware gate (no separate "enter scan"
      // layer). Function pages are pushed on top via named routes below.
      home: const AppLauncherPage(),
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, String>?;

        Widget page;
        switch (settings.name) {
          case '/image':
            page = ImagePage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
          case '/danmaku':
            page = DanmakuPage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
          case '/video':
            page = VideoPage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
          case '/slideshow':
            page = SlideshowPage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
          case '/stream':
            page = StreamPage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
          case '/wifi':
            page = WifiPage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
          // Drawer / dashboard entries — device-independent, so args are ignored.
          case '/chip-config':
            page = const ChipConfigPage();
            break;
          case '/settings':
            page = const SettingsPage();
            break;
          case '/cache':
            page = const CacheManagementPage();
            break;
          case '/ota':
            page = const OtaPage();
            break;
          default:
            page = const EBadgeAppRoot();
        }

        return MaterialPageRoute(
          builder: (context) => page,
          settings: settings,
        );
      },
    );
  }
}
