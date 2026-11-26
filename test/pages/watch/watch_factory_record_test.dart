import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/pages/watch_factory_page.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/providers/watch_bind_provider.dart';
import 'package:honeybox/services/ble_manager.dart' as manager;
import 'package:honeybox/services/watch_record_file.dart';

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

class _TestRecordWriter implements WatchRecordFileWriter {
  @override
  int get dataBytes => 4;

  @override
  bool get isActive => true;

  @override
  Future<void> abort() async {}

  @override
  Future<void> append(Iterable<Uint8List> frames) async {}

  @override
  Future<File?> finish(DateTime stoppedAt) async =>
      File('/tmp/20261125_163045.wav');

  @override
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
    required DateTime startedAt,
  }) async {}
}

void main() {
  testWidgets('factory page sends RECORD_REQ and renders START/STOP responses',
      (tester) async {
    final manager = _Manager();
    addTearDown(manager.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bleManagerProvider.overrideWithValue(manager),
        watchBindProvider.overrideWith((ref) => _BoundNotifier()),
      ],
      child: MaterialApp(
        home: WatchFactoryPage(
          deviceName: 'Watch',
          deviceId: 'watch-test',
          recordFileWriterFactory: (deviceId) async => _TestRecordWriter(),
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
      0x0D,
      0x02,
      0x00,
      0x00,
      0x3E,
      0x80,
      0x01,
      0x0F,
      0x00,
      0x00,
      0x01,
      0x10,
      0x01,
      0xE0,
    ]));
    await tester.pump();

    expect(find.textContaining('PCM 16000 Hz'), findsOneWidget);
    expect(find.textContaining('480 B/帧'), findsOneWidget);
    manager.notifications.add(Uint8List.fromList([
      0x14,
      0x00,
      0x02,
      0x00,
      0x0E,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x04,
      0x01,
      0x02,
      0x03,
      0x04,
    ]));
    await tester.pump();
    expect(find.text('已接收 PCM 1 包 / 4 字节'), findsOneWidget);

    await tester.tap(find.byKey(const Key('watch-factory-record-stop')));
    await tester.pump();
    expect(manager.sent.last,
        Uint8List.fromList([0x14, 0x00, 0x04, 0x00, 0x00]));

    manager.notifications.add(Uint8List.fromList([
      0x14,
      0x00,
      0x03,
      0x00,
      0x01,
      0x00,
    ]));
    await tester.pumpAndSettle();

    expect(find.text('录音已完成'), findsOneWidget);
    expect(find.text('已接收 PCM 1 包 / 4 字节'), findsOneWidget);
    expect(find.textContaining('已保存：'), findsOneWidget);
  });
}
