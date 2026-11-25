import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'i18n/app_language.dart';
import 'i18n/app_strings.dart';
import 'providers/language_provider.dart';
import 'theme/app_theme.dart';
import 'pages/ebadge/ebadge_app_root.dart';
import 'pages/ebadge/ebadge_debug_page.dart';
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
import 'pages/watch/pages/watch_face_page.dart';
import 'pages/watch/pages/watch_notification_page.dart';
import 'pages/watch/pages/watch_health_page.dart';
import 'pages/watch/pages/watch_factory_page.dart';
import 'pages/ota/watch_rtl87x3g_ota_page.dart';

class HoneyBoxApp extends ConsumerStatefulWidget {
  const HoneyBoxApp({super.key});

  @override
  ConsumerState<HoneyBoxApp> createState() => _HoneyBoxAppState();
}

class _HoneyBoxAppState extends ConsumerState<HoneyBoxApp> {
  @override
  void initState() {
    super.initState();
    // Tell the native dashboard which language to use before it can be opened.
    pushLanguageToNative(ref.read(resolvedLanguageProvider));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    // Mirror every later change into the dashboard's own preference store.
    ref.listen<AppLanguage>(resolvedLanguageProvider, (_, next) {
      pushLanguageToNative(next);
    });

    return AppStringsScope(
      strings: strings,
      child: MaterialApp(
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
            case '/ebadge-debug':
              page = EBadgeDebugPage(
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
            // Watch feature pages. Health consumes the connected device details.
            case '/watch-face':
              page = const WatchFacePage();
              break;
            case '/watch-notification':
              page = const WatchNotificationPage();
              break;
            case '/watch-health':
              page = WatchHealthPage(
                deviceName: args?['deviceName'] ?? 'Watch',
                deviceId: args?['deviceId'] ?? '',
              );
              break;
            case '/watch-factory':
              page = WatchFactoryPage(
                deviceName: args?['deviceName'] ?? 'Watch',
                deviceId: args?['deviceId'] ?? '',
              );
              break;
            case '/watch-rtl87x3g-ota':
              page = WatchRtl87x3gOtaPage(
                deviceName: args?['deviceName'] ?? 'Watch',
                deviceId: args?['deviceId'] ?? '',
              );
              break;
            default:
              page = const EBadgeAppRoot();
          }

          return MaterialPageRoute(
            builder: (context) => page,
            settings: settings,
          );
        },
      ),
    );
  }
}
