import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/health/jw_health_sport_page.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import '../../services/jw/jw_health_aggregator_test.dart' show healthRow;

void main() {
  // History key0x16 byte8: HL_Private_Protocol.md:2234-2261;
  // hub_exercise.h:33-60. Raw UK enum is not unified WSSportType.
  test('history mode byte uses all verified names and conservative fallback',
      () {
    const names = [
      '跑步',
      '登山',
      '足球',
      '骑行',
      '跳绳',
      '户外跑步',
      '户外骑车',
      '户外徒步',
      '室内跑步',
      '自由训练',
      '平板支撑',
      '健走',
      '呼吸训练',
      '瑜伽',
      '徒步',
      '动感单车',
      '划船机',
      '踏步机',
      '椭圆机',
      '篮球',
      '网球',
      '羽毛球',
      '棒球',
      '橄榄球',
      '乒乓球',
      '滑雪',
      '板球',
      '力量训练'
    ];
    for (var i = 0; i < names.length; i++) {
      expect(jwHealthSportTitle(healthRow(JwHistoryType.exercise, {'mode': i})),
          '运动记录 · ${names[i]}');
    }
    for (final mode in [28, 29, 30, 255]) {
      expect(
          jwHealthSportTitle(healthRow(JwHistoryType.exercise, {'mode': mode})),
          '运动记录 · 模式 $mode');
    }
  });

  test(
      'sport overview preserves measured zero seconds without invented minutes',
      () {
    final record = healthRow(JwHistoryType.exercise,
        {'mode': 28, 'durationSeconds': 0, 'energyCalories': 0});
    expect(jwHealthSportOverview(record), '2026-10-05 · 0秒 · 0 kcal');
  });

  testWidgets(
      'detail converts distance and energy with absent duration explicit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: JwHealthSportPage(
            record: healthRow(JwHistoryType.exercise, {
      'mode': 0,
      'distanceMeters': 2500,
      'energyCalories': 123000
    }))));
    expect(find.text('2.5 km'), findsOneWidget);
    expect(find.text('123 kcal'), findsOneWidget);
    expect(find.text('暂无数据'), findsWidgets);
    expect(find.textContaining('不显示曲线'), findsOneWidget);
  });
}
