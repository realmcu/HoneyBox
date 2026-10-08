import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/jw_history_page.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/jw/history/jw_history_decoder.dart';
import 'package:honeybox/services/jw/history/jw_history_models.dart';
import 'package:honeybox/services/jw/history/jw_history_store.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import '../helpers/jw_fixture.dart';

JwHistoryProgress progress(JwHistoryPhase phase) => JwHistoryProgress(
    batchId: 'batch',
    phase: phase,
    counts: {
      JwHistoryType.sleep:
          const JwHistoryTypeStats(received: 5, newlyPersisted: 2)
    },
    expectedMarkers: [91, 96, 100],
    observedMarkers: [],
    startReceived: true,
    traditionalEndReceived: false);

void main() {
  testWidgets(
      'busy sync disabled but cancellation available; counts are distinct',
      (tester) async {
    var cancelled = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: JwHistoryOverview(
                state: JwDeviceState(
                    phase: JwDevicePhase.loggedIn,
                    operationInProgress: true,
                    historyProgress:
                        progress(JwHistoryPhase.receivingTraditional)),
                onSync: () {},
                onCancel: () {
                  cancelled++;
                },
                onBrowse: () {}))));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('jw-history-sync')))
            .onPressed,
        isNull);
    expect(find.text('睡眠：接收 5 · 新增保存 2'), findsOneWidget);
    await tester.tap(find.text('取消同步'));
    expect(cancelled, 1);
  });
  testWidgets('completed observed round displays protocol limits',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: JwHistoryOverview(
                state: JwDeviceState(
                    phase: JwDevicePhase.loggedIn,
                    historyProgress: progress(JwHistoryPhase.completed)),
                onSync: () {},
                onCancel: () {},
                onBrowse: () {}))));
    expect(find.text('已保存本轮；设备全部数据是否取尽尚未证实'), findsOneWidget);
  });
  testWidgets(
      'learning readiness has no score and missing skin temperature has no zero',
      (tester) async {
    final learning = decodeJwHistoryField(
            'jw:test',
            100,
            Uint8List.fromList(
                jwHex('ea070a040500ff00000937042f00ffff03000000')),
            batchId: 'b',
            firstSeenOrdinal: 0)
        .single;
    final temp = Uint8List.fromList(jwHex('354400010003816f02671748'));
    // Temperature bitfield only; retain the real timestamp and HR.
    var bits = BigInt.parse(
        temp.sublist(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16);
    bits &= ~(((BigInt.one << 14) - BigInt.one) << 32);
    final zero = jwHex(bits.toRadixString(16).padLeft(16, '0'));
    temp.setRange(4, 12, zero);
    final heart = decodeJwHistoryField('jw:test', 41, temp,
            batchId: 'b', firstSeenOrdinal: 1)
        .single;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      JwHistoryRecordTile(record: learning, partial: true),
      JwHistoryRecordTile(record: heart, partial: false)
    ]))));
    expect(find.textContaining('基线学习中'), findsOneWidget);
    expect(find.textContaining('未完成同步'), findsOneWidget);
    expect(find.textContaining('皮温：无有效数据'), findsOneWidget);
    expect(find.textContaining('0 °C'), findsNothing);
    expect(find.textContaining('255 分'), findsNothing);
  });
  testWidgets(
      'offline catalog uses persisted device identities after reopening',
      (tester) async {
    late Directory root;
    late FileJwHistoryStore store;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('jw-ui-catalog-');
      store = FileJwHistoryStore(root);
      await store.open();
      final row = decodeJwHistoryField(
              'jw:test', 3, Uint8List.fromList(jwHex('3544000105460002')),
              batchId: 'b', firstSeenOrdinal: 0)
          .single;
      await store.append('b', [row]);
      await store.close();
      store = FileJwHistoryStore(root);
      await store.open();
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(overrides: [
        jwHistoryStoreProvider.overrideWith((ref) async => store)
      ], child: const MaterialApp(home: JwSavedHistoryDevicesPage())));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('test'), findsOneWidget);
    expect(find.textContaining('无需连接手表'), findsOneWidget);
  });
  testWidgets(
      'saved partial records remain browsable offline with the actual stored day',
      (tester) async {
    late Directory root;
    late FileJwHistoryStore store;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('jw-ui-');
      store = FileJwHistoryStore(root);
      await store.open();
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    });
    final row = decodeJwHistoryField(
            'jw:test', 3, Uint8List.fromList(jwHex('3544000105460002')),
            batchId: 'b', firstSeenOrdinal: 0)
        .single;
    await tester.runAsync(() async {
      await store.append('b', [row]);
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            jwHistoryStoreProvider.overrideWith((ref) async => store)
          ],
          child: const MaterialApp(
              home: JwHistoryRecordsPage(
                  deviceKey: 'jw:test', initialType: JwHistoryType.sleep))));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.textContaining('2026-10-04'), findsWidgets);
    expect(find.textContaining('未完成同步'), findsOneWidget);
    expect(find.textContaining('设备本地时间'), findsWidgets);
  });
}
