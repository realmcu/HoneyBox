import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/launcher/app_launcher_page.dart';
import 'package:honeybox/pages/launcher/app_catalog.dart';
import 'package:honeybox/pages/launcher/widgets/app_card.dart';
import 'package:honeybox/pages/watch_lab/sdk_demo_hub_page.dart';
import 'package:honeybox/providers/current_app_provider.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: child),
      );

  testWidgets('launcher lists every catalog entry (scroll to build)', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    final scrollable = find.byType(Scrollable);
    expect(find.byType(AppCard), findsWidgets);
    for (final e in kAppCatalog) {
      await tester.scrollUntilVisible(
        find.text(e.title),
        120,
        scrollable: scrollable,
      );
      expect(find.byType(AppCard), findsWidgets);
    }
    expect(kAppCatalog.length, 6);
  });

  testWidgets('每个应用的 title 都出现在页面上', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    final scrollable = find.byType(Scrollable);
    for (final e in kAppCatalog) {
      await tester.scrollUntilVisible(
        find.text(e.title),
        120,
        scrollable: scrollable,
      );
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

  testWidgets('SDK Demo 入口进入 Hub，JW/WS 子项可进入全屏 Demo', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppLauncherPage()),
    ));

    await tester.ensureVisible(find.text('SDK Demo'));
    await tester.tap(find.text('SDK Demo'));
    await tester.pumpAndSettle();

    expect(find.byType(SdkDemoHubPage), findsOneWidget);
    expect(container.read(currentAppProvider), AppId.watchLab);

    await tester.tap(find.byKey(const Key('sdk_demo.jw_card')));
    await tester.pumpAndSettle();
    expect(find.byType(JWWatchLabAppRoot), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SdkDemoHubPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('sdk_demo.ws_card')));
    await tester.pumpAndSettle();
    expect(find.byType(WSWatchLabAppRoot), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SdkDemoHubPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SdkDemoHubPage), findsNothing);
    expect(container.read(currentAppProvider), isNull);
  });
}
