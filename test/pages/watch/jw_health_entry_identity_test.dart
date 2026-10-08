import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/jw_device_page.dart';
import 'package:honeybox/pages/watch/jw_history_page.dart';
import 'package:honeybox/pages/watch/health/jw_health_page.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/jw/health/jw_health_goals.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/services/jw/history/jw_history_store.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';
import '../../services/jw/jw_health_aggregator_test.dart' show healthRow;
import 'jw_health_page_test.dart' show settleIo, expectSteps;

class _HeldInfoTransport extends FakeJwTransport {
  _HeldInfoTransport(this.holdSerial);
  final bool holdSerial;
  final serialGate = Completer<void>();
  @override
  Future<Uint8List?> read(String uuid) async {
    if (uuid == '2a25' && holdSerial) await serialGate.future;
    return super.read(uuid);
  }
}

class _Fixture {
  _Fixture(this.dir, this.store, this.transport, this.repository, this.notifier,
      this.initializing);
  final Directory dir;
  final FileJwHistoryStore store;
  final _HeldInfoTransport transport;
  final JwDeviceRepository repository;
  final JwDeviceNotifier notifier;
  final Future<void> initializing;
}

Future<_Fixture> _fixture(WidgetTester tester,
    {required String platform,
    required String serial,
    bool hold = false,
    int login = 0}) async {
  final result = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('jw-entry-identity-');
    final store = FileJwHistoryStore(Directory('${dir.path}/records'));
    await store.open();
    final actualKey = 'jw:${serial.isEmpty ? platform : serial}';
    await store.append('authoritative-seed', [
      healthRow(JwHistoryType.steps, {'steps': 222}, device: actualKey)
    ]);
    if (actualKey != 'jw:$platform') {
      await store.append('provisional-seed', [
        healthRow(JwHistoryType.steps, {'steps': 111}, device: 'jw:$platform')
      ]);
    }
    final transport = _HeldInfoTransport(hold);
    installJwDeviceScript(transport,
        functions: '0000000000000000', loginResult: login);
    transport.readValues['2a25'] = Uint8List.fromList(utf8.encode(serial));
    final repository = JwDeviceRepository(
        session: JwSession(transport),
        transport: transport,
        platformDeviceKey: platform,
        identityStore: JwIdentityStore(File('${dir.path}/identity.json')),
        historyStoreFactory: () async => store,
        ownsHistoryStore: false);
    final notifier = JwDeviceNotifier(repository: repository);
    final initializing = notifier.initialize();
    if (!hold) await initializing;
    return _Fixture(dir, store, transport, repository, notifier, initializing);
  }))!;
  addTearDown(() async {
    await tester.runAsync(() async {
      if (!result.transport.serialGate.isCompleted) {
        result.transport.serialGate.complete();
      }
      await tester.pumpWidget(const SizedBox());
      await result.initializing;
      await result.repository.dispose();
      await result.transport.dispose();
      await result.store.close();
      await result.dir.delete(recursive: true);
    });
  });
  return result;
}

Future<void> _mount(WidgetTester tester, _Fixture f) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          jwRepositoryProvider.overrideWith((ref) async => f.repository),
          jwDeviceProvider.overrideWith((ref) => f.notifier),
          jwHistoryStoreProvider.overrideWith((ref) async => f.store),
          jwHealthGoalStoreProvider.overrideWith((ref) async =>
              JwHealthGoalStore(File('${f.dir.path}/goals.json'))),
        ],
        child: MaterialApp(
            home: JwDevicePage(
                deviceId: f.repository.platformDeviceKey!,
                deviceName: 'S200'))));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
  });
}

