import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';

void main() {
  testWidgets('api example opens as modal sheet on current page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(
                      JwDemoContentSheet.showApiExample(
                        context,
                        stepTitle: '初始化 SDK',
                        code: 'await watch.initialize();',
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('初始化 SDK'), findsOneWidget);
    expect(find.text('公开 API 示例'), findsOneWidget);
    expect(find.byKey(const Key('jw.demo.content_sheet')), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
