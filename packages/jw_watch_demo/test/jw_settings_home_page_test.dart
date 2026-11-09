import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_demo_controller.dart';
import 'package:jw_watch_demo/src/jw_find_device_page.dart';
import 'package:jw_watch_demo/src/jw_settings_home_page.dart';

void main() {
  testWidgets('settings home shows App-like groups and rows', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JwSettingsHomePage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jw.demo.page.settings')), findsOneWidget);
    expect(
        find.byKey(const Key('jw.demo.settings.device_overview')), findsOneWidget);
    expect(find.text('常用功能'), findsOneWidget);
    expect(find.text('查找设备'), findsOneWidget);
    expect(
      find.byKey(const Key('jw.demo.settings.row.findDevice')),
      findsOneWidget,
    );
    expect(find.text('SDK 未支持'), findsWidgets);
    expect(find.text('可用'), findsNothing);
    expect(find.byKey(const Key('jw.demo.settings.show_unsupported')),
        findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('jw.demo.settings.row.unitSettings')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('单位设置'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('jw.demo.settings.row.watchFace')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('表盘'), findsOneWidget);
    expect(find.text('本轮不实现'), findsWidgets);
  });

  testWidgets('find device opens App-like ripple page', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JwSettingsHomePage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('jw.demo.settings.row.findDevice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('查找设备'), findsWidgets);
    expect(find.byKey(const Key('jw.demo.settings.find_device.toggle')),
        findsOneWidget);
    expect(find.byKey(const Key('jw.demo.settings.find_device.api')),
        findsOneWidget);
    expect(find.text('Immediate Alert'), findsNothing);
  });

  testWidgets('find device API action opens sheet', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: JwFindDevicePage(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('jw.demo.settings.find_device.api')));
    await tester.pumpAndSettle();
    expect(find.text('公开 API 示例'), findsOneWidget);
    expect(find.textContaining('session.findDevice'), findsOneWidget);
  });

  testWidgets('device control opens lab from settings', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JwSettingsHomePage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('jw.demo.settings.row.deviceControl')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('jw.demo.control.lab')), findsOneWidget);
    expect(find.text('设备控制'), findsWidgets);
  });

  testWidgets('take photo opens control page', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JwSettingsHomePage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('jw.demo.settings.row.takePhoto')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('jw.demo.settings.take_photo.page')),
        findsOneWidget);
    expect(find.byKey(const Key('jw.demo.settings.take_photo.api')),
        findsOneWidget);
    expect(find.text('未连接设备'), findsOneWidget);
  });
}
