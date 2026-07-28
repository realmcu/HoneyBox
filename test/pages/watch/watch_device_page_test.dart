import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/watch/watch_device_page.dart';
import 'package:honeybox/providers/watch_bind_provider.dart';
import 'package:honeybox/theme/app_theme.dart';

void main() {
  late StreamController<Uint8List> notifications;
  late List<Uint8List> sent;

  setUp(() {
    notifications = StreamController<Uint8List>.broadcast();
    sent = [];
  });

  tearDown(() async {
    await notifications.close();
  });

  Widget buildPage({
    int? Function(Uint8List)? send,
    DateTime Function()? clock,
  }) {
    return ProviderScope(
      overrides: [
        watchBindProvider.overrideWith((ref) {
          return WatchBindNotifier(
            commandAvailable: () => true,
            sendCommand: send ??
                (frame) {
                  sent.add(Uint8List.fromList(frame));
                  return 1;
                },
            notifications: notifications.stream,
            userId: Uint8List(32),
            clock: clock ?? () => DateTime(2024, 7, 27, 15, 42, 36),
          );
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WatchDevicePage(
          deviceName: 'HoneyBox Watch',
          deviceId: 'test-device',
        ),
      ),
    );
  }

  testWidgets('replaces WiFi provisioning with the manual bind action',
      (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('WiFi 配网'), findsNothing);
    expect(find.text('绑定设备'), findsOneWidget);
  });

  testWidgets('shows binding progress and then the success state',
      (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('绑定设备'));
    await tester.pump();

    expect(sent, hasLength(1));
    expect(find.text('绑定中...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    notifications.add(
      Uint8List.fromList([0x03, 0x00, 0x02, 0x00, 0x01, 0x00]),
    );
    await tester.pump();

    expect(find.text('已绑定'), findsOneWidget);
    expect(find.text('设备绑定成功，时间已同步'), findsOneWidget);
    expect(sent, hasLength(2));
    expect(find.text('重试同步'), findsNothing);
  });

  testWidgets('keeps bound state and retries only time synchronization',
      (tester) async {
    var calls = 0;
    var now = DateTime(2024, 7, 27, 15, 42, 36);
    await tester.pumpWidget(buildPage(
      clock: () => now,
      send: (frame) {
        sent.add(Uint8List.fromList(frame));
        calls++;
        return calls == 2 ? null : 1;
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('绑定设备'));
    await tester.pump();
    notifications.add(
      Uint8List.fromList([0x03, 0x00, 0x02, 0x00, 0x01, 0x00]),
    );
    await tester.pump();

    expect(find.text('已绑定'), findsOneWidget);
    expect(find.text('设备绑定成功，时间同步失败'), findsOneWidget);
    expect(find.text('重试同步'), findsOneWidget);
    expect(sent, hasLength(2));

    now = DateTime(2024, 7, 27, 15, 43, 1);
    await tester.tap(find.text('重试同步'));
    await tester.pump();

    expect(sent, hasLength(3));
    expect(sent.where((frame) => frame.first == 0x03), hasLength(1));
    expect(find.text('重试同步'), findsNothing);
    expect(find.text('设备绑定成功，时间已同步'), findsOneWidget);
  });
}
