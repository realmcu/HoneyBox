import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/health/jw_health_page.dart';
import 'package:honeybox/providers/ble_provider.dart';
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
import 'jw_health_page_test.dart' show settleIo;

class _HeldQuery implements JwHistoryStore {
  _HeldQuery(this.store);
  final JwHistoryStore store;
  final entered = Completer<void>(), release = Completer<void>();
  bool held = false;
  @override
  Future<JwHistoryInventory> inventory(String key) => store.inventory(key);
  @override
  Future<JwHistoryPage> query(String key, JwHistoryType type,
      {required String day, int offset = 0, int limit = 100}) async {
    if (!held) {
      held = true;
      entered.complete();
      await release.future;
    }
    return store.query(key, type, day: day, offset: offset, limit: limit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  final live = StateProvider<JwDeviceRepository?>((ref) => null);
  final platform = StateProvider<String?>((ref) => null);
  final notifier = StateProvider<JwDeviceNotifier?>((ref) => null);
  final replacing = StateProvider<bool>((ref) => false);
  final failure = StateProvider<bool>((ref) => false);
  late Completer<JwDeviceRepository?> replacement;
  late Directory dir;
  late FileJwHistoryStore store;
  _HeldQuery? query;
  final repositories = <JwDeviceRepository>[];
  final transports = <FakeJwTransport>[];
  late ProviderContainer scope;

  Future<void> open(WidgetTester tester, {bool holdQuery = false}) async {
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('jw-live-capabilities-');
      replacement = Completer<JwDeviceRepository?>();
      store = FileJwHistoryStore(Directory('${dir.path}/records'));
      await store.open();
      await store.append('saved-metric', [
        healthRow(JwHistoryType.heartTemperature, {'heartRateBpm': 70})
      ]);
      if (holdQuery) query = _HeldQuery(store);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (!replacement.isCompleted) replacement.complete(null);
        if (query != null && !query!.release.isCompleted) {
          query!.release.complete();
        }
        await tester.pumpWidget(const SizedBox());
        for (final repository in repositories) {
          await repository.dispose();
        }
        for (final transport in transports) {
          await transport.dispose();
        }
        await store.close();
        await dir.delete(recursive: true);
      });
    });
  }

  Future<JwDeviceNotifier> device(WidgetTester tester,
      {String platformKey = 'platform-A',
      String serial = 'test',
      String functions = '0000000000000000'}) async {
    return (await tester.runAsync(() async {
      final transport = FakeJwTransport();
      // Rejected login keeps this deliberately read-only, with resolved info.
      installJwDeviceScript(transport, functions: functions, loginResult: 1);
      transport.readValues['2a25'] = Uint8List.fromList(utf8.encode(serial));
      final repository = JwDeviceRepository(
          session: JwSession(transport),
          transport: transport,
          platformDeviceKey: platformKey,
          identityStore: JwIdentityStore(
              File('${dir.path}/identity-${repositories.length}.json')),
          historyStoreFactory: () async => store,
          ownsHistoryStore: false);
      repositories.add(repository);
      transports.add(transport);
      final result = JwDeviceNotifier(repository: repository);
      await result.initialize();
      return result;
    }))!;
  }

  Future<void> mount(WidgetTester tester, {JwDeviceNotifier? initial}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            jwRepositoryProvider.overrideWith((ref) {
              final repository = ref.watch(live);
              if (ref.watch(replacing)) return replacement.future;
              if (ref.watch(failure)) {
                return Future.error(StateError('replacement failed'));
              }
              return Future.value(repository);
            }),
            connectedDeviceProvider.overrideWith((ref) {
              final key = ref.watch(platform);
              return key == null
                  ? null
                  : ConnectedDeviceInfo(
                      deviceId: key, name: 'S200', mtu: 23, isJw: true);
            }),
            jwDeviceProvider.overrideWith((ref) =>
                ref.watch(notifier) ?? JwDeviceNotifier(repository: null)),
            jwHistoryStoreProvider.overrideWith((ref) async => query ?? store),
            jwHealthGoalStoreProvider.overrideWith((ref) async =>
                JwHealthGoalStore(File('${dir.path}/goals.json'))),
          ],
          child: MaterialApp(home: Consumer(builder: (context, ref, _) {
            // Keep the real FutureProvider alive for previous-value regressions.
            ref.watch(jwRepositoryProvider);
            return const JwHealthPage(deviceKey: 'jw:test');
          }))));
      scope =
          ProviderScope.containerOf(tester.element(find.byType(JwHealthPage)));
      if (initial != null) {
        scope.read(notifier.notifier).state = initial;
        scope.read(platform.notifier).state =
            initial.repository!.platformDeviceKey;
        scope.read(live.notifier).state = initial.repository;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();
    });
    if (query == null) await settleIo(tester);
  }

  Future<void> transition(WidgetTester tester, void Function() change) async {
    await tester.runAsync(() async {
      change();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();
    });
    await tester.pumpAndSettle();
  }
}

