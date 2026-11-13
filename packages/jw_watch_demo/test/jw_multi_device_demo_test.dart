import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';
import 'package:jw_watch_demo/src/jw_demo_controller.dart';
import 'package:jw_watch_demo/src/jw_history_sync_state.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/storage/jw_database.dart';

void main() {
  testWidgets('scan adds two watches, selector switches and closes only one',
      (tester) async {
    await tester.runAsync(() async {
      final store =
          JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));
      final watch = JWWatch.simulation(historyStore: store);
      await watch.initialize();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: JWWatchLabHome(watch: watch)));
      await tester.pumpAndSettle();

      Future<void> add(String id) async {
        await tester.tap(find.byKey(const Key('jw.demo.add_device')));
        await tester.pumpAndSettle();
        final row = find.byKey(Key('jw.demo.device.$id'));
        expect(row, findsOneWidget);
        await tester
            .tap(find.descendant(of: row, matching: find.byType(TextButton)));
        await tester.pumpAndSettle();
      }

      await add('jw-sim-1');
      await add('jw-sim-2');
      expect(watch.attachedSessionsSnapshot.where((e) => e.state.isConnected),
          hasLength(2));
      await tester.tap(find.byKey(const Key('jw.demo.session.jw-sim-1')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ListTile>(
                  find.byKey(const Key('jw.demo.session.jw-sim-1')))
              .selected,
          isTrue);
      expect(
          tester
              .widget<ListTile>(
                  find.byKey(const Key('jw.demo.session.jw-sim-2')))
              .selected,
          isFalse);
      await tester.tap(find.byKey(const Key('jw.demo.close.jw-sim-1')));
      await tester.pumpAndSettle();
      expect(watch.sessionOf('jw-sim-1'), isNull);
      expect(watch.sessionOf('jw-sim-2')!.state.isConnected, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await watch.dispose();
      await store.dispose();
    });
  });

  testWidgets(
      'late error stays with originating device and sync survives selection changes',
      (tester) async {
    final store =
        JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));
    final watch = JWWatch.simulation(historyStore: store);
    final controller = JWDemoController(watch: watch);
    await tester.runAsync(() async {
      await controller.initialize();
      expect(
          await controller.connect(
              const JWScanDevice(deviceMac: 'jw-sim-1', name: 'A', rssi: 0)),
          isTrue);
      final unauthenticated = controller.syncFor(controller.session!);
      await expectLater(
          unauthenticated.start(controller.session!), throwsStateError);
      expect(unauthenticated.state.phase, JwHistorySyncPhase.failed);
      await controller.bindFirstTime('123456', confirmed: true);
      final a = controller.session!;
      expect(
          await controller.connect(
              const JWScanDevice(deviceMac: 'jw-sim-2', name: 'B', rssi: 0)),
          isTrue);
      await controller.bindFirstTime('123456', confirmed: true);
      final b = controller.session!;
      controller.selectDevice('jw-sim-1');
      final syncA = controller.syncFor(a);
      final running = syncA.start(a);
      controller.selectDevice('jw-sim-2');
      final syncB = controller.syncFor(b);
      await Future.wait([running, syncB.start(b)]);
      expect(controller.session, same(b));
      expect(syncA.state.phase, JwHistorySyncPhase.success);
      expect(syncB.state.phase, JwHistorySyncPhase.success);
      controller.selectDevice('jw-sim-1');
      expect(controller.syncFor(a), same(syncA));
      // Stop A during an operation; its failure must not overwrite B's UI error.
      final failed = controller.login('123456');
      final check = expectLater(failed, throwsA(anything));
      final close = watch.closeSession('jw-sim-1');
      controller.selectDevice('jw-sim-2');
      await Future.wait([check, close]);
      expect(controller.error, isNull);
      expect(controller.state.isReady, isTrue);
      await controller.shutdown();
      controller.dispose();
      await store.dispose();
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
