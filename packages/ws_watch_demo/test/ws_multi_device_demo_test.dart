import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/src/ws_watch_lab_home.dart';
import 'package:ws_watch_demo/src/ws_demo_controller.dart';
import 'package:ws_watch_demo/src/ws_history_sync_state.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  testWidgets('scan adds two watches, selector switches and closes only one',
      (tester) async {
    await tester.runAsync(() async {
      final store = await WSHistoryStore.open(databasePath: ':memory:');
      final watch =
          WSWatch(config: const WSConfig.simulation(), historyStore: store);
      await watch.initialize();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: WSWatchLabHome(watch: watch)));
      await tester.pumpAndSettle();

      Future<void> add(String id) async {
        await tester.tap(find.byKey(const Key('ws.demo.add_device')));
        await tester.pumpAndSettle();
        final row = find.byKey(Key('jw.demo.device.$id'));
        expect(row, findsOneWidget);
        await tester
            .tap(find.descendant(of: row, matching: find.byType(TextButton)));
        await tester.pumpAndSettle();
      }

      await add('ws-watch-simulator');
      await add('ws-watch-simulator-2');
      expect(watch.attachedSessionsSnapshot.where((e) => e.state.isConnected),
          hasLength(2));
      await tester
          .tap(find.byKey(const Key('ws.demo.session.ws-watch-simulator')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ListTile>(
                  find.byKey(const Key('ws.demo.session.ws-watch-simulator')))
              .selected,
          isTrue);
      expect(
          tester
              .widget<ListTile>(
                  find.byKey(const Key('ws.demo.session.ws-watch-simulator-2')))
              .selected,
          isFalse);
      await tester
          .tap(find.byKey(const Key('ws.demo.close.ws-watch-simulator')));
      await tester.pumpAndSettle();
      expect(watch.sessionOf('ws-watch-simulator'), isNull);
      expect(
          watch.sessionOf('ws-watch-simulator-2')!.state.isConnected, isTrue);
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
    final store = await WSHistoryStore.open(databasePath: ':memory:');
    final watch =
        WSWatch(config: const WSConfig.simulation(), historyStore: store);
    final controller = WSDemoController(watch: watch);
    await tester.runAsync(() async {
      await controller.initialize();
      expect(
          await controller.connect(const WSScanDevice(
              deviceMac: 'ws-watch-simulator', name: 'A', rssi: 0)),
          isTrue);
      final unauthenticated = controller.syncFor(controller.session!);
      await expectLater(
          unauthenticated.start(controller.session!), throwsStateError);
      expect(unauthenticated.state.phase, WsHistorySyncPhase.failed);
      await controller.bindFirstTime('123456', confirmed: true);
      final a = controller.session!;
      expect(
          await controller.connect(const WSScanDevice(
              deviceMac: 'ws-watch-simulator-2', name: 'B', rssi: 0)),
          isTrue);
      await controller.bindFirstTime('123456', confirmed: true);
      final b = controller.session!;
      controller.selectDevice('ws-watch-simulator');
      final syncA = controller.syncFor(a);
      final running = syncA.start(a);
      controller.selectDevice('ws-watch-simulator-2');
      final syncB = controller.syncFor(b);
      await Future.wait([running, syncB.start(b)]);
      expect(controller.session, same(b));
      expect(syncA.state.phase, WsHistorySyncPhase.success);
      expect(syncB.state.phase, WsHistorySyncPhase.success);
      controller.selectDevice('ws-watch-simulator');
      expect(controller.syncFor(a), same(syncA));
      // Stop A during an operation; its failure must not overwrite B's UI error.
      final failed = controller.login('123456');
      final check = expectLater(failed, throwsA(anything));
      final close = watch.closeSession('ws-watch-simulator');
      controller.selectDevice('ws-watch-simulator-2');
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