Future<void> _labels(WidgetTester tester, {required bool unsupported}) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pump();
  final hr = find.byKey(const Key('jw-health-metric-heartRate'));
  await tester.scrollUntilVisible(hr, 250);
  expect(
      find.descendant(of: hr, matching: find.text('70 bpm')), findsOneWidget);
  expect(
      find.descendant(
          of: hr,
          matching: find
              .textContaining('\u5f53\u524d\u80fd\u529b\u672a\u652f\u6301')),
      unsupported ? findsOneWidget : findsNothing);
  final oxygen = find.byKey(const Key('jw-health-metric-bloodOxygen'));
  await tester.scrollUntilVisible(oxygen, 250);
  expect(
      find.descendant(
          of: oxygen,
          matching: find
              .textContaining('\u5f53\u524d\u8bbe\u5907\u4e0d\u652f\u6301')),
      unsupported ? findsOneWidget : findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
      'saved labels follow readonly reconnect disconnect and both live identities without refresh',
      (tester) async {
    final h = _Harness();
    await h.open(tester);
    final same = await h.device(tester);
    final wrongPlatform = await h.device(tester, platformKey: 'platform-B');
    final other =
        await h.device(tester, platformKey: 'platform-B', serial: 'other');
    await h.mount(tester);
    await _labels(tester, unsupported: false);
    expect(same.repository!.state.canWrite, false);
    await h.transition(tester, () {
      h.scope.read(h.notifier.notifier).state = same;
      h.scope.read(h.platform.notifier).state = 'platform-A';
      h.scope.read(h.live.notifier).state = same.repository;
    });
    await _labels(tester, unsupported: true);
    await h.transition(tester, () {
      h.scope.read(h.live.notifier).state = wrongPlatform.repository;
    });
    await _labels(tester, unsupported: false);
    await h.transition(tester, () {
      h.scope.read(h.live.notifier).state = same.repository;
    });
    await _labels(tester, unsupported: true);
    await h.transition(tester, () {
      h.transports.first.emitDisconnect();
    });
    await _labels(tester, unsupported: false);
    await h.transition(tester, () {
      h.scope.read(h.live.notifier).state = other.repository;
      h.scope.read(h.platform.notifier).state = 'platform-B';
    });
    await _labels(tester, unsupported: false);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpAndSettle();
  });

  testWidgets(
      'same platform loading retains old repository but yields unknown captions and errors stay unknown',
      (tester) async {
    final h = _Harness();
    await h.open(tester);
    final same = await h.device(tester);
    await h.mount(tester, initial: same);
    await _labels(tester, unsupported: true);
    await h.transition(tester, () {
      h.scope.read(h.replacing.notifier).state = true;
    });
    final pending = h.scope.read(jwRepositoryProvider);
    expect(pending.isLoading, true);
    expect(pending.valueOrNull, same.repository);
    expect(h.scope.read(jwDeviceProvider.notifier).repository, same.repository);
    await _labels(tester, unsupported: false);
    await h.transition(tester, () {
      h.scope.read(h.failure.notifier).state = true;
      h.scope.read(h.replacing.notifier).state = false;
    });
    expect(h.scope.read(jwRepositoryProvider).hasError, true);
    await _labels(tester, unsupported: false);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpAndSettle();
  });

  testWidgets(
      'old unsupported snapshot completed after disconnect cannot restore stale captions',
      (tester) async {
    final h = _Harness();
    await h.open(tester, holdQuery: true);
    final same = await h.device(tester);
    await h.mount(tester, initial: same);
    await tester.runAsync(() async {
      await h.query!.entered.future;
    });
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.runAsync(() async {
      h.transports.first.emitDisconnect();
      h.scope.read(h.platform.notifier).state = null;
      await tester.pump();
      h.query!.release.complete();
    });
    await settleIo(tester);
    await _labels(tester, unsupported: false);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpAndSettle();
  });
}
