// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:honeybox/app.dart';
import 'package:honeybox/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('HoneyBoxApp shows app launcher', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HoneyBoxApp()));
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'HoneyBox');

    // The launcher title depends on the resolved language (test hosts report
    // en_US, devices may report zh), so assert through the same provider the
    // UI reads instead of hard-coding one language's copy.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    expect(find.text(container.read(appStringsProvider).launcherTitle),
        findsOneWidget);
  });
}
