import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';

void main() {
  testWidgets('shows three navigation destinations before connection',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    expect(find.byKey(const Key('jw.demo.tab.home')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.data')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.settings')), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.tab.features')), findsNothing);
    expect(find.byKey(const Key('jw.demo.session_status')), findsNothing);
    expect(find.byKey(const Key('jw.demo.home.session_card')), findsNothing);
  });

  testWidgets('data and settings tabs stay on home before session ready',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JWWatchLabHome()));

    await tester.tap(find.byKey(const Key('jw.demo.tab.data')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jw.demo.page.home')), findsOneWidget);

    await tester.tap(find.byKey(const Key('jw.demo.tab.settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jw.demo.page.home')), findsOneWidget);
  });

  testWidgets('home shows inline user id field defaulting to 123456',
      (tester) async {
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
}
