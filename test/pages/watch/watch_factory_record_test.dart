import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/pages/watch_factory_page.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/providers/watch_bind_provider.dart';
import 'package:honeybox/services/ble_manager.dart' as manager;

class _Manager implements manager.BleManager {
  final notifications = StreamController<Uint8List>.broadcast(sync: true);
  final sent = <Uint8List>[];

  @override
  bool get commandAvailable => true;

  @override
  Stream<Uint8List> get commandNotifications => notifications.stream;

  @override
  int? sendCommand(Uint8List l2) {
    sent.add(Uint8List.fromList(l2));
    return sent.length;
  }

  @override
  Stream<manager.BleState> get onStateChanged => const Stream.empty();

  @override
  void stopScan() {}

  @override
  Future<void> startScan(void Function(ScanResult result) callback,
      {String? serviceUuid}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    notifications.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BoundNotifier extends WatchBindNotifier {
  _BoundNotifier()
      : super(
          commandAvailable: () => true,
          sendCommand: (_) => 1,
          notifications: const Stream.empty(),
          userId: Uint8List(32),
        ) {
    state = const WatchBindState(
      WatchBindPhase.success,
      timeSyncPhase: WatchTimeSyncPhase.synced,
    );
  }
}

void main() {
  testWidgets('factory page sends RECORD_REQ and renders START response',
      (tester) async {
    final manager = _Manager();
    addTearDown(manager.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bleManagerProvider.overrideWithValue(manager),
        watchBindProvider.overrideWith((ref) => _BoundNotifier()),
      ],
      child: const MaterialApp(
        home: WatchFactoryPage(
          deviceName: 'Watch',
          deviceId: 'watch-test',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('watch-factory-record-start')));
    await tester.pump();
    expect(manager.sent, hasLength(1));
    expect(
      manager.sent.single,
      Uint8List.fromList([0x14, 0x00, 0x05, 0x00, 0x00]),
    );

    manager.notifications.add(Uint8List.fromList([
      0x14,
      0x00,
      0x01,
      0x00,
      0x0A,
      0x01,
      0x00,
      0x00,
      0x3E,
      0x80,
      0x01,
      0x14,
      0x3E,
      0x80,
      0x04,
    ]));
    await tester.pump();

    expect(find.textContaining('Opus 16000 Hz'), findsOneWidget);
    expect(find.textContaining('16000 bps'), findsOneWidget);
  });
}
