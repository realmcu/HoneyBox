import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'package:watch_transport_ble_example/jw_smoke.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'JW real BLE: scan, language reply and battery read, disconnect and reconnect',
      (tester) async {
    final scanner = WatchBleScanner();
    addTearDown(scanner.dispose);
    await scanner.start(timeout: const Duration(seconds: 15));
    await Future<void>.delayed(const Duration(seconds: 10));
    await scanner.stop();
    for (final device in scanner.devices) {
      debugPrint(
          'BLE inventory: ${device.name} ${device.deviceId} RSSI=${device.rssi} JW=${isJwCandidate(device)}');
    }
    const requested = String.fromEnvironment('BLE_DEVICE_ID');
    final candidates = scanner.devices
        .where((d) => requested.isNotEmpty
            ? d.deviceId.toLowerCase() == requested.toLowerCase()
            : isJwCandidate(d))
        .toList();
    expect(candidates.length, 1,
        reason:
            'Specify --dart-define=BLE_DEVICE_ID=<id> if zero/multiple JW candidates');
    final device = candidates.single;
    for (var attempt = 0; attempt < 2; attempt++) {
      final connection = WatchBleTransport(
              config: WatchBleConfig(profile: jwDiagnosticProfile()))
          .createConnection(
              WatchDeviceTarget(transportId: 'ble', deviceId: device.deviceId));
      final subscription =
          connection.received.listen((data) => debugPrint('JW RX: $data'));
      try {
        await connection.connect();
        debugPrint('JW connected attempt=$attempt mtu=${connection.mtu}');
        final language = await queryJwLanguage(connection);
        expect(language, inInclusiveRange(0, 17));
        debugPrint('JW language reply=$language attempt=$attempt');
        final battery = await readJwBattery(connection);
        expect(battery, inInclusiveRange(0, 100));
        debugPrint('JW battery read=$battery% attempt=$attempt');
      } finally {
        await subscription.cancel();
        await connection.dispose();
      }
      expect(connection.state, WatchTransportState.disposed);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
