import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/health/watch_health_data.dart';
import 'package:honeybox/pages/watch/health/watch_health_provider.dart';
import 'package:honeybox/pages/watch/pages/watch_health_page.dart';
import 'package:honeybox/providers/watch_bind_provider.dart';
import 'package:honeybox/theme/app_theme.dart';

import '../../helpers/watch_health_fixture.dart';

class _ImmediateRepository implements WatchHealthRepository {
  int syncCount = 0;

  @override
  Future<WatchHealthSnapshot> sync(String deviceId) async {
    syncCount++;
    return watchHealthFixture();
  }
}

class _TestBindNotifier extends WatchBindNotifier {
  _TestBindNotifier({required bool bound})
      : super(
          commandAvailable: () => true,
          sendCommand: (_) => 1,
          notifications: const Stream.empty(),
          userId: Uint8List(32),
        ) {
    if (bound) {
      state = const WatchBindState(
        WatchBindPhase.success,
        timeSyncPhase: WatchTimeSyncPhase.synced,
      );
    }
  }
}

Widget _buildPage(
    {required _ImmediateRepository repository, bool bound = true}) {
  return ProviderScope(
    overrides: [
      watchHealthRepositoryProvider.overrideWithValue(repository),
      watchBindProvider.overrideWith((ref) => _TestBindNotifier(bound: bound)),
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
  testWidgets('automatically synchronizes once when opened while bound',
      (tester) async {
    final repository = _ImmediateRepository();
    await tester.pumpWidget(_buildPage(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('HoneyBox Watch S1'), findsOneWidget);
    expect(find.text('1,000'), findsOneWidget);
    expect(repository.syncCount, 1);
  });

  testWidgets('does not synchronize automatically while unbound',
      (tester) async {
    final repository = _ImmediateRepository();
    await tester.pumpWidget(_buildPage(repository: repository, bound: false));
    await tester.pumpAndSettle();

    expect(find.text('设备尚未绑定'), findsWidgets);
    expect(repository.syncCount, 0);
  });

  testWidgets('synchronizes and renders the health dashboard', (tester) async {
    final repository = _ImmediateRepository();
    await tester.pumpWidget(_buildPage(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('watch-health-sync')));
    await tester.pumpAndSettle();

    expect(find.text('1,000'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('4:00'), findsOneWidget);
    expect(find.text('最近同步：12:00'), findsOneWidget);
    expect(repository.syncCount, 2);

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    // Bucket-average heart rate, labelled to the minute (v1 has no per-sample
    // stream, so the fixture's newest bucket is 08:15).
    expect(find.textContaining('7/30 08:15'), findsOneWidget);
  });

  testWidgets('switches to the weekly trend without another sync',
      (tester) async {
    final repository = _ImmediateRepository();
    await tester.pumpWidget(_buildPage(repository: repository));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();

    expect(find.text('日均 143 步'), findsOneWidget);
  });

  testWidgets('fits a narrow Android-sized viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildPage(repository: _ImmediateRepository()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
