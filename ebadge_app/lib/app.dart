import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/scan/scan_page.dart';
import 'pages/device/device_page.dart';
import 'pages/image/image_page.dart';
import 'pages/danmaku/danmaku_page.dart';
import 'pages/gif/gif_page.dart';
import 'pages/video/video_page.dart';
import 'pages/stream/stream_page.dart';

class EbadgeApp extends StatelessWidget {
  const EbadgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eBadge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/scan',
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, String>?;

        Widget page;
        switch (settings.name) {
          case '/scan':
            page = const ScanPage();
            break;
          case '/device':
            page = DevicePage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
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
          case '/gif':
            page = GifPage(
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
          case '/stream':
            page = StreamPage(
              deviceName: args?['deviceName'] ?? '',
              deviceId: args?['deviceId'] ?? '',
            );
            break;
          default:
            page = const ScanPage();
        }

        return MaterialPageRoute(
          builder: (context) => page,
          settings: settings,
        );
      },
    );
  }
}
