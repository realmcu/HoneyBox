import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_demo_dialogs.dart';

void main() {
  testWidgets('showMessage returns true on positive', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await JwDemoDialogs.showMessage(
                  context,
                  title: '断开连接',
                  detail: '确认断开当前设备？',
                  positiveText: '断开',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('断开连接'), findsOneWidget);
    expect(find.text('确认断开当前设备？'), findsOneWidget);

    await tester.tap(find.text('断开'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('showSinglePicker returns selected value', (tester) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await JwDemoDialogs.showSinglePicker<int>(
                  context,
                  title: '提醒间隔',
                  values: const [30, 45, 60],
                  labelOf: (v) => '$v',
                  initial: 45,
                  dataTips: '分钟',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('提醒间隔'), findsOneWidget);
    expect(find.text('分钟'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, 45);
  });

  testWidgets('showSelectTime returns range', (tester) async {
    JwDemoTimeRange? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await JwDemoDialogs.showSelectTime(
                  context,
                  startHour: 9,
                  startMinute: 0,
                  endHour: 18,
                  endMinute: 30,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('18:30'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result?.startHour, 9);
    expect(result?.startMinute, 0);
    expect(result?.endHour, 18);
    expect(result?.endMinute, 30);
  });
}
