import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/launcher/app_catalog.dart';
import 'package:honeybox/pages/ota/ota_chip_page.dart';
import 'package:honeybox/providers/current_app_provider.dart';

Widget _routeHarness({
  required ProviderContainer container,
  required String label,
  required Widget destination,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => destination),
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('OTA chip back keeps the connected Watch app context',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentAppProvider.notifier).state = AppId.watch;

    await tester.pumpWidget(
      _routeHarness(
        container: container,
        label: 'open-chip',
        destination: const OtaChipPage(),
      ),
    );
    await tester.tap(find.text('open-chip'));
    await tester.pumpAndSettle();
    expect(find.text('选择芯片类型'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('open-chip'), findsOneWidget);
    expect(container.read(currentAppProvider), AppId.watch);
  });
}
