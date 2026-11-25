import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ebadge/ebadge_app_root.dart';
import 'package:honeybox/pages/scan/scan_page.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/pages/launcher/app_catalog.dart';
import 'package:honeybox/services/ble_manager.dart' as manager;

class _Manager implements manager.BleManager {
  var disconnectCalls = 0;
  void Function(ScanResult)? scanCallback;

  @override
  Stream<manager.BleState> get onStateChanged => const Stream.empty();
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void stopScan() {}
  @override
  Future<void> startScan(void Function(ScanResult) callback,
      {String? serviceUuid}) async {
    scanCallback = callback;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

void main() {
  testWidgets('back to launcher keeps eBadge connection', (tester) async {
    final manager = _Manager();
    final connection = ConnectedDeviceInfo(
      deviceId: 'badge-1',
      name: 'eBadge-A1',
      mtu: 247,
      ownerApp: AppId.ebadge.name,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bleManagerProvider.overrideWith((ref) => manager),
        connectedDeviceProvider.overrideWith((ref) => connection),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/ebadge-root'),
                  builder: (_) => const EBadgeAppRoot(),
                ),
              ),
              child: const Text('Launcher'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Launcher'));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(EBadgeAppRoot)));
    Navigator.of(tester.element(find.byType(EBadgeAppRoot))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Launcher'), findsOneWidget);
    expect(container.read(connectedDeviceProvider), same(connection));
    expect(manager.disconnectCalls, 0);
  });

  testWidgets('Watch-owned connection is not shown as an eBadge device',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bleManagerProvider.overrideWith((ref) => _Manager()),
        connectedDeviceProvider.overrideWith((ref) => ConnectedDeviceInfo(
              deviceId: 'watch-1',
              name: 'Watch-A1',
              mtu: 247,
              isJw: true,
              ownerApp: AppId.watch.name,
            )),
      ],
      child: const MaterialApp(home: EBadgeAppRoot()),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ScanPage), findsOneWidget);
  });

  testWidgets(
      'fast disconnect while leaving eBadge cannot pop the launcher again',
      (tester) async {
    final manager = _Manager();
    final connection = ConnectedDeviceInfo(
      deviceId: 'badge-1',
      name: 'eBadge-A1',
      mtu: 247,
      ownerApp: AppId.ebadge.name,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bleManagerProvider.overrideWith((ref) => manager),
        connectedDeviceProvider.overrideWith((ref) => connection),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/ebadge-root'),
                  builder: (_) => const EBadgeAppRoot(),
                ),
              ),
              child: const Text('Launcher'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Launcher'));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(EBadgeAppRoot)));
    await tester.tap(find.byType(BackButton));
    container.read(connectedDeviceProvider.notifier).state = null;
    await tester.pumpAndSettle();

    expect(find.text('Launcher'), findsOneWidget);
    expect(manager.disconnectCalls, 0);
  });
}
