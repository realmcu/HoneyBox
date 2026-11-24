import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const selected = String.fromEnvironment('WS_LAB_PLAN', defaultValue: 'smoke');
  final planIds = selected == 'all'
      ? WSDemoLabRunner.availablePlanIds
      : <String>[selected];

  for (final planId in planIds) {
    testWidgets('WS demo lab plan: $planId', (tester) async {
      final runner = WSDemoLabRunner(
        eventSink: (event) {
          debugPrint('WS_LAB_JSON ${jsonEncode(event)}');
        },
      );
      final report = await tester.runAsync(() => runner.run(planId));
      expect(
        report?.passed,
        isTrue,
        reason: report == null
            ? 'Lab produced no report.'
            : jsonEncode(report.toJson()),
      );
    });
  }
}
