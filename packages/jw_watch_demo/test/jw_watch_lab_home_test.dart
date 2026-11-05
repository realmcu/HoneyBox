import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';

void main() {
  testWidgets('shows four stable navigation destinations before connection',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    expect(find.byKey(const Key('jw.demo.tab.home')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.features')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.scenarios')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.device')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.session_status')), findsOneWidget);
  });

  testWidgets('keeps features in their own tab', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    await tester.tap(find.byKey(const Key('jw.demo.tab.features')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jw.demo.page.features')), findsOneWidget);
    expect(
        find.byKey(const Key('jw.demo.feature.measurements')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.feature.history')), findsOneWidget);
  });

  testWidgets('history feature opens sync flow page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    await tester.tap(find.byKey(const Key('jw.demo.tab.features')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jw.demo.feature.history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jw.demo.history.sync.flow')), findsOneWidget);
    expect(find.text('开始同步'), findsOneWidget);
  });

  testWidgets('connection sliver list lays out device row on narrow screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverList.separated(
                  itemCount: 1,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return Padding(
                      key: const Key('jw.demo.device.59:17:01:1B:E7:B1'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PEARCE'),
                                  Text('59:17:01:1B:E7:B1 · RSSI -62'),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('连接'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PEARCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows inline user id field defaulting to 123456', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jw.demo.user_id_input')), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('home guide actions layout without rendering exceptions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('jw.demo.guide.initialize')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('jw.demo.page.home')), findsOneWidget);
  });

  testWidgets('opens API guidance in content sheet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    await tester.tap(find.byKey(const Key('jw.demo.tab.features')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jw.demo.feature.measurements')));
    await tester.pumpAndSettle();

    expect(find.text('公开 API 示例'), findsOneWidget);
    expect(find.textContaining('startHeartRate'), findsOneWidget);
  });
}
