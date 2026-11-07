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
    expect(find.byKey(const Key('jw.demo.data.mock_toggle')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.data.sync_start')), findsOneWidget);
    expect(find.text('步数'), findsOneWidget);
    expect(find.text('心率'), findsOneWidget);
    expect(
        find.byKey(const Key('jw.demo.data.card.heartRate')), findsOneWidget);
    expect(find.textContaining('步'), findsWidgets);
  });

  testWidgets('step detail uses App-style light top and chart', (tester) async {
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
          useMock: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('步数'), findsWidgets);
    expect(find.text('今天'), findsOneWidget);
    expect(
        find.byKey(const Key('jw.demo.data.detail.prev_day')), findsOneWidget);
    expect(find.text('总步数'), findsOneWidget);
    expect(find.text('目标完成'), findsOneWidget);
  });

  testWidgets('date nav stays centered when shifting days', (tester) async {
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
          useMock: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final todayCenter = tester.getCenter(find.text('今天'));
    expect(todayCenter.dx, closeTo(200, 8));

    await tester.tap(find.byKey(const Key('jw.demo.data.detail.prev_day')));
    await tester.pumpAndSettle();
    expect(find.text('昨天'), findsOneWidget);
    expect(tester.getCenter(find.text('昨天')).dx, closeTo(200, 8));

    await tester.tap(find.byKey(const Key('jw.demo.data.detail.prev_day')));
    await tester.pumpAndSettle();
    expect(find.text('昨天'), findsNothing);
    expect(find.text('今天'), findsNothing);
    // 再往前应是 yyyy.MM.dd，且仍居中，不应跳回今天。
    final older = find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(w.data ?? ''),
    );
    expect(older, findsOneWidget);
    expect(tester.getCenter(older).dx, closeTo(200, 8));
  });

  testWidgets('heart rate detail shows avg/max/min stats', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);
    final item =
        jwDataCatalog().firstWhere((e) => e.id == JwDataTypeId.heartRate);

    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: JwDataDetailPage(
          controller: controller,
          item: item,
          useMock: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('平均心率'), findsOneWidget);
    expect(find.text('最高'), findsOneWidget);
    expect(find.text('最低'), findsOneWidget);
  });

  testWidgets('all mock detail types open without crashing', (tester) async {
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
            useMock: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(item.title), findsWidgets);
      expect(
        find.byKey(const Key('jw.demo.data.detail.prev_day')),
        findsOneWidget,
      );
    }
  });
}
