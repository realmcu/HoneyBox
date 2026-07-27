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

  Widget buildPage() {
    return ProviderScope(
      overrides: [
        watchBindProvider.overrideWith((ref) {
          return WatchBindNotifier(
            commandAvailable: () => true,
            sendCommand: (frame) {
              sent.add(Uint8List.fromList(frame));
              return 1;
            },
            notifications: notifications.stream,
            userId: Uint8List(32),
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
    expect(find.text('设备绑定成功'), findsOneWidget);
  });
}
