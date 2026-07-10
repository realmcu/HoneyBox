import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'providers/ble_provider.dart';
import 'providers/transfer_provider.dart';
import 'pages/scan/scan_page.dart';
import 'pages/device/device_page.dart';
import 'pages/image/image_page.dart';
import 'pages/danmaku/danmaku_page.dart';
import 'pages/video/video_page.dart';
import 'pages/slideshow/slideshow_page.dart';
import 'pages/stream/stream_page.dart';
import 'pages/wifi/wifi_page.dart';
import 'pages/chip_config/chip_config_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/ota/ota_page.dart';

class EbadgeApp extends StatelessWidget {
  const EbadgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eBadge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // The home is a single connection-aware gate (no separate "enter scan"
      // layer). Function pages are pushed on top via named routes below.
      home: const AppRoot(),
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
          case '/ota':
            page = const OtaPage();
            break;
          default:
            page = const AppRoot();
        }

        return MaterialPageRoute(
          builder: (context) => page,
          settings: settings,
        );
      },
    );
  }
}

/// Root gate: decides what the app shows based on the BLE connection state.
///
/// - Not connected  → [ScanPage] (which immediately starts scanning).
/// - Connected      → [DevicePage] for the connected device.
///
/// Connecting/disconnecting is driven purely by provider state, so there is no
/// extra navigation layer to "enter" the scanner — it simply is the home
/// screen whenever no device is attached.
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When a connection drops, discard any open function sub-page so we land
    // back on the gate (which now renders the scanner) and notify the user.
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (prev != null && next == null) {
        // Clear any lingering send status so the next connection/card starts clean.
        ref.read(transferProgressProvider.notifier).reset();
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final connected = ref.watch(connectedDeviceProvider);
    if (connected != null) {
      return DevicePage(
        deviceName: connected.name,
        deviceId: connected.deviceId,
      );
    }
    return const ScanPage();
  }
}
