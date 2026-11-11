import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/launcher/app_launcher_page.dart';
import 'package:honeybox/pages/launcher/app_catalog.dart';
import 'package:honeybox/pages/launcher/widgets/app_card.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/providers/current_app_provider.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: child),
      );

  testWidgets('renders one AppCard per kAppCatalog entry', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.byType(AppCard), findsNWidgets(kAppCatalog.length));
  });

  testWidgets('每个应用的 title 都出现在页面上', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    for (final e in kAppCatalog) {
      expect(find.text(e.title), findsOneWidget,
          reason: '${e.title} not rendered');
    }
  });

  testWidgets('入口应用不显示"预览"角标', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.text('预览'), findsNothing);
  });

  testWidgets('AppBar 标题为"选择应用"', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.widgetWithText(AppBar, '选择应用'), findsOneWidget);
  });

  testWidgets('主页面菜单只显示全局功能', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('芯片配置'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
    expect(find.text('缓存管理'), findsNothing);
  });

  testWidgets('connected app is visible on its launcher card', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        connectedDeviceProvider.overrideWith((ref) => ConnectedDeviceInfo(
              deviceId: 'watch-1',
              name: 'Watch-A1',
              mtu: 247,
              isJw: true,
              ownerApp: AppId.watch.name,
            )),
      ],
      child: const MaterialApp(home: AppLauncherPage()),
    ));

    expect(find.text('已连接 · Watch-A1'), findsOneWidget);
  });

  testWidgets('switching to another device app requires confirmation',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        connectedDeviceProvider.overrideWith((ref) => ConnectedDeviceInfo(
              deviceId: 'watch-1',
              name: 'Watch-A1',
              mtu: 247,
              isJw: true,
              ownerApp: AppId.watch.name,
            )),
      ],
      child: const MaterialApp(home: AppLauncherPage()),
    ));

    await tester.tap(find.text('eBadge'));
    await tester.pumpAndSettle();

    expect(find.text('切换应用'), findsOneWidget);
    expect(find.textContaining('当前已连接 Watch-A1'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('选择应用'), findsOneWidget);
  });

  testWidgets('returning from a non-device app clears current app state',
      (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppLauncherPage)),
    );

    await tester.ensureVisible(find.text('OTA'));
    await tester.tap(find.text('OTA'));
    await tester.pumpAndSettle();
    expect(find.text('选择芯片类型'), findsOneWidget);
    expect(container.read(currentAppProvider), AppId.ota);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('选择应用'), findsOneWidget);
    expect(container.read(currentAppProvider), isNull);
  });
}
