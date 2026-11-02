import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/launcher/app_launcher_page.dart';
import 'package:honeybox/pages/launcher/app_catalog.dart';
import 'package:honeybox/pages/launcher/widgets/app_card.dart';
import 'package:honeybox/providers/current_app_provider.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';

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

  testWidgets('WS Watch 入口打开 Demo 首页，返回后清空当前应用', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppLauncherPage()),
    ));

    await tester.ensureVisible(find.text('WS Watch'));
    await tester.tap(find.text('WS Watch'));
    await tester.pumpAndSettle();

    expect(find.byType(WSWatchDemoHome), findsOneWidget);
    expect(container.read(currentAppProvider), AppId.wsWatch);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(WSWatchDemoHome), findsNothing);
    expect(container.read(currentAppProvider), isNull);
  });
}
