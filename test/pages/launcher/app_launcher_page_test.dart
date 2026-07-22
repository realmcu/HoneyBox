import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebadge_app/pages/launcher/app_launcher_page.dart';
import 'package:ebadge_app/pages/launcher/app_catalog.dart';
import 'package:ebadge_app/pages/launcher/widgets/app_card.dart';

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

  testWidgets('未实现应用显示"预览"角标', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.text('预览'), findsNWidgets(2));
  });

  testWidgets('AppBar 标题为"选择应用"', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.widgetWithText(AppBar, '选择应用'), findsOneWidget);
  });
}
