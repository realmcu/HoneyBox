import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:honeybox/pages/watch/health/jw_health_page.dart';
import 'package:honeybox/pages/watch/health/jw_health_sport_page.dart';
import 'package:honeybox/pages/watch/watch_app_root.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:honeybox/validation/jw_health_ui_acceptance_main.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/jw/health/jw_health_repository.dart';
import 'package:honeybox/services/jw/health/jw_health_models.dart';
import 'package:honeybox/services/jw/health/jw_health_goals.dart';

void main() {
  test('launch requires explicit mode and absolute isolated paths', () {
    // Absolute paths must be native to the host: CI runs on Linux.
    final root = Platform.isWindows ? 'C:' : '/tmp';
    final receipt = '$root/receipt';
    final fixture = '$root/fixture';
    expect(() => JwHealthAcceptanceOptions.parse([]), throwsArgumentError);
    expect(
        () => JwHealthAcceptanceOptions.parse(
            ['--jw-health-mode=fixture', '--jw-health-output=relative']),
        throwsArgumentError);
    expect(
        () => JwHealthAcceptanceOptions.parse([
              '--jw-health-mode=real',
              '--jw-health-output=$receipt',
              '--jw-health-fixture-data=$fixture'
            ]),
        throwsArgumentError);
    final options = JwHealthAcceptanceOptions.parse([
      '--jw-health-mode=fixture',
      '--jw-health-output=$receipt',
      '--jw-health-fixture-data=$fixture'
    ]);
    expect(options.mode, 'fixture');
    expect(options.fixtureData!.path, fixture);
  });

  test(
      'decoded seed preserves zeros, sparse metrics, partial day and closed sleep',
      () async {
    final dir = await Directory.systemTemp.createTemp('health-host-seed-');
    final fixture = await JwHealthAcceptanceFixture.open(dir,
        data: Directory('${dir.path}/data'), commitDelay: Duration.zero);
    try {
      final repo = JwHealthRepository(fixture.store);
      final day = await repo.load(
          deviceKey: jwHealthFixtureHistoryKey,
          date: DateTime.utc(2026, 10, 5),
          period: JwHealthPeriod.day);
      expect(day.totals.steps, 1234);
      expect(day.totals.distanceMeters, 890);
      expect(day.totals.energyKcal, 123.45);
      expect(day.totals.sleepMinutes, 150);
      expect(day.metrics[JwHealthMetric.heartRate]!.average, 72);
      expect(day.metrics[JwHealthMetric.bloodPressure]!.samples, hasLength(2));
      expect(day.sportRecords.single.values['heartRateAverage'], 72);
      final zero = await repo.load(
          deviceKey: jwHealthFixtureHistoryKey,
          date: DateTime.utc(2026, 9, 30),
          period: JwHealthPeriod.day);
      expect(zero.totals.steps, 0);
      final empty = await repo.load(
          deviceKey: jwHealthFixtureHistoryKey,
          date: DateTime.utc(2026, 10, 1),
          period: JwHealthPeriod.day);
      expect(empty.totals.steps, isNull);
      final partial = await repo.load(
          deviceKey: jwHealthFixtureHistoryKey,
          date: DateTime.utc(2026, 10, 2),
          period: JwHealthPeriod.day);
      expect(partial.coverage.partialRecordIds, isNotEmpty);
      final week = await repo.load(
          deviceKey: jwHealthFixtureHistoryKey,
          date: DateTime.utc(2026, 10, 5),
          period: JwHealthPeriod.week);
      expect(week.days, hasLength(7));
      expect(week.totals.steps, 11234);
    } finally {
      await fixture.close();
      await dir.delete(recursive: true);
    }
  });

  test(
      'fresh production coordinator sync commits revised records and reconnect owns session',
      () async {
    final dir = await Directory.systemTemp.createTemp('health-host-sync-');
    final data = Directory('${dir.path}/data');
    var fixture = await JwHealthAcceptanceFixture.open(dir,
        data: data, commitDelay: Duration.zero);
    final container = ProviderContainer(overrides: fixture.overrides);
    final deviceSubscription = container.listen(jwDeviceProvider, (_, __) {});
    try {
      final ble = container.read(bleNotifierProvider.notifier);
      expect(
          await ble.connect(jwHealthFixtureDeviceId, jwHealthFixtureName,
              allowJw: true),
          isTrue);
      final repo = (await container.read(jwRepositoryProvider.future))!;
      await repo.initialize();
      final round = await repo.syncHistory();
      expect(round.localCommitComplete, isTrue);
      expect(round.applicationAckTransportDelivered, isTrue);
      final day = await JwHealthRepository(fixture.store).load(
          deviceKey: jwHealthFixtureHistoryKey,
          date: DateTime.utc(2026, 10, 5),
          period: JwHealthPeriod.day);
      expect(day.totals.steps, 2234);
      expect(day.totals.energyKcal, closeTo(223.45, 0.000001));
      await ble.disconnect();
      expect(container.read(connectedDeviceProvider), isNull);
      expect(
          await ble.connect(jwHealthFixtureDeviceId, jwHealthFixtureName,
              allowJw: true),
          isTrue);
      final replacement = (await container.read(jwRepositoryProvider.future))!;
      expect(identical(repo, replacement), isFalse);
      await replacement.initialize();
      expect(replacement.historyDeviceKey, jwHealthFixtureHistoryKey);
      await fixture.goals.write(jwHealthFixtureHistoryKey,
          const JwHealthGoals(steps: 4000, energyKcal: 250, sleepMinutes: 480));
    } finally {
      deviceSubscription.close();
      container.dispose();
      await fixture.close();
    }
    fixture = await JwHealthAcceptanceFixture.open(
        Directory('${dir.path}/restart'),
        data: data,
        commitDelay: Duration.zero);
    try {
      expect((await fixture.goals.read(jwHealthFixtureHistoryKey)).steps, 4000);
      final day = await JwHealthRepository(fixture.store).load(
          deviceKey: jwHealthFixtureHistoryKey,
          date: DateTime.utc(2026, 10, 5),
          period: JwHealthPeriod.day);
      expect(day.totals.steps, 2234,
          reason: 'idempotent reseed must not replace synced data');
      final audit =
          await File('${dir.path}/simulated-events.jsonl').readAsString();
      expect(audit, contains('durableCommitComplete'));
      expect(audit, contains('applicationHistoryConfirmation'));
    } finally {
      await fixture.close();
      await dir.delete(recursive: true);
    }
  });
  test(
      'snapshot observes published providers without creating or flushing them',
      () {
    final observer = JwHealthAcceptanceObserver();
    var creations = 0;
    final container = ProviderContainer(observers: [
      observer
    ], overrides: [
      bleNotifierProvider.overrideWith((ref) {
        creations++;
        throw StateError('This provider must stay untouched by capture');
      }),
    ]);
    try {
      expect(observer.snapshot()['bleState'], isNull);
      expect(creations, 0);
      container.read(connectedDeviceProvider.notifier).state =
          ConnectedDeviceInfo(
              deviceId: 'published-id',
              name: 'Published',
              mtu: 247,
              isJw: true);
      expect(observer.snapshot()['connectedDeviceId'], 'published-id');
      expect(creations, 0);
    } finally {
      container.dispose();
    }
  });

  testWidgets(
      'geometry excludes inactive routes and captures native back/app-bar labels',
      (tester) async {
    final capture = GlobalKey();
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: capture,
            child: Scaffold(
                appBar: AppBar(
                    leading: const BackButton(),
                    title: const Text('Mounted route'),
                    actions: [
                      IconButton(
                          tooltip: 'Inspect',
                          onPressed: () => presses++,
                          icon: const Icon(Icons.info)),
                    ]),
                body: const Column(children: [
                  Offstage(
                      offstage: true,
                      child: Text('Hidden inactive route',
                          key: Key('duplicate-route'))),
                  Text('Visible route', key: Key('visible-route')),
                ])))));
    await tester.pumpAndSettle();
    final geometry = jwHealthUiGeometry(capture.currentContext!);
    expect(geometry.where((g) => g['widgetType'] == 'AppBar'), hasLength(1));
    expect(geometry.where((g) => g['tooltip'] == 'Back'), isNotEmpty);
    expect(geometry.where((g) => g['tooltip'] == 'Inspect'), isNotEmpty);
    expect(
        geometry.where((g) => g['text'] == 'Hidden inactive route'), isEmpty);
    expect(geometry.where((g) => g['text'] == 'Visible route'), hasLength(1));
    expect(presses, 0);
  });

  test(
      'fixture refuses unmarked nonempty data and manifest describes actual persisted seed',
      () async {
    final dir = await Directory.systemTemp.createTemp('health-host-isolation-');
    final data = Directory('${dir.path}/existing');
    await data.create();
    final original = File('${data.path}/original.txt');
    await original.writeAsString('preserve');
    try {
      await expectLater(
          JwHealthAcceptanceFixture.open(Directory('${dir.path}/receipt'),
              data: data),
          throwsStateError);
      expect(await original.readAsString(), 'preserve');
      expect(await File('${data.path}/fixture-owner.json').exists(), isFalse);
      final fixture = await JwHealthAcceptanceFixture.open(
          Directory('${dir.path}/valid-receipt'),
          data: Directory('${dir.path}/isolated'),
          commitDelay: Duration.zero);
      try {
        final manifest = jsonDecode(
            await File('${fixture.output.path}/seed-manifest.json')
                .readAsString()) as Map;
        expect(manifest['kind'], jwHealthFixtureMarker);
        expect(manifest['goalsAtLaunch'],
            {'steps': null, 'sleepMinutes': null, 'energyKcal': null});
        expect(manifest['freshSeedWeekSteps'], 11234);
        expect((manifest['currentDay'] as Map)['partialRecordIds'], isEmpty);
        expect(
            (manifest['currentWeek'] as Map)['partialRecordIds'], isNotEmpty);
        expect(((manifest['currentDay'] as Map)['metrics'] as Map).keys,
            hasLength(6));
      } finally {
        await fixture.close();
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  testWidgets(
      'fixture native controls preserve production sport/offline route and reconnect session',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory dir;
    late JwHealthAcceptanceFixture fixture;
    late ProviderContainer container;
    final observer = JwHealthAcceptanceObserver();
    await tester.runAsync(() async {
      dir =
          await Directory.systemTemp.createTemp('health-host-native-controls-');
      fixture = await JwHealthAcceptanceFixture.open(dir,
          data: Directory('${dir.path}/data'), commitDelay: Duration.zero);
      container = ProviderContainer(
          overrides: fixture.overrides, observers: [observer]);
      await container
          .read(bleNotifierProvider.notifier)
          .connect(jwHealthFixtureDeviceId, jwHealthFixtureName, allowJw: true);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: JwHealthFixtureApp(capture: GlobalKey())));
      await tester.pump();
      final repository = (await container.read(jwRepositoryProvider.future))!;
      await repository.initialize();
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await fixture.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpAndSettle();
    expect(find.textContaining(jwHealthFixtureMarker), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('jw-health-entry')));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(JwHealthPage), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('jw-health-sport-section')), 500);
    await tester.tap(find.text('运动记录 · 登山'));
    await tester.pumpAndSettle();
    expect(find.byType(JwHealthSportPage), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('jw-health-fixture-disconnect')));
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(container.read(connectedDeviceProvider), isNull);
    expect(find.byType(JwHealthSportPage), findsOneWidget);
    expect(observer.snapshot()['connectedDeviceId'], isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(JwHealthPage), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('jw-health-fixture-reconnect')));
      await tester.pump();
      final repository = (await container.read(jwRepositoryProvider.future))!;
      await repository.initialize();
    });
    await tester.pumpAndSettle();
    expect(container.read(connectedDeviceProvider)!.deviceId,
        jwHealthFixtureDeviceId);
    expect(find.byType(JwHealthPage), findsOneWidget);
    expect(
        observer.snapshot()['repositoryHistoryKey'], jwHealthFixtureHistoryKey);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WatchAppRoot), findsOneWidget);
    await tester.runAsync(() async {
      await tester.pageBack();
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('jw-health-fixture-open-watch')), findsOneWidget);
    expect(container.read(connectedDeviceProvider), isNull,
        reason: 'production root leave guard must own disconnect');
    expect(tester.takeException(), isNull);
  });
  test(
      'snapshot remains read-only while actual durable coordinator commit is pending',
      () async {
    final dir = await Directory.systemTemp.createTemp('health-host-pending-');
    final fixture = await JwHealthAcceptanceFixture.open(dir,
        data: Directory('${dir.path}/data'),
        commitDelay: const Duration(seconds: 1));
    final observer = JwHealthAcceptanceObserver();
    final container =
        ProviderContainer(overrides: fixture.overrides, observers: [observer]);
    final subscription = container.listen(jwDeviceProvider, (_, __) {});
    try {
      await container
          .read(bleNotifierProvider.notifier)
          .connect(jwHealthFixtureDeviceId, jwHealthFixtureName, allowJw: true);
      final repository = (await container.read(jwRepositoryProvider.future))!;
      await repository.initialize();
      final syncing = repository.syncHistory();
      for (var i = 0; i < 200; i++) {
        if (repository.state.historyProgress?.phase.name == 'committing') break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(repository.state.historyProgress!.phase.name, 'committing');
      final watch = Stopwatch()..start();
      final metadata = observer.snapshot();
      watch.stop();
      expect((metadata['historyProgress'] as Map)['phase'], 'committing');
      expect(watch.elapsedMilliseconds, lessThan(100));
      expect(metadata['operationInProgress'], isTrue);
      final result = await syncing;
      expect(result.localCommitComplete, isTrue);
      expect(
          (observer.snapshot()['lastHistoryResult']
              as Map)['localCommitComplete'],
          isTrue);
    } finally {
      subscription.close();
      container.dispose();
      await fixture.close();
      await dir.delete(recursive: true);
    }
  });
}
