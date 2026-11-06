import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_demo_controller.dart';
import 'package:jw_watch_demo/src/jw_settings_health_monitoring_page.dart';

void main() {
  testWidgets('health monitoring always shows App rows with tags',
      (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: JwHealthMonitoringPage(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('健康与监测'), findsOneWidget);
    expect(find.text('心脏健康'), findsOneWidget);
    expect(find.text('心率自动监测'), findsOneWidget);
    expect(find.text('间隔'), findsOneWidget);
    expect(find.text('高心率警报'), findsOneWidget);
    expect(find.text('血压自动监测'), findsOneWidget);
    expect(find.text('血氧自动监测'), findsOneWidget);
    expect(find.text('低血氧报警'), findsOneWidget);
    expect(find.text('血糖自动监测'), findsOneWidget);
    expect(find.text('高温健康提醒'), findsWidgets);
    expect(find.text('全天睡眠'), findsOneWidget);
    expect(find.text('温度自动监测'), findsOneWidget);
    expect(find.text('压力自动监测'), findsOneWidget);

    expect(find.text('温度过高提醒'), findsNothing);
    expect(find.text('SDK 未支持'), findsWidgets);
    expect(find.textContaining('UKHealthAndMonitoringActivity'), findsNothing);
    expect(find.text('尿酸'), findsNothing);
    expect(find.textContaining('私人'), findsNothing);
  });

  testWidgets('high heart rate secondary page has title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: JwHighHeartRateAlarmPage(enabled: false, maxRate: 180),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('心率区间及提醒'), findsOneWidget);
    expect(find.text('高心率警报'), findsOneWidget);
    expect(find.text('最高心率'), findsOneWidget);
  });

  testWidgets('implemented health title opens API sheet', (tester) async {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: JwHealthMonitoringPage(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('心率自动监测'));
    await tester.pumpAndSettle();

    expect(find.text('公开 API 示例'), findsOneWidget);
    expect(find.textContaining('readHeartRateAutoMeasure'), findsOneWidget);
  });
}
