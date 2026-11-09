import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_control_lab_page.dart';
import 'package:jw_watch_demo/src/jw_demo_controller.dart';

void main() {
  testWidgets('control lab shows actions and log placeholder', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: JwControlLabPage(controller: controller)),
    );
    await tester.pump();

    expect(find.byKey(const Key('jw.demo.control.lab')), findsOneWidget);
    expect(find.text('请先完成连接与登录。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('jw.demo.control.lab.api')));
    await tester.pumpAndSettle();
    expect(find.text('公开 API 示例'), findsOneWidget);
    expect(find.textContaining('setWeather'), findsOneWidget);
  });
}
