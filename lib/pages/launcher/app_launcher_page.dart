import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../i18n/app_language.dart';
import '../../i18n/app_strings.dart';
import '../../providers/ble_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/app_settings.dart';
import '../../providers/current_app_provider.dart';
import '../ebadge/ebadge_app_root.dart';
import '../shared/update_flow.dart';
import '../watch/watch_app_root.dart';
import '../watch_lab/sdk_demo_app_root.dart';
import 'app_catalog.dart';
import 'connected_app.dart';
import 'widgets/app_card.dart';

/// Sentinel value for the overflow-menu entry that is an *action* rather than a
/// route push (all other values are route names).
const String _kUpdateAction = '#check-update';

/// APK 打开时首先看到的页面。
/// 从 [kAppCatalog] 读取应用清单，展示为卡片列表。点击后 push 对应
/// `<App>AppRoot`（带 route name，供断连回退 popUntil 匹配）。
class AppLauncherPage extends ConsumerWidget {
  const AppLauncherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectedDeviceProvider);
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.launcherTitle),
        actions: [
          // Language lives here rather than inside the dashboard: it now drives
          // both this app and the native dashboard, so it belongs one level up.
          PopupMenuButton<AppLanguage>(
            icon: const Icon(Icons.language),
            tooltip: strings.languageTooltip,
            onSelected: (language) => setAppLanguage(ref, language),
            itemBuilder: (context) => [
              for (final language in AppLanguage.values)
                CheckedPopupMenuItem<AppLanguage>(
                  value: language,
                  checked: ref.watch(appSettingsProvider).language == language,
                  child: Text(switch (language) {
                    AppLanguage.system => strings.languageFollowSystem,
                    AppLanguage.zhHans => strings.languageChinese,
                    AppLanguage.en => strings.languageEnglish,
                  }),
                ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              // The update entry runs in place; every other entry is a route.
              if (v == _kUpdateAction) {
                runUpdateCheck(context);
                return;
              }
              Navigator.pushNamed(context, v);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: '/chip-config', child: Text(strings.menuChipConfig)),
              PopupMenuItem(
                  value: _kUpdateAction, child: Text(strings.menuCheckUpdate)),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: kAppCatalog.length,
        itemBuilder: (_, i) {
          final entry = kAppCatalog[i];
          return AppCard(
            entry: entry,
            connectedDeviceName: connectedDeviceMatchesApp(connected, entry.id)
                ? connected?.name
                : null,
            onTap: () => _launch(context, ref, entry),
          );
        },
      ),
    );
  }

  Future<void> _launch(
    BuildContext context,
    WidgetRef ref,
    AppEntry entry,
  ) async {
    if (entry.id == AppId.dashboard) {
      try {
        await const MethodChannel('honeybox/map').invokeMethod<void>('open');
      } on PlatformException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.message ?? AppStrings.of(context).openMapFailed,
              ),
            ),
          );
        }
      } on MissingPluginException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).mapUnsupported)),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).openMapFailedWith('$error')),
            ),
          );
        }
      }
      return;
    }

    final existing = ref.read(connectedDeviceProvider);
    final usesDeviceConnection =
        entry.id == AppId.ebadge || entry.id == AppId.watch;
    if (usesDeviceConnection &&
        existing != null &&
        !connectedDeviceMatchesApp(existing, entry.id)) {
      final switchApp = await _confirmSwitchConnectedApp(
        context,
        connectedName: existing.name,
        targetName: AppStrings.of(context).appTitle(entry.id),
      );
      if (!switchApp || !context.mounted) return;
      await ref.read(bleNotifierProvider.notifier).disconnect();
      if (!context.mounted) return;
    }

    ref.read(currentAppProvider.notifier).state = entry.id;
    final name = routeNameFor(entry.id);
    try {
      await Navigator.of(context).push(MaterialPageRoute(
        settings: RouteSettings(name: name),
        builder: (_) => _rootFor(entry),
      ));
    } finally {
      if (context.mounted && ref.read(currentAppProvider) == entry.id) {
        ref.read(currentAppProvider.notifier).state = null;
      }
    }
  }

  Future<bool> _confirmSwitchConnectedApp(
    BuildContext context, {
    required String connectedName,
    required String targetName,
  }) async {
    final strings = AppStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(strings.switchAppTitle),
            content: Text(strings.switchAppBody(connectedName, targetName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(strings.disconnectAndOpen),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _rootFor(AppEntry entry) {
    switch (entry.id) {
      case AppId.ebadge:
        return const EBadgeAppRoot();
      case AppId.watch:
        return const WatchAppRoot();
      case AppId.dashboard:
        // Dashboard is opened as a native Activity through the 'honeybox/map'
        // channel (see _launch), so this widget route is never taken.
        throw StateError(
            'dashboard is opened natively, not as a Flutter route');
      case AppId.watchLab:
        return const SdkDemoAppRoot();
    }
  }
}