FilledButton _entry(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('jw-health-entry')));
void main() {
  // Break: opening the provisional BLE ID while serial GATT reads are still held.
  testWidgets(
      'held device info cannot open provisional health and saved browser stays reachable',
      (tester) async {
    final f = await _fixture(tester,
        platform: 'platform-A', serial: 'SERIAL-A', hold: true);
    await _mount(tester, f);
    await tester.pump();
    expect(f.repository.state.info, isNull);
    expect(_entry(tester).onPressed, isNull);
    final saved = find.byKey(const Key('jw-health-saved-devices'));
    expect(tester.widget<TextButton>(saved).onPressed, isNotNull);
    await tester.runAsync(() async {
      await tester.tap(saved);
      await tester.pump();
    });
    await settleIo(tester);
    expect(find.byType(JwSavedHistoryDevicesPage), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('jw-saved-raw-jw:SERIAL-A')));
      await tester.pump();
    });
    await settleIo(tester);
    expect(find.byType(JwHistoryRecordsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    // Initialization deliberately keeps the progress indicator animating.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      f.transport.serialGate.complete();
      await f.initializing;
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(f.repository.historyDeviceKey, 'jw:SERIAL-A');
    expect(_entry(tester).onPressed, isNotNull);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('jw-health-entry')));
      await tester.pump();
    });
    await settleIo(tester);
    expect(tester.widget<JwHealthPage>(find.byType(JwHealthPage)).deviceKey,
        'jw:SERIAL-A');
    await expectSteps(tester, '222 步');
    await expectSteps(tester, '111 步', absent: true);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('jw-health-sync')))
            .onPressed,
        isNotNull);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpAndSettle();
  });
  // Break: gating on canWrite or treating a resolved empty serial as unresolved.
  testWidgets(
      'resolved empty serial uses platform fallback for read-only saved browsing',
      (tester) async {
    final f = await _fixture(tester,
        platform: 'platform-fallback', serial: '', login: 1);
    await _mount(tester, f);
    await tester.pumpAndSettle();
    expect(f.repository.state.info, isNotNull);
    expect(f.repository.state.canWrite, false);
    expect(_entry(tester).onPressed, isNotNull);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('jw-health-entry')));
      await tester.pump();
    });
    await settleIo(tester);
    expect(tester.widget<JwHealthPage>(find.byType(JwHealthPage)).deviceKey,
        'jw:platform-fallback');
    await expectSteps(tester, '222 步');
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('jw-health-sync')))
            .onPressed,
        isNull);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpAndSettle();
  });
  // Break: previous repository can be AsyncData or retained in AsyncLoading.
  // A captured enabled callback must also resolve the current key at invocation.
  testWidgets(
      'replacement excludes old platform and retained loading data and rereads key at invocation',
      (tester) async {
    final old =
        await _fixture(tester, platform: 'platform-A', serial: 'OLD-SERIAL');
    final next =
        await _fixture(tester, platform: 'platform-A', serial: 'NEW-SERIAL');
    final pagePlatform = StateProvider<String>((ref) => 'platform-B');
    final replacing = StateProvider<bool>((ref) => false);
    final activeNotifier =
        StateProvider<JwDeviceNotifier>((ref) => old.notifier);
    final gate = Completer<JwDeviceRepository?>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(next.repository);
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            jwRepositoryProvider.overrideWith((ref) => ref.watch(replacing)
                ? gate.future
                : Future.value(old.repository)),
            jwDeviceProvider.overrideWith((ref) => ref.watch(activeNotifier)),
            jwHistoryStoreProvider.overrideWith((ref) async => next.store),
            jwHealthGoalStoreProvider.overrideWith((ref) async =>
                JwHealthGoalStore(File('${next.dir.path}/goals.json'))),
          ],
          child: MaterialApp(home: Consumer(builder: (context, ref, _) {
            ref.watch(jwRepositoryProvider);
            return JwDevicePage(
                deviceId: ref.watch(pagePlatform), deviceName: 'S200');
          }))));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();
    });
    final scope =
        ProviderScope.containerOf(tester.element(find.byType(JwDevicePage)));
    expect(scope.read(jwRepositoryProvider).valueOrNull, same(old.repository));
    expect(_entry(tester).onPressed, isNull,
        reason:
            'Old platform repository must not open on the replacement device page');
    scope.read(pagePlatform.notifier).state = 'platform-A';
    await tester.pump();
    expect(_entry(tester).onPressed, isNotNull);
    final capturedCallback = _entry(tester).onPressed!;
    await tester.runAsync(() async {
      scope.read(replacing.notifier).state = true;
      await tester.pump();
    });
    final loading = scope.read(jwRepositoryProvider);
    expect(loading.isLoading, true);
    expect(loading.valueOrNull, same(old.repository));
    expect(_entry(tester).onPressed, isNull,
        reason:
            'Matching platform is insufficient while provider replacement retains prior data');
    capturedCallback();
    await tester.pump();
    expect(find.byType(JwHealthPage), findsNothing,
        reason:
            'A press queued from the prior ready frame must recheck provider loading');
    await tester.runAsync(() async {
      gate.complete(next.repository);
      await scope.read(jwRepositoryProvider.future);
      scope.read(activeNotifier.notifier).state = next.notifier;
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(_entry(tester).onPressed, isNotNull);
    await tester.runAsync(() async {
      capturedCallback();
      await tester.pump();
    });
    await settleIo(tester);
    expect(tester.widget<JwHealthPage>(find.byType(JwHealthPage)).deviceKey,
        'jw:NEW-SERIAL');
    await expectSteps(tester, '222 步');
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('jw-health-sync')))
            .onPressed,
        isNotNull);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpAndSettle();
  });
}
