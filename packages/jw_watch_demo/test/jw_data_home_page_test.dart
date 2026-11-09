import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_data_catalog.dart';
import 'package:jw_watch_demo/src/jw_data_detail_page.dart';
import 'package:jw_watch_demo/src/jw_data_home_page.dart';
import 'package:jw_watch_demo/src/jw_demo_controller.dart';

void main() {
  testWidgets('data home shows sync bar and type cards', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JwDataHomePage(controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('jw.demo.page.data')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.data.sync_hero')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.data.sync_start')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.data.reset_sync_markers')), findsOneWidget);
    expect(find.text('步数'), findsWidgets);
    expect(find.text('心率'), findsOneWidget);
    expect(
        find.byKey(const Key('jw.demo.data.card.heartRate')), findsOneWidget);
  });

  testWidgets('detail pages open without session (empty local DB)', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final item in jwDataCatalog()) {
      await tester.pumpWidget(
        MaterialApp(
          home: JwDataDetailPage(
            controller: controller,
            item: item,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(item.title), findsWidgets);
      expect(
        find.byKey(const Key('jw.demo.data.detail.prev_day')),
        findsOneWidget,
      );
    }
  });

  testWidgets('step detail has date nav and stats blocks', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);
    final item =
        jwDataCatalog().firstWhere((e) => e.id == JwDataTypeId.activity);

    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: JwDataDetailPage(
          controller: controller,
          item: item,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(
        find.byKey(const Key('jw.demo.data.detail.prev_day')), findsOneWidget);
    expect(find.text('总步数'), findsOneWidget);
    expect(find.text('目标完成'), findsOneWidget);
  });
}
