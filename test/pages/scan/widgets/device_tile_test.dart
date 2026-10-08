import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/scan/widgets/device_tile.dart';
import 'package:honeybox/theme/app_theme.dart';

void main() {
  testWidgets('connectable scan tile fits the actual Windows 280px viewport',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                    width: 280,
                    child: DeviceTile(
                        deviceId: '64:1A:B2:B8:00:3A',
                        name: 'S200',
                        rssi: -42,
                        connectable: true,
                        debug: false,
                        isConnecting: false,
                        onConnect: () {}))))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('连接'), findsOneWidget);
  });
}
