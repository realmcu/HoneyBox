import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/health/watch_health_data.dart';
import 'package:honeybox/pages/watch/health/watch_health_provider.dart';
import 'package:honeybox/pages/watch/pages/watch_health_page.dart';
import 'package:honeybox/theme/app_theme.dart';

class _ImmediateRepository implements WatchHealthRepository {
  @override
  Future<WatchHealthSnapshot> sync(String deviceId) async {
    return WatchHealthSamples.snapshot;
  }
}

Widget buildPage() {
  return ProviderScope(
    overrides: [
      watchHealthRepositoryProvider.overrideWithValue(_ImmediateRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WatchHealthPage(
        deviceName: 'HoneyBox Watch S1',
        deviceId: 'watch-test',
      ),
    ),
  );
}

void main() {
  testWidgets('starts with an explicit unsynchronized state', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('HoneyBox Watch S1'), findsOneWidget);
    expect(find.text('尚未同步健康数据'), findsOneWidget);
    expect(find.text('同步手表后即可查看'), findsOneWidget);
    expect(find.text('8,426'), findsNothing);
  });

  testWidgets('synchronizes and renders the health dashboard', (tester) async {
    await tester.pumpWidget(buildPage());

    await tester.tap(find.byKey(const Key('watch-health-sync')));
    await tester.pumpAndSettle();

    expect(find.text('8,426'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('7:18'), findsOneWidget);
    expect(find.text('最近同步：刚刚'), findsOneWidget);
    expect(find.text('平均 69 次/分'), findsOneWidget);
  });

  testWidgets('switches to the weekly trend without another sync',
      (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.tap(find.byKey(const Key('watch-health-sync')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();

    expect(find.text('本周日均 7,680 步'), findsOneWidget);
    expect(find.text('平均 72 次/分'), findsOneWidget);
  });

  testWidgets('fits a narrow Android-sized viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.tap(find.byKey(const Key('watch-health-sync')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
